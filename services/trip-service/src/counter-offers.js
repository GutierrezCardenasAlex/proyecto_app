// A counteroffer reserves the driver using the existing accepted state, but
// cannot advance or change fare_amount until the owning passenger consents.
function registerCounterOfferRoutes(app, { pool, redis, requireTripAccess, emitRealtime, publish }) {
  app.post('/:tripId/counter-offer/response', async (request, reply) => {
    const { tripId } = request.params;
    if (typeof request.body?.accept !== 'boolean') {
      return reply.code(400).send({ message: 'Indica si aceptas la contraoferta' });
    }
    const access = await requireTripAccess(request, reply, tripId);
    if (!access) return;
    if (access.user.role !== 'passenger') {
      return reply.code(403).send({ message: 'Solo el pasajero puede responder la contraoferta' });
    }
    const accept = request.body.accept;
    const client = await pool.connect();
    let trip;
    try {
      await client.query('BEGIN');
      // Lock and transition in one statement; concurrent responses/cancellation
      // must recheck the pending state after acquiring the row lock.
      const result = await client.query(
        `UPDATE trips SET
           fare_amount = CASE WHEN $3 THEN counter_offer_amount ELSE fare_amount END,
           counter_offer_status = CASE WHEN $3 THEN 'accepted' ELSE 'rejected' END,
           status = CASE WHEN $3 THEN 'arriving'::trip_status ELSE 'cancelled'::trip_status END,
           cancelled_at = CASE WHEN $3 THEN cancelled_at ELSE NOW() END,
           updated_at = NOW()
         WHERE id = $1 AND passenger_id = $2 AND status = 'accepted'
           AND counter_offer_status = 'pending' AND counter_offer_amount > 0
         RETURNING *`,
        [tripId, access.user.sub, accept]
      );
      trip = result.rows[0];
      if (!trip) {
        await client.query('ROLLBACK');
        return reply.code(409).send({ message: 'La contraoferta ya fue respondida o el viaje fue cancelado' });
      }
      if (!accept) {
        await client.query(
          `UPDATE drivers SET status = 'available', is_available = TRUE,
             current_trip_id = NULL, updated_at = NOW()
           WHERE id = $1 AND current_trip_id = $2`, [trip.driver_id, tripId]
        );
      }
      await client.query(
        `INSERT INTO trip_events (trip_id, event_type, payload) VALUES ($1, $2, $3::jsonb)`,
        [tripId, accept ? 'counter_offer_accepted' : 'counter_offer_rejected',
          JSON.stringify({ passengerId: access.user.sub, fareAmount: trip.fare_amount })]
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
    const payload = { tripId, driverId: trip.driver_id, passengerId: trip.passenger_id,
      status: trip.status, fareAmount: Number(trip.fare_amount) };
    // A notification failure must not turn a committed decision into an HTTP
    // failure. Both apps also reload the persisted active trip.
    try {
      await redis.set(`trip:${tripId}:status`, trip.status, 'EX', 3600);
      await emitRealtime('trip:counter_offer', `trip:${tripId}`, payload);
      await emitRealtime('driver:counter_offer', `driver:${trip.driver_id}`, payload);
      await publish(`trip.${trip.status}`, payload);
    } catch (error) {
      app.log.warn({ err: error, tripId }, 'counteroffer saved; notification failed');
    }
    return trip;
  });
}

module.exports = { registerCounterOfferRoutes };
