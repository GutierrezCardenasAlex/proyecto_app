import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/maps/services/network_status_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../trip/data/trip_repository.dart';
import '../data/driver_repository.dart';

class DriverStartupTrace {
  static final DateTime _mainStartedAt = DateTime.now();
  static DateTime? _splashShownAt;
  static DateTime? _sessionRestoredAt;
  static DateTime? _shellShownAt;
  static DateTime? _socketConnectedAt;
  static DateTime? _mapReadyAt;

  static void markMainStarted() {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[RAPIGO_PRO][startup] main iniciado @ ${_mainStartedAt.toIso8601String()}',
    );
  }

  static void markSplashVisible() {
    if (!kDebugMode || _splashShownAt != null) {
      return;
    }
    _splashShownAt = DateTime.now();
    debugPrint(
      '[RAPIGO_PRO][startup] splash visible en ${_splashShownAt!.difference(_mainStartedAt).inMilliseconds}ms',
    );
  }

  static void markSessionRestored() {
    if (!kDebugMode || _sessionRestoredAt != null) {
      return;
    }
    _sessionRestoredAt = DateTime.now();
    debugPrint(
      '[RAPIGO_PRO][startup] sesion restaurada en ${_sessionRestoredAt!.difference(_mainStartedAt).inMilliseconds}ms',
    );
  }

  static void markShellShown() {
    if (!kDebugMode || _shellShownAt != null) {
      return;
    }
    _shellShownAt = DateTime.now();
    debugPrint(
      '[RAPIGO_PRO][startup] DriverShell visible en ${_shellShownAt!.difference(_mainStartedAt).inMilliseconds}ms',
    );
  }

  static void markSocketConnected() {
    if (!kDebugMode || _socketConnectedAt != null) {
      return;
    }
    _socketConnectedAt = DateTime.now();
    debugPrint(
      '[RAPIGO_PRO][startup] socket conectado en ${_socketConnectedAt!.difference(_mainStartedAt).inMilliseconds}ms',
    );
  }

  static void markMapReady() {
    if (!kDebugMode || _mapReadyAt != null) {
      return;
    }
    _mapReadyAt = DateTime.now();
    debugPrint(
      '[RAPIGO_PRO][startup] mapa listo en ${_mapReadyAt!.difference(_mainStartedAt).inMilliseconds}ms',
    );
  }
}

class DriverInitialBootstrap extends ConsumerStatefulWidget {
  const DriverInitialBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverInitialBootstrap> createState() =>
      _DriverInitialBootstrapState();
}

class _DriverInitialBootstrapState
    extends ConsumerState<DriverInitialBootstrap> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_runBootstrap());
    });
  }

  Future<void> _runBootstrap() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.token.isEmpty) {
      return;
    }

    await _runStage(
      'network-monitor',
      () => ref.read(networkStatusProvider.notifier).startMonitoring(),
    );
    await _runStage(
      'session-refresh',
      () => ref.read(driverSessionProvider.notifier).refreshSessionStatus(),
    );
    await _runStage(
      'driver-state-restore',
      () => ref.read(driverStateProvider.notifier).restoreOperationalState(),
    );
    if (!mounted) {
      return;
    }

    unawaited(_runDeferredLoads(session.userId.isNotEmpty));
  }

  Future<void> _runDeferredLoads(bool shouldRefreshAccess) async {
    await _runSoftStage(
      'active-trip',
      () => ref.read(offeredTripProvider.notifier).loadOffer(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await _runSoftStage(
      'offers',
      () => ref.read(driverOffersProvider.notifier).loadOffers(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _runSoftStage(
      'history',
      () => ref.read(driverTripHistoryProvider.future).then((_) {}),
    );
    if (shouldRefreshAccess) {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await _runSoftStage(
        'access-refresh',
        () => ref.read(driverSessionProvider.notifier).refreshAccessStatus(),
      );
    }
  }

  Future<void> _runStage(String label, Future<void> Function() action) async {
    final startedAt = DateTime.now();
    try {
      await action();
      if (kDebugMode) {
        debugPrint(
          '[RAPIGO_PRO][bootstrap] $label listo en ${DateTime.now().difference(startedAt).inMilliseconds}ms',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[RAPIGO_PRO][bootstrap] $label omitido: $error');
      }
    }
  }

  Future<void> _runSoftStage(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      await _runStage(label, action);
    } catch (_) {
      // Mantener el render inicial liviano aunque una tarea secundaria falle.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
