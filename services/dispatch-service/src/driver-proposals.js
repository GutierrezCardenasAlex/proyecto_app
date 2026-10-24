function registerDriverProposals(app, { pool, requireOwnDriverId, emitRealtime, schema, redis, publish }) {
  const sendProposal = async (request, reply) => {
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ message: 'Precio o solicitud inválida' });
    const { tripId, driverId, counterFare, expectedFare } = parsed.data;
    if (!await requireOwnDriverId(request, reply, driverId)) return;
    const client = await pool.connect();
    let proposal;
    let assignedTrip = null;
    let affected = [];
    try {
      await client.query('BEGIN');
      // All offer writes and selections lock driver then trip, in that order.
      const driver = await client.query(`SELECT id FROM drivers WHERE id = $1
        AND is_available = TRUE AND status = 'available' AND current_trip_id IS NULL
        AND accepts_transport_requests = TRUE
        AND NOT EXISTS (SELECT 1 FROM trips WHERE driver_id = $1
          AND status IN ('accepted','arriving','at_pickup','in_progress')) FOR UPDATE`, [driverId]);
      if (!driver.rows.length) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'Debes estar disponible para ofrecer un viaje' });
      }
      const result = await client.query(`SELECT * FROM trips WHERE id = $1
        AND status IN ('requested','searching')
        AND (dispatch_mode = 'broadcast' OR preferred_driver_id IS NULL OR preferred_driver_id = $2)
        FOR UPDATE`, [tripId, driverId]);
      const trip = result.rows[0];
      if (!trip) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'La solicitud ya no está disponible para ti' });
      }
      const amount = counterFare ?? Number(trip.fare_amount);
      const direct = amount === Number(trip.fare_amount);
      if (direct && expectedFare != null && expectedFare !== Number(trip.fare_amount)) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'El precio del pasajero cambió. Revisa la solicitud antes de aceptar.' });
      }
      if (!Number.isFinite(amount) || amount < 0 || amount > 99999999.99 ||
          (!trip.promotional_trip && amount <= 0) ||
          (trip.promotional_trip && amount !== Number(trip.fare_amount))) {
        await client.query('ROLLBACK');
        return reply.code(400).send({ message: 'Precio inválido; una promoción conserva su tarifa' });
      }
      const offer = await client.query(`INSERT INTO trip_driver_offers (trip_id, driver_id, amount, trip_revision)
        VALUES ($1, $2, $3, (SELECT updated_at FROM trips WHERE id = $1))
        ON CONFLICT (trip_id, driver_id) DO UPDATE SET amount = EXCLUDED.amount, trip_revision = EXCLUDED.trip_revision, status = 'pending', updated_at = NOW()
          WHERE trip_driver_offers.status IN ('pending','unavailable')
        RETURNING *`, [tripId, driverId, amount]);
      proposal = offer.rows[0];
      if (!proposal) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'El pasajero ya respondió tu oferta' });
      }
      if (direct) {
        // The driver already locked above accepts the passenger's own price.
        await client.query(`UPDATE drivers SET status = 'busy', is_available = FALSE,
          current_trip_id = $2, updated_at = NOW() WHERE id = $1`, [driverId, tripId]);
        const assigned = await client.query(`UPDATE trips SET driver_id = $2,
          status = 'arriving', accepted_at = NOW(), updated_at = NOW()
          WHERE id = $1 RETURNING *`, [tripId, driverId]);
        assignedTrip = assigned.rows[0];
        const closed = await client.query(`UPDATE trip_driver_offers SET
          status = CASE WHEN id = $1 THEN 'accepted' ELSE 'unavailable' END, updated_at = NOW()
          WHERE status = 'pending' AND (trip_id = $2 OR driver_id = $3)
          RETURNING trip_id, driver_id`, [proposal.id, tripId, driverId]);
        affected = closed.rows;
        proposal = { ...proposal, status: 'accepted' };
      }
      await client.query(`INSERT INTO trip_events (trip_id, event_type, payload)
        VALUES ($1, $2, $3::jsonb)`, [tripId, direct ? 'driver_direct_accept' : 'driver_offer_sent', JSON.stringify({ driverId, amount })]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally { client.release(); }
    // Notification failures must not undo a committed assignment or ask for a retry.
    try {
      for (const id of new Set([tripId, ...affected.map(row => row.trip_id)])) {
        await emitRealtime('trip:offers_changed', `trip:${id}`, { tripId: id });
      }
      for (const id of new Set([driverId, ...affected.map(row => row.driver_id)])) {
        await emitRealtime('driver:offers_changed', `driver:${id}`, { tripId });
      }
      if (assignedTrip) {
        await emitRealtime('trip:status_changed', `trip:${tripId}`, { tripId, driverId, status: assignedTrip.status });
        await emitRealtime('driver:trip_accepted', `driver:${driverId}`, { tripId, status: assignedTrip.status });
        if (redis) await redis.set(`trip:${tripId}:status`, assignedTrip.status, 'EX', 3600);
        if (publish) await publish('dispatch.trip.accepted', { tripId, driverId });
      }
    } catch (error) { app.log.warn({ err: error, tripId }, 'offer saved; notification failed'); }
    return { proposal, accepted: assignedTrip != null, ...(assignedTrip ? { trip: assignedTrip } : {}) };
  };
  // New clients must never call the legacy assignment endpoint on an old server.
  app.post('/proposals', sendProposal);
  app.post('/accept', sendProposal);
}
async function withdrawDriverProposal(pool, driverId, tripId) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM drivers WHERE id = $1 FOR UPDATE', [driverId]);
    const trip = await client.query('SELECT status FROM trips WHERE id = $1 FOR UPDATE', [tripId]);
    if (!trip.rows.length || !['requested', 'searching'].includes(trip.rows[0].status)) {
      await client.query('ROLLBACK');
      return false;
    }
    await client.query(`UPDATE trip_driver_offers SET status = 'unavailable', updated_at = NOW()
      WHERE trip_id = $1 AND driver_id = $2 AND status = 'pending'`, [tripId, driverId]);
    await client.query('COMMIT');
    return true;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
module.exports = { registerDriverProposals, withdrawDriverProposal };
