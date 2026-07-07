String driverTripRouteStageForStatus(String? status) {
  switch (status) {
    case 'in_progress':
    case 'completed':
      return 'destination';
    case 'accepted':
    case 'arriving':
    case 'at_pickup':
    default:
      return 'pickup';
  }
}

String driverTripRouteStageKey(String tripId, String stage) {
  return 'driver_trip_route_${tripId}_$stage';
}

List<String> driverTripRouteReadKeys(String tripId, String? status) {
  final stage = driverTripRouteStageForStatus(status);
  final otherStage = stage == 'pickup' ? 'destination' : 'pickup';
  return <String>[
    driverTripRouteStageKey(tripId, stage),
    'driver_trip_route_$tripId',
    driverTripRouteStageKey(tripId, otherStage),
  ];
}

List<String> driverTripRouteWriteKeys(String tripId, String? status) {
  final stage = driverTripRouteStageForStatus(status);
  return <String>[
    'driver_trip_route_$tripId',
    driverTripRouteStageKey(tripId, stage),
  ];
}

String? driverTripRoutePrefetchKey(String tripId, String? status) {
  final stage = driverTripRouteStageForStatus(status);
  if (stage == 'pickup') {
    return driverTripRouteStageKey(tripId, 'destination');
  }
  return null;
}
