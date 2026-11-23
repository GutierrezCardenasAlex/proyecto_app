import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rapigo_driver_pro/driver/features/map/presentation/driver_map_motion.dart';

void main() {
  test('GPS inside a block projects onto the middle of a street segment', () {
    final route = [const LatLng(-19.58, -65.76), const LatLng(-19.58, -65.74)];
    final projected = projectDriverToRoute(
      const LatLng(-19.5803, -65.75),
      route,
    )!;
    expect(projected.latitude, closeTo(-19.58, 0.0000001));
    expect(projected.longitude, closeTo(-65.75, 0.0000001));
  });

  test('projection clamps to road endpoints and handles missing geometry', () {
    const start = LatLng(-19.58, -65.76);
    const end = LatLng(-19.58, -65.74);
    final projected = projectDriverToRoute(const LatLng(-19.58, -65.73), [
      start,
      end,
    ])!;
    expect(const Distance()(projected, end), lessThan(0.01));
    expect(projectDriverToRoute(start, []), isNull);
    expect(projectDriverToRoute(end, [start, start]), start);
  });

  test('animation positions at a turn stay on road geometry', () {
    final route = [
      const LatLng(-19.58, -65.76),
      const LatLng(-19.58, -65.75),
      const LatLng(-19.57, -65.75),
    ];
    final projected = projectDriverToRoute(
      const LatLng(-19.5798, -65.7502),
      route,
    )!;
    expect(distanceToDriverRoute(projected, route), lessThan(0.01));
  });

  test('motion follows one-second GPS cadence without a 450ms stop', () {
    final cadence = DriverMotionCadence();
    expect(cadence.next(Duration.zero), const Duration(seconds: 1));
    expect(
      cadence.next(const Duration(seconds: 1)),
      const Duration(seconds: 1),
    );
    expect(
      cadence.next(const Duration(seconds: 2)),
      const Duration(seconds: 1),
    );
  });

  test('motion duration adapts to faster GPS and recovers after a pause', () {
    final cadence = DriverMotionCadence();
    cadence.next(Duration.zero);
    final fast = cadence.next(const Duration(milliseconds: 500));
    expect(fast.inMilliseconds, inInclusiveRange(500, 750));
    expect(
      cadence.next(const Duration(seconds: 10)),
      const Duration(milliseconds: 450),
    );
    expect(
      cadence.next(const Duration(seconds: 11)),
      const Duration(seconds: 1),
    );
    expect(
      cadence.next(const Duration(seconds: 11)),
      const Duration(seconds: 1),
    );
  });

  test('bearing crosses north by the short path', () {
    expect(shortestHeadingDelta(359, 1), 2);
    expect(shortestHeadingDelta(1, 359), -2);
    expect(shortestHeadingDelta(45, 45), 0);
  });

  test('distance uses segments, not distance to sparse vertices', () {
    final route = [const LatLng(-19.58, -65.76), const LatLng(-19.58, -65.74)];
    expect(
      distanceToDriverRoute(const LatLng(-19.58, -65.75), route),
      closeTo(0, 0.01),
    );
    expect(
      distanceToDriverRoute(const LatLng(-19.581, -65.75), route),
      closeTo(111.32, 1),
    );
    expect(distanceToDriverRoute(route.first, [route.first, route.first]), 0);
    expect(distanceToDriverRoute(route.first, []), double.infinity);
  });

  test('reroute needs sustained deviation and observes cooldown', () {
    final gate = DriverRerouteGate();
    final start = DateTime(2026);
    gate.markAttempt(start);
    bool check(int seconds, double meters) => gate.shouldRefresh(
      now: start.add(Duration(seconds: seconds)),
      distanceMeters: meters,
      missingRoute: false,
    );
    expect(check(1, 90), isFalse);
    expect(check(2, 90), isFalse);
    expect(check(3, 90), isFalse);
    expect(check(21, 0), isFalse);
    expect(check(22, 90), isFalse);
    expect(check(23, 90), isFalse);
    expect(check(24, 90), isTrue);
    gate.markAttempt(start.add(const Duration(seconds: 24)));
    expect(check(25, 90), isFalse);
  });

  test(
    'missing route retries after cooldown rather than on each GPS update',
    () {
      final gate = DriverRerouteGate();
      final now = DateTime(2026);
      gate.markAttempt(now);
      expect(
        gate.shouldRefresh(
          now: now.add(const Duration(seconds: 19)),
          distanceMeters: double.infinity,
          missingRoute: true,
        ),
        isFalse,
      );
      expect(
        gate.shouldRefresh(
          now: now.add(const Duration(seconds: 20)),
          distanceMeters: double.infinity,
          missingRoute: true,
        ),
        isTrue,
      );
    },
  );
}
