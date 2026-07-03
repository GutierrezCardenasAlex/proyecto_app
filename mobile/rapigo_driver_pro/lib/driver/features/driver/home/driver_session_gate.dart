part of 'driver_home_page.dart';

class DriverSessionGate extends ConsumerStatefulWidget {
  const DriverSessionGate({super.key});

  @override
  ConsumerState<DriverSessionGate> createState() => _DriverSessionGateState();
}

class _DriverSessionGateState extends ConsumerState<DriverSessionGate> {
  static const _minimumSplash = Duration(milliseconds: 260);

  late final DateTime _openedAt;
  Timer? _splashReleaseTimer;
  bool _allowGateAdvance = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  @override
  void dispose() {
    _splashReleaseTimer?.cancel();
    super.dispose();
  }

  void _ensureMinimumSplash() {
    if (_allowGateAdvance) {
      return;
    }

    final elapsed = DateTime.now().difference(_openedAt);
    final remaining = _minimumSplash - elapsed;
    if (remaining <= Duration.zero) {
      _allowGateAdvance = true;
      return;
    }

    _splashReleaseTimer ??= Timer(remaining, () {
      if (!mounted) {
        return;
      }
      setState(() => _allowGateAdvance = true);
    });
  }

  bool _isAuthorizedStatus(String value) {
    return value.trim().toUpperCase() == 'AUTORIZADO';
  }

  @override
  Widget build(BuildContext context) {
    final isRestoring = ref.watch(driverSessionProvider.select((s) => s.isRestoring));
    final loggedIn = ref.watch(driverSessionProvider.select((s) => s.loggedIn));
    final deviceStatus = ref.watch(driverSessionProvider.select((s) => s.deviceStatus));
    final profileCompleted = ref.watch(driverSessionProvider.select((s) => s.profileCompleted));
    final accessStatus = ref.watch(driverSessionProvider.select((s) => s.accessStatus));

    if (isRestoring) {
      return const DriverLoadingSplash();
    }

    DriverStartupTrace.markSessionRestored();
    _ensureMinimumSplash();
    if (!_allowGateAdvance) {
      return const DriverLoadingSplash();
    }

    if (!loggedIn) {
      return const DriverLoginShell();
    }

    if (!_isAuthorizedStatus(deviceStatus)) {
      return DeviceBlockedView(deviceStatus: deviceStatus);
    }

    if (!profileCompleted) {
      return const DriverProfileCompletionPage();
    }

    if (!_isAuthorizedStatus(accessStatus)) {
      return PendingAuthorizationView(accessStatus: accessStatus);
    }

    return const DriverShell();
  }
}
