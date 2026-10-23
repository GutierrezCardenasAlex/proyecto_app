function registerDriverOfferRoutes(app, { pool, requireTripAccess, emitRealtime, redis, publish }) {
  async function owner(request, reply) {
    const access = await requireTripAccess(request, reply, request.params.tripId);
    if (!access) return null;
    if (access.user.role !== 'passenger') {
      reply.code(403).send({ message: 'Solo el pasajero puede elegir una oferta' });
      return null;
    }
    return access.user;
  }

  app.get('/:tripId/offers', async (request, reply) => {
    if (!await owner(request, reply)) return;
    return { offers: await loadPassengerOffers(pool, request.params.tripId) };
  });

  app.post('/:tripId/offers/:offerId/response', async (request, reply) => {
    const user = await owner(request, reply);
    if (!user) return;
    const { accept, expectedAmount } = request.body ?? {};
    if (typeof accept !== 'boolean' || (accept && (typeof expectedAmount !== 'number' || !Number.isFinite(expectedAmount)))) {
      return reply.code(400).send({ message: 'Respuesta inválida' });
    }
    const { tripId, offerId } = request.params;
    if (!/^[0-9a-f-]{36}$/i.test(offerId)) return reply.code(400).send({ message: 'Oferta inválida' });
    const client = await pool.connect();
    let trip;
    let driverId;
    let affected = [];
    try {
      await client.query('BEGIN');
      const lookup = await client.query('SELECT driver_id FROM trip_driver_offers WHERE id = $1 AND trip_id = $2', [offerId, tripId]);
      driverId = lookup.rows[0]?.driver_id;
      if (!driverId) {
        await client.query('ROLLBACK');
        return reply.code(404).send({ message: 'Oferta no encontrada' });
      }
      const driverResult = await client.query('SELECT * FROM drivers WHERE id = $1 FOR UPDATE', [driverId]);
      const tripResult = await client.query('SELECT * FROM trips WHERE id = $1 AND passenger_id = $2 FOR UPDATE', [tripId, user.sub]);
      trip = tripResult.rows[0];
      const offerResult = await client.query("SELECT o.*, o.trip_revision = t.updated_at AS revision_valid FROM trip_driver_offers o JOIN trips t ON t.id = o.trip_id WHERE o.id = $1 AND o.status = 'pending' FOR UPDATE OF o", [offerId]);
      const offer = offerResult.rows[0];
      if (!trip || !['requested', 'searching'].includes(trip.status) || !offer ||
          (accept && (Number(offer.amount) !== expectedAmount || !offer.revision_valid))) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'La oferta cambió o la solicitud ya fue atendida. Actualiza la lista.' });
      }
      if (accept) {
        const driver = driverResult.rows[0];
        if (!driver || driver.status !== 'available' || !driver.is_available || driver.current_trip_id) {
          await client.query('ROLLBACK');
          return reply.code(409).send({ message: 'Este conductor ya no está disponible. Elige otra oferta.' });
        }
        const reserved = await client.query(`UPDATE drivers SET status = 'busy', is_available = FALSE,
          current_trip_id = $2, updated_at = NOW() WHERE id = $1
          AND NOT EXISTS (SELECT 1 FROM trips WHERE driver_id = $1
            AND status IN ('accepted','arriving','at_pickup','in_progress')) RETURNING id`, [driverId, tripId]);
        if (!reserved.rows.length) {
          await client.query('ROLLBACK');
          return reply.code(409).send({ message: 'El conductor tiene otro viaje activo' });
        }
        const updated = await client.query(`UPDATE trips SET driver_id = $2, fare_amount = $3,
          status = 'arriving', accepted_at = NOW(), updated_at = NOW() WHERE id = $1 RETURNING *`, [tripId, driverId, offer.amount]);
        trip = updated.rows[0];
        // Other offers for this trip and this driver's other proposals cannot be selected.
        const closed = await client.query(`UPDATE trip_driver_offers SET
          status = CASE WHEN id = $1 THEN 'accepted' ELSE 'unavailable' END, updated_at = NOW()
          WHERE status = 'pending' AND (trip_id = $2 OR driver_id = $3) RETURNING trip_id, driver_id`, [offerId, tripId, driverId]);
        affected = closed.rows;
      } else {
        await client.query("UPDATE trip_driver_offers SET status = 'ignored', updated_at = NOW() WHERE id = $1", [offerId]);
        affected = [{ trip_id: tripId, driver_id: driverId }];
      }
      await client.query(`INSERT INTO trip_events (trip_id, event_type, payload) VALUES ($1, $2, $3::jsonb)`,
        [tripId, accept ? 'driver_offer_accepted' : 'driver_offer_ignored', JSON.stringify({ offerId, driverId, amount: offer.amount })]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally { client.release(); }
    try {
      for (const id of new Set([tripId, ...affected.map(row => row.trip_id)])) {
        await emitRealtime('trip:offers_changed', `trip:${id}`, { tripId: id });
      }
      for (const id of new Set(affected.map(row => row.driver_id))) {
        await emitRealtime('driver:offers_changed', `driver:${id}`, { tripId });
      }
      if (accept) {
        await redis.set(`trip:${tripId}:status`, trip.status, 'EX', 3600);
        await emitRealtime('trip:status_changed', `trip:${tripId}`, { tripId, status: trip.status, driverId });
        await emitRealtime('driver:trip_accepted', `driver:${driverId}`, { tripId, status: trip.status });
        await publish('dispatch.trip.accepted', { tripId, driverId });
      }
    } catch (error) { app.log.warn({ err: error, tripId }, 'offer decision saved; notification failed'); }
    return { trip, accepted: accept };
  });
}
async function loadPassengerOffers(pool, tripId) {
    const result = await pool.query(`SELECT o.*, u.full_name AS driver_name, d.rating,
        v.vehicle_type, v.brand, v.model, v.plate, v.color
      FROM trip_driver_offers o
      JOIN trips t ON t.id = o.trip_id
      JOIN drivers d ON d.id = o.driver_id
      JOIN users u ON u.id = d.user_id
      LEFT JOIN LATERAL (SELECT * FROM vehicles WHERE driver_id = d.id ORDER BY id LIMIT 1) v ON TRUE
      WHERE o.trip_id = $1 AND o.status = 'pending' AND o.trip_revision = t.updated_at AND t.status IN ('requested','searching')
        AND d.status = 'available' AND d.is_available = TRUE AND d.current_trip_id IS NULL
        AND NOT EXISTS (SELECT 1 FROM trips busy WHERE busy.driver_id = d.id
          AND busy.status IN ('accepted','arriving','at_pickup','in_progress'))
      ORDER BY o.amount, o.created_at`, [tripId]);
  return result.rows;
}
module.exports = { registerDriverOfferRoutes, loadPassengerOffers };
