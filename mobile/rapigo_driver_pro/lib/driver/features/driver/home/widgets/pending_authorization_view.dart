part of '../driver_home_page.dart';

class PendingAuthorizationView extends ConsumerStatefulWidget {
  const PendingAuthorizationView({
    super.key,
    required this.accessStatus,
  });

  final String accessStatus;

  @override
  ConsumerState<PendingAuthorizationView> createState() =>
      _PendingAuthorizationViewState();
}

class _PendingAuthorizationViewState
    extends ConsumerState<PendingAuthorizationView> {
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
    return _DriverAuthorizationPendingShell(
      accessStatus: widget.accessStatus,
      onRefresh: _refreshNow,
      isRefreshing: _refreshing,
    );
  }
}
