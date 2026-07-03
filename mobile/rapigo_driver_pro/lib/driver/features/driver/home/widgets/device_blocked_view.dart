part of '../driver_home_page.dart';

class DeviceBlockedView extends ConsumerStatefulWidget {
  const DeviceBlockedView({
    super.key,
    required this.deviceStatus,
  });

  final String deviceStatus;

  @override
  ConsumerState<DeviceBlockedView> createState() => _DeviceBlockedViewState();
}

class _DeviceBlockedViewState extends ConsumerState<DeviceBlockedView> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNow());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshNow(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNow() async {
    if (!mounted || _refreshing) {
      return;
    }
    setState(() => _refreshing = true);
    try {
      await ref.read(driverSessionProvider.notifier).refreshSessionStatus();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DriverDeviceAccessPendingShell(
      deviceStatus: widget.deviceStatus,
      onRefresh: _refreshNow,
      isRefreshing: _refreshing,
    );
  }
}
