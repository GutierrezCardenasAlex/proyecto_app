function statusUpdateQuery(status) {
  const timestamps = {
    arriving: null,
    at_pickup: null,
    in_progress: 'started_at',
    completed: 'completed_at',
    cancelled: 'cancelled_at'
  };
  if (!Object.hasOwn(timestamps, status)) throw new Error('Invalid trip status');
  const timestampField = timestamps[status];
  // Comparisons below infer $2 as text. Cast explicitly when assigning the enum.
  return `UPDATE trips SET status = $2::trip_status,
    ${timestampField ? `${timestampField} = NOW(),` : ''}
    updated_at = NOW(),
    counter_offer_status = CASE
      WHEN $2 = 'cancelled' AND counter_offer_status = 'pending' THEN 'rejected'
      ELSE counter_offer_status END
    WHERE id = $1 AND status NOT IN ('cancelled', 'completed')
      AND ($2 = 'cancelled' OR counter_offer_status IS DISTINCT FROM 'pending')
    RETURNING *`;
}

module.exports = { statusUpdateQuery };
