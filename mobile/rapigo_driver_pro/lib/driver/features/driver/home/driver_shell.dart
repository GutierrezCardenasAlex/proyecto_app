part of 'driver_home_page.dart';

class DriverShell extends ConsumerStatefulWidget {
  const DriverShell({super.key});

  @override
  ConsumerState<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends ConsumerState<DriverShell> {
  static const _shellTabKey = 'rapigo_driver_shell_tab_v1';
  int _selectedIndex = 0;
  bool _openOffersFromDashboard = false;
  bool _incomingOfferPageOpen = false;
  String? _incomingOfferPageTripId;
  DateTime? _lastBackPressedAt;

  DriverTrip? _resolvePendingOffer(
    DriverTrip? activeTrip,
    List<DriverTrip> offers,
    String? previewTripId,
  ) {
    if (previewTripId != null &&
        activeTrip != null &&
        activeTrip.id == previewTripId &&
        activeTrip.status == 'accepted') {
      return activeTrip;
    }
    if (activeTrip != null && const {'requested', 'searching'}.contains(activeTrip.status)) {
      return activeTrip;
    }
    for (final offer in offers) {
      if (const {'requested', 'searching'}.contains(offer.status)) {
        return offer;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _restoreShellTab();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DriverStartupTrace.markShellShown();
    });
  }

  Future<void> _restoreShellTab() async {
    final preferences = await SharedPreferences.getInstance();
    final restoredIndex = preferences.getInt(_shellTabKey);
    if (!mounted || restoredIndex == null || restoredIndex < 0 || restoredIndex > 4) {
      return;
    }
    setState(() => _selectedIndex = restoredIndex);
  }

  Future<void> _persistShellTab(int index) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_shellTabKey, index);
  }

  Future<bool> _handleHomeBack() async {
    if (_selectedIndex != 0) {
      if (mounted) {
        setState(() => _selectedIndex = 0);
      }
      unawaited(_persistShellTab(0));
      return false;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    if (shouldExit) {
      return true;
    }
    _lastBackPressedAt = now;
    if (mounted) {
      showTopNotice(
        context,
        'Presiona atras otra vez para salir de RAPIGO PRO.',
        tone: NoticeTone.info,
      );
    }
    return false;
  }

  void _openTab(int index) {
    if (!mounted) {
      return;
    }
    setState(() => _selectedIndex = index);
    unawaited(_persistShellTab(index));
  }

  void _maybeOpenIncomingOfferPage(DriverTrip? pendingOffer, DriverTrip? activeTrip) {
    if (pendingOffer == null) {
      _incomingOfferPageTripId = null;
      return;
    }
    final ignoredTripId = ref.read(driverIgnoredIncomingTripIdProvider);
    if (ignoredTripId != null) {
      if (ignoredTripId == pendingOffer.id) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(driverIgnoredIncomingTripIdProvider.notifier).clear();
        }
      });
    }
    if (_incomingOfferPageOpen) {
      return;
    }
    if (activeTrip != null &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(activeTrip.status)) {
      return;
    }
    if (_incomingOfferPageTripId == pendingOffer.id) {
      return;
    }
    _incomingOfferPageOpen = true;
    _incomingOfferPageTripId = pendingOffer.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _incomingOfferPageOpen = false;
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _DriverOfferRoutePreviewPage(trip: pendingOffer),
        ),
      );
      _incomingOfferPageOpen = false;
      if (mounted) {
        final latestTrip = ref.read(offeredTripProvider).value;
        final latestOffers = ref.read(driverOffersProvider).value ?? const <DriverTrip>[];
        final latestPreviewTripId = ref.read(driverOfferPreviewTripIdProvider);
        final latestPending = _resolvePendingOffer(latestTrip, latestOffers, latestPreviewTripId);
        if (latestPending?.id != pendingOffer.id) {
          _incomingOfferPageTripId = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(offeredTripProvider).value;
    final offers = ref.watch(driverOffersProvider).value ?? const <DriverTrip>[];
    final previewTripId = ref.watch(driverOfferPreviewTripIdProvider);
    final suppressIncomingOfferOverlay =
        ref.watch(driverSuppressIncomingOfferOverlayProvider);
    final pendingOffer = _resolvePendingOffer(activeTrip, offers, previewTripId);
    if (!suppressIncomingOfferOverlay) {
      _maybeOpenIncomingOfferPage(pendingOffer, activeTrip);
    } else {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          ref
              .read(driverSuppressIncomingOfferOverlayProvider.notifier)
              .clear();
        }
      });
    }

    final pages = <Widget>[
      DriverDashboard(
        onMenuTap: () => setState(() => _selectedIndex = 4),
        onOpenTab: _openTab,
        openOffersFromDrawer: _openOffersFromDashboard,
        onOffersDrawerHandled: () {
          if (mounted && _openOffersFromDashboard) {
            setState(() => _openOffersFromDashboard = false);
          }
        },
      ),
      const DriverStatisticsPage(),
      const DriverTripsTab(),
      const DriverOrdersTab(),
      const DriverProfilePage(),
    ];

    return DriverInitialBootstrap(
      child: DriverSocketListener(
        child: DriverActiveTripListener(
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) {
                return;
              }
              final shouldExit = await _handleHomeBack();
              if (shouldExit) {
                await SystemNavigator.pop();
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF08111F),
              extendBody: true,
              body: Stack(
                children: [
                  IndexedStack(index: _selectedIndex, children: pages),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
