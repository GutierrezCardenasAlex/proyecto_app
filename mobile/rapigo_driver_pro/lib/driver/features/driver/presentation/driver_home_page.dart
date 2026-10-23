part of '../home/driver_home_page.dart';

class _DriverAuthorizationPendingShell extends ConsumerWidget {
  const _DriverAuthorizationPendingShell({
    required this.accessStatus,
    required this.isRefreshing,
  });

  final String accessStatus;
  final bool isRefreshing;

  String? _normalizeWhatsAppPhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) return '591$digits';
    if (digits.length == 11 && digits.startsWith('591')) return digits;
    return null;
  }

  Future<void> _requestAuthorization(
    BuildContext context,
    DriverSession session,
    String supportPhone,
  ) async {
    final centralPhone = _normalizeWhatsAppPhone(supportPhone);
    if (centralPhone == null) {
      showTopNotice(
        context,
        'No hay numero de central configurado para WhatsApp.',
      );
      return;
    }
    final message = Uri.encodeComponent(
      'Hola central RAPIGO, solicito autorizacion para usar la aplicacion de conductor.\n'
      'Nombre: ${session.fullName}\n'
      'Telefono: ${session.phone}\n'
      'ID conductor: ${session.driverId}\n'
      'Estado: ${session.accessStatus}\n'
      'Por favor revisen y autoricen mi registro.',
    );
    final uri = Uri.parse('https://wa.me/$centralPhone?text=$message');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) {
      return;
    }
    if (!opened) {
      showTopNotice(context, 'No se pudo abrir WhatsApp en este momento.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejected = accessStatus == 'RECHAZADO';
    final session = ref.watch(driverSessionProvider);
    final offlineState = ref.watch(offlineMapProvider);
    final publicSettings = ref.watch(driverPublicSettingsProvider);
    final loadedSupportPhone = publicSettings.asData?.value.supportPhone ?? '';
    final supportPhone = loadedSupportPhone.trim().isNotEmpty
        ? loadedSupportPhone
        : shared_config.AppConfig.supportPhone;
    final mapPercent = (offlineState.progress * 100).clamp(0, 100).round();
    if (!offlineState.isReady && !offlineState.isDownloading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(offlineMapProvider.notifier).ensureOfflineAvailability();
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFFE3EAF9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10123EAF),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: rejected
                            ? const Color(0xFFFFE3E3)
                            : const Color(0xFFE9F1FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        rejected
                            ? Icons.block_rounded
                            : Icons.verified_user_outlined,
                        color: rejected
                            ? const Color(0xFFE04F4F)
                            : const Color(0xFF1746B5),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      rejected
                          ? 'Permisos insuficientes'
                          : 'Falta autorizacion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1746B5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rejected
                          ? 'La central todavia no habilito este registro de conductor. Deben revisar tus datos y volver a autorizar el uso.'
                          : 'Tu cuenta de conductor ya se registro correctamente, pero la central todavia debe autorizarla para que puedas operar.',
                      style: const TextStyle(
                        color: Color(0xFF64739A),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mientras esperas',
                            style: TextStyle(
                              color: Color(0xFF1746B5),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'La app ya puede dejar listos permisos y mapa offline de Potosi. Cuando la central te autorice, solo vuelves a entrar y podras usar el panel de conductor.',
                            style: TextStyle(
                              color: Color(0xFF68779E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            color: Color(0xFF1746B5),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              offlineState.isReady
                                  ? 'Mapa offline listo'
                                  : 'Descarga de mapa',
                              style: const TextStyle(
                                color: Color(0xFF1746B5),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            offlineState.isReady ? '100%' : '$mapPercent%',
                            style: const TextStyle(
                              color: Color(0xFF101722),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _requestAuthorization(
                          context,
                          session,
                          supportPhone,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1746B5),
                          side: const BorderSide(color: Color(0xFFBFD3FF)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text(
                          'Solicitar autorización por WhatsApp',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFFF6BE00),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRefreshing
                                ? 'Revisando autorizacion...'
                                : 'Esperando autorizacion de central',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF68779E),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverDeviceAccessPendingShell extends StatelessWidget {
  const _DriverDeviceAccessPendingShell({
    required this.deviceStatus,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final String deviceStatus;
  final Future<void> Function() onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final rejected = deviceStatus == 'RECHAZADO';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFFE3EAF9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10123EAF),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      rejected
                          ? Icons.block_rounded
                          : Icons.phone_android_rounded,
                      color: rejected
                          ? const Color(0xFFE04F4F)
                          : const Color(0xFF1746B5),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rejected ? 'Equipo bloqueado' : 'Equipo pendiente',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1746B5),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rejected
                          ? 'La central bloqueo este dispositivo. Si lo vuelven a autorizar, la app del conductor se habilitara sola.'
                          : 'La central aun no autoriza este dispositivo. Apenas lo hagan, la app del conductor seguira sola.',
                      style: const TextStyle(
                        color: Color(0xFF68779E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isRefreshing ? null : onRefresh,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF6BE00),
                          foregroundColor: const Color(0xFF101722),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          isRefreshing ? 'REVISANDO...' : 'ACTUALIZAR ESTADO',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverLoginShell extends StatelessWidget {
  const _DriverLoginShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FE),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFF2F6FF), Color(0xFFEAF1FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C5BFF).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7C81E).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const DriverLoginCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverDashboard extends ConsumerStatefulWidget {
  const _DriverDashboard({
    required this.onMenuTap,
    required this.onOpenTab,
    required this.openOffersFromDrawer,
    required this.onOffersDrawerHandled,
  });

  final VoidCallback onMenuTap;
  final ValueChanged<int> onOpenTab;
  final bool openOffersFromDrawer;
  final VoidCallback onOffersDrawerHandled;

  @override
  ConsumerState<_DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<_DriverDashboard>
    with AutomaticKeepAliveClientMixin {
  static const double _kFixedHeading = 75.6;
  static const double _kFixedZoom = 16.91;
  static const double _kFixedMapBearing = -14.6;
  static const String _wideMapModeKey = 'driver_dashboard_wide_map_mode';
  static const String _homeMapZoomKey = 'driver_dashboard_home_map_zoom';
  static const String _homeMapBearingKey = 'driver_dashboard_home_map_bearing';

  int _mapFocusSignal = 0;
  bool _mapReadyLogged = false;
  bool _wideMapMode = false;
  double? _savedHomeZoom;
  double? _savedHomeBearing;
  Timer? _mapViewPersistDebounce;
  Timer? _counterOfferRefresh;
  final String _debugMarkerStyle = 'rapigo';
  final double _debugMarkerScale = 1.08;
  final double _debugMarkerOffsetX = 0;
  final double _debugMarkerOffsetY = 0;
  String _streetChipLabel = 'Ubicacion actual';
  LatLng? _lastStreetLookupPoint;
  bool _resolvingStreetChip = false;
  bool _showResumeOverlay = false;
  double _resumeOverlayOpacity = 0;
  bool _resumeOverlayScheduled = false;
  String? _selectedIncomingOfferId;

  @override
  void initState() {
    super.initState();
    _counterOfferRefresh = Timer.periodic(const Duration(seconds: 5), (
      _,
    ) async {
      await ref.read(offeredTripProvider.notifier).loadOffer();
      if (mounted) await ref.read(driverOffersProvider.notifier).loadOffers();
    });
    unawaited(_restoreMapViewPreferences());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapReadyLogged) {
        return;
      }
      _mapReadyLogged = true;
      DriverStartupTrace.markMapReady();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshStreetChip(force: true));
    });
  }

  Future<void> _restoreMapViewPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final restoredWide = preferences.getBool(_wideMapModeKey);
    final restoredZoom = preferences.getDouble(_homeMapZoomKey);
    final restoredBearing = preferences.getDouble(_homeMapBearingKey);
    if (!mounted) {
      return;
    }
    setState(() {
      if (restoredWide != null) {
        _wideMapMode = restoredWide;
      }
      _savedHomeZoom = restoredZoom;
      _savedHomeBearing = restoredBearing;
    });
  }

  Future<void> _persistMapViewPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_wideMapModeKey, _wideMapMode);
    if (_savedHomeZoom != null) {
      await preferences.setDouble(_homeMapZoomKey, _savedHomeZoom!);
    }
    if (_savedHomeBearing != null) {
      await preferences.setDouble(_homeMapBearingKey, _savedHomeBearing!);
    }
  }

  void _scheduleMapViewPreferencesPersist() {
    _mapViewPersistDebounce?.cancel();
    _mapViewPersistDebounce = Timer(const Duration(milliseconds: 420), () {
      unawaited(_persistMapViewPreferences());
    });
  }

  void _onHomeMapTelemetry({
    required double zoom,
    required double cameraBearing,
  }) {
    final zoomChanged =
        _savedHomeZoom == null || (_savedHomeZoom! - zoom).abs() > 0.01;
    final bearingChanged =
        _savedHomeBearing == null ||
        (_savedHomeBearing! - cameraBearing).abs() > 0.01;
    if (!zoomChanged && !bearingChanged) {
      return;
    }
    _savedHomeZoom = zoom;
    _savedHomeBearing = cameraBearing;
    _scheduleMapViewPreferencesPersist();
  }

  Future<void> _refreshStreetChip({bool force = false}) async {
    if (!mounted) {
      return;
    }
    final point = LatLng(
      ref.read(driverStateProvider.select((s) => s.lat)),
      ref.read(driverStateProvider.select((s) => s.lng)),
    );
    final previous = _lastStreetLookupPoint;
    if (!force && previous != null) {
      final delta = const Distance().as(LengthUnit.Meter, previous, point);
      if (delta < 22) {
        return;
      }
    }
    if (_resolvingStreetChip) {
      return;
    }
    _resolvingStreetChip = true;
    _lastStreetLookupPoint = point;
    try {
      final details = await ref
          .read(geocodingServiceProvider)
          .reverseLookup(point);
      if (!mounted) {
        return;
      }
      final label = details.primary.trim().isNotEmpty
          ? details.primary.trim()
          : 'Ubicacion actual';
      setState(() {
        _streetChipLabel = label;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _streetChipLabel = 'Ubicacion actual';
      });
    } finally {
      _resolvingStreetChip = false;
    }
  }

  void _toggleAdvancedMapMode() {
    setState(() {
      _wideMapMode = !_wideMapMode;
      _savedHomeZoom = _wideMapMode ? (_kFixedZoom - 0.33) : _kFixedZoom;
      _savedHomeBearing ??= _kFixedMapBearing;
      _mapFocusSignal++;
    });
    unawaited(_persistMapViewPreferences());
    if (_wideMapMode) {
      unawaited(_refreshStreetChip(force: true));
    }
  }

  void _showHomeResumeOverlay() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showResumeOverlay = true;
      _resumeOverlayOpacity = 1;
    });
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() => _resumeOverlayOpacity = 0);
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _showResumeOverlay = false;
          _resumeOverlayScheduled = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _counterOfferRefresh?.cancel();
    _mapViewPersistDebounce?.cancel();
    super.dispose();
  }

  LatLngBounds? _buildDriverFocusBounds({
    required double driverLat,
    required double driverLng,
    DriverTrip? trip,
    bool previewingRoute = false,
  }) {
    if (trip == null) {
      return null;
    }
    final driverPoint = LatLng(driverLat, driverLng);
    if (previewingRoute) {
      final points = <LatLng>[
        driverPoint,
        LatLng(trip.pickupLat, trip.pickupLng),
      ];
      if (trip.destinationLat != null && trip.destinationLng != null) {
        points.add(LatLng(trip.destinationLat!, trip.destinationLng!));
      }
      return LatLngBounds.fromPoints(points);
    }
    if (trip.status == 'in_progress') {
      if (trip.destinationLat == null || trip.destinationLng == null) {
        return LatLngBounds.fromPoints([
          driverPoint,
          LatLng(trip.pickupLat, trip.pickupLng),
        ]);
      }
      return LatLngBounds.fromPoints([
        driverPoint,
        LatLng(trip.destinationLat!, trip.destinationLng!),
      ]);
    }
    if (const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status)) {
      return LatLngBounds.fromPoints([
        driverPoint,
        LatLng(trip.pickupLat, trip.pickupLng),
      ]);
    }
    return null;
  }

  Future<void> _openAvailableTripsPage({
    required DriverTrip? trip,
    required AsyncValue<List<DriverTrip>> offersAsync,
  }) async {
    final offers = offersAsync.value ?? const <DriverTrip>[];
    final pendingOffers = offers
        .where((item) => _hasPendingOffer(item))
        .toList(growable: false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DriverAvailableTripsPage(
          hasLiveTrip: _hasLiveTripStatus(trip),
          offersAsync: offersAsync,
          pendingOffers: pendingOffers,
          onViewDetails: (offer) {
            Navigator.of(context).pop();
            _showIncomingTripDetail(offer);
          },
          onAccept: (offer) {
            Navigator.of(context).pop();
            if (offer != null) _showIncomingTripDetail(offer);
          },
          onReject: (offer) async {
            await _rejectOfferForCurrentDriver(offer);
          },
          onExpired: () {
            ref.read(driverOffersProvider.notifier).loadOffers();
            ref.read(offeredTripProvider.notifier).loadOffer();
          },
        ),
      ),
    );
  }

  Future<void> _rejectOfferForCurrentDriver(DriverTrip offer) async {
    try {
      await ref.read(driverOffersProvider.notifier).rejectOffer(offer.id);
      final currentOffer = ref.read(offeredTripProvider).value;
      if (currentOffer?.id == offer.id) {
        await ref.read(offeredTripProvider.notifier).clearTrip();
      }
      await ref.read(driverOffersProvider.notifier).loadOffers();
      if (mounted) {
        showTopNotice(
          context,
          'Solicitud ignorada para tu conductor.',
          tone: NoticeTone.info,
        );
      }
    } catch (error) {
      if (mounted) {
        showTopNotice(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          tone: NoticeTone.error,
        );
      }
    }
  }

  bool _hasPendingOffer(DriverTrip? trip) {
    return trip != null &&
        const {'requested', 'searching'}.contains(trip.status);
  }

  bool _hasLiveTripStatus(DriverTrip? trip) {
    return trip != null &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(trip.status);
  }

  Color _driverStatusAccentColor(String status) {
    return switch (status) {
      'requested' ||
      'searching' ||
      'accepted' ||
      'arriving' => const Color(0xFFF97316),
      'at_pickup' => const Color(0xFF22C55E),
      'in_progress' => const Color(0xFF0EA5E9),
      'completed' => const Color(0xFF9CA3AF),
      _ => const Color(0xFFF97316),
    };
  }

  void _showAvailableTripsSheet({
    required AsyncValue<DriverTrip?> tripAsync,
    required DriverTrip? trip,
    required AsyncValue<List<DriverTrip>> offersAsync,
  }) {
    final offers = offersAsync.value ?? const <DriverTrip>[];
    final pendingOffers = offers
        .where((item) => _hasPendingOffer(item))
        .toList(growable: false);
    final accent = pendingOffers.isEmpty
        ? const Color(0xFFF97316)
        : _driverStatusAccentColor(pendingOffers.first.status);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111214),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFF4EC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.22),
                            const Color(0xFF1A1A1D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.32),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111214),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.local_taxi_rounded,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Viajes disponibles',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF4EC),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pendingOffers.isEmpty
                                      ? 'Revisa nuevas solicitudes apenas entren.'
                                      : 'Tienes ${pendingOffers.length} solicitudes listas para revisar y decidir.',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD8BF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111214),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '${pendingOffers.length}',
                              style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: offersAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => DriverEmptyCard(
                          title: 'No pudimos cargar ofertas',
                          subtitle: error.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                        ),
                        data: (_) {
                          if (pendingOffers.isEmpty) {
                            if (_hasLiveTripStatus(trip)) {
                              return const DriverEmptyCard(
                                title: 'Ya tienes un viaje en curso',
                                subtitle:
                                    'Termina o actualiza ese viaje para recibir una nueva solicitud.',
                              );
                            }
                            return const DriverEmptyCard(
                              title: 'No hay viajes disponibles',
                              subtitle:
                                  'En cuanto entre una nueva solicitud, la veras aqui.',
                            );
                          }

                          return ListView.separated(
                            itemCount: pendingOffers.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final pendingOffer = pendingOffers[index];
                              return _DriverAvailableTripCard(
                                trip: pendingOffer,
                                accentColor: _driverStatusAccentColor(
                                  pendingOffer.status,
                                ),
                                onViewDetails: () {
                                  Navigator.of(context).pop();
                                  _showIncomingTripDetail(pendingOffer);
                                },
                                onAccept: () async {
                                  Navigator.of(context).pop();
                                  await _handleDriverPrimaryAction(
                                    pendingOffer,
                                  );
                                },
                                onReject: () async {
                                  await _rejectOfferForCurrentDriver(
                                    pendingOffer,
                                  );
                                },
                                onExpired: () {
                                  ref
                                      .read(driverOffersProvider.notifier)
                                      .loadOffers();
                                  ref
                                      .read(offeredTripProvider.notifier)
                                      .loadOffer();
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showIncomingTripDetail(DriverTrip trip) {
    ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(trip.id);
    setState(() {
      _selectedIncomingOfferId = trip.id;
      _mapFocusSignal++;
    });
  }

  Future<void> _handleDriverPrimaryAction(DriverTrip? trip) async {
    if (trip == null) {
      return;
    }

    if (trip.status == 'requested' || trip.status == 'searching') {
      await _openOfferRoutePreview(trip);
      return;
    }

    try {
      if (trip.status == 'accepted') {
        final openedNavigation = await _openNavigationForTrip(trip);
        if (!openedNavigation) {
          return;
        }
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('arriving');
        return;
      }
      if (trip.status == 'arriving') {
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('at_pickup');
        return;
      }
      if (trip.status == 'at_pickup') {
        final destinationLabel = trip.destination.trim().toLowerCase();
        final destinationMissing =
            trip.destinationLat == null ||
            trip.destinationLng == null ||
            destinationLabel.isEmpty ||
            destinationLabel == 'destino no esta marcado' ||
            destinationLabel == 'destino por confirmar' ||
            destinationLabel == 'abordaje inmediato';
        if (destinationMissing) {
          if (mounted) {
            showTopNotice(
              context,
              'El pasajero aun no guardo el destino final. Espera a que lo marque para iniciar el viaje.',
              tone: NoticeTone.warning,
            );
          }
          return;
        }
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('in_progress');
        await _openNavigationForTrip(trip.copyWith(status: 'in_progress'));
        if (trip.isPromotional && mounted) {
          showTopNotice(
            context,
            'Este viaje es gratis. El pasajero se gano la promocion.',
            tone: NoticeTone.success,
          );
        }
        return;
      }
      if (trip.status == 'in_progress') {
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('completed');
        await ref.read(driverOffersProvider.notifier).loadOffers();
        return;
      }
    } catch (error) {
      if (mounted) {
        showTopNotice(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          tone: NoticeTone.error,
        );
      }
    }
  }

  Future<void> _openOfferRoutePreview(DriverTrip trip) async {
    ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(trip.id);
    setState(() {
      _selectedIncomingOfferId = trip.id;
      _mapFocusSignal++;
    });
  }

  trip_navigation.NavigationTarget? _navigationTargetForTrip(DriverTrip trip) {
    if (const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status)) {
      return trip_navigation.NavigationTarget(
        latitude: trip.pickupLat,
        longitude: trip.pickupLng,
        label: _primaryAddress(trip.passengerPickup),
      );
    }
    if (trip.status == 'in_progress' &&
        trip.destinationLat != null &&
        trip.destinationLng != null) {
      return trip_navigation.NavigationTarget(
        latitude: trip.destinationLat!,
        longitude: trip.destinationLng!,
        label: _primaryAddress(trip.destination),
      );
    }
    return null;
  }

  String _primaryAddress(String raw) {
    final parts = raw.split(',');
    return parts.first.trim().isEmpty ? raw : parts.first.trim();
  }

  Future<bool> _openNavigationForTrip(DriverTrip trip) async {
    final target = _navigationTargetForTrip(trip);
    if (target == null) {
      showTopNotice(
        context,
        'No hay coordenadas suficientes para navegar.',
        tone: NoticeTone.warning,
      );
      return false;
    }
    final service = ref.read(trip_navigation.navigationServiceProvider);
    final preference = await service.loadPreference();
    var provider = service.providerForPreference(preference);
    if (provider == null) {
      provider = await _showNavigationProviderPicker(target);
      if (provider == null) {
        return false;
      }
    }
    final result = await service.launch(provider, target);
    if (!mounted) {
      return result.provider == trip_navigation.NavigationProvider.rapigo ||
          result.openedExternalApp;
    }
    if (result.usedFallback) {
      showTopNotice(
        context,
        '${provider.label} no esta disponible. Seguimos navegando dentro de RAPIGO.',
        tone: NoticeTone.warning,
        icon: Icons.navigation_rounded,
      );
    } else if (result.provider == trip_navigation.NavigationProvider.rapigo) {
      showTopNotice(
        context,
        'Navegacion RAPIGO activa hacia ${target.label}.',
        tone: NoticeTone.info,
        icon: Icons.navigation_rounded,
      );
    }
    return true;
  }

  Future<trip_navigation.NavigationProvider?> _showNavigationProviderPicker(
    trip_navigation.NavigationTarget target,
  ) async {
    final service = ref.read(trip_navigation.navigationServiceProvider);
    final providers = await service.availableProviders();
    if (!mounted) {
      return null;
    }
    return showModalBottomSheet<trip_navigation.NavigationProvider>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = context.rapigoPalette;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.outlineStrong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplicacion de navegacion',
                  style: GoogleFonts.plusJakartaSans(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Destino: ${target.label}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (final provider in providers) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      provider == trip_navigation.NavigationProvider.rapigo
                          ? Icons.navigation_rounded
                          : provider == trip_navigation.NavigationProvider.waze
                          ? Icons.assistant_direction_rounded
                          : Icons.map_rounded,
                      color: palette.accentBlue,
                    ),
                    title: Text(
                      provider.label,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      provider.description,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                    onTap: () => Navigator.of(context).pop(provider),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHomeQuickSheet({
    required bool available,
    required String fullName,
    required DriverTrip? trip,
    required AsyncValue<List<DriverTrip>> offersAsync,
  }) async {
    final firstName = fullName.trim().isNotEmpty
        ? fullName.trim().split(' ').first
        : 'Perfil pendiente';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.88,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'assets/icons/rapigo_driver_icon.png',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, $firstName',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onOpenTab(4);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFEAF2FF),
                                    foregroundColor: const Color(0xFF1D4ED8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Ver perfil'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 34),
                          color: const Color(0xFF4B5563),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Navegador',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _HomeNavigatorCard(
                                  icon: Icons.bar_chart_rounded,
                                  label: 'Estadistica',
                                  accent: const Color(0xFF1D4ED8),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onOpenTab(1);
                                  },
                                ),
                                _HomeNavigatorCard(
                                  icon: Icons.local_taxi_rounded,
                                  label: 'Viajes',
                                  accent: const Color(0xFF0F172A),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onOpenTab(2);
                                  },
                                ),
                                _HomeNavigatorCard(
                                  icon: Icons.inventory_2_rounded,
                                  label: 'Pedidos',
                                  accent: const Color(0xFFF59E0B),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onOpenTab(3);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Accesos directos',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _HomeQuickActionTile(
                              icon: Icons.local_taxi_rounded,
                              label: 'Viajes disponibles',
                              onTap: () {
                                Navigator.of(context).pop();
                                _openAvailableTripsPage(
                                  trip: trip,
                                  offersAsync: offersAsync,
                                );
                              },
                            ),
                            _HomeQuickActionTile(
                              icon: Icons.notifications_none_rounded,
                              label: 'Notificaciones',
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DriverNotificationsPage(),
                                  ),
                                );
                              },
                            ),
                            _HomeQuickActionTile(
                              icon: Icons.settings_outlined,
                              label: 'Ajustes',
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DriverSettingsPage(),
                                  ),
                                );
                              },
                            ),
                            _HomeQuickActionTile(
                              icon: Icons.support_agent_rounded,
                              label: 'Soporte',
                              onTap: () {
                                Navigator.of(context).pop();
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const DriverSupportPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDriverCenterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.56,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6DBE5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Centro del conductor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Accesos y herramientas rapidas para tu operacion diaria.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        children: [
                          _HomeQuickActionTile(
                            icon: Icons.my_location_rounded,
                            label: 'Actualizar GPS',
                            onTap: () async {
                              Navigator.of(context).pop();
                              await ref
                                  .read(driverStateProvider.notifier)
                                  .refreshLocation();
                              if (!mounted) return;
                              setState(() => _mapFocusSignal++);
                              final gpsError = ref
                                  .read(driverStateProvider)
                                  .errorMessage;
                              if (gpsError != null &&
                                  gpsError.trim().isNotEmpty) {
                                showTopNotice(
                                  this.context,
                                  gpsError,
                                  tone: NoticeTone.error,
                                );
                                return;
                              }
                              showTopNotice(
                                this.context,
                                'Ubicacion actualizada en el mapa.',
                                tone: NoticeTone.success,
                              );
                            },
                          ),
                          _HomeQuickActionTile(
                            icon: _wideMapMode
                                ? Icons.splitscreen_rounded
                                : Icons.fullscreen_rounded,
                            label: _wideMapMode
                                ? 'Vista compacta'
                                : 'Vista amplia',
                            onTap: () {
                              Navigator.of(context).pop();
                              _toggleAdvancedMapMode();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(driverStateProvider.select((s) => (s.lat, s.lng)), (_, next) {
      unawaited(_refreshStreetChip());
    });
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    ref.listen<String?>(driverStateProvider.select((s) => s.errorMessage), (
      previous,
      next,
    ) {
      if (next == null || next.trim().isEmpty || next == previous) {
        return;
      }
      showTopNotice(
        context,
        next,
        tone: NoticeTone.error,
        compact: true,
        centered: true,
      );
    });
    final available = ref.watch(driverStateProvider.select((s) => s.available));
    final driverLat = ref.watch(driverStateProvider.select((s) => s.lat));
    final driverLng = ref.watch(driverStateProvider.select((s) => s.lng));
    final driverHeading = _kFixedHeading;
    final speedKph = ref.watch(
      driverStateProvider.select((s) => s.speedKph ?? 0),
    );
    final tripAsync = ref.watch(offeredTripProvider);
    final offersAsync = ref.watch(driverOffersProvider);
    final trip = tripAsync.value;
    final offers = offersAsync.value ?? const <DriverTrip>[];
    final previewTripId = ref.watch(driverOfferPreviewTripIdProvider);
    final shouldResumeHome = ref.watch(driverHomeResumeOverlayProvider);
    final pendingOffers = <DriverTrip>[
      if (_hasPendingOffer(trip)) trip!,
      ...offers.where(
        (item) =>
            _hasPendingOffer(item) &&
            (!_hasPendingOffer(trip) || item.id != trip!.id),
      ),
    ];
    final selectedIncomingOffer = pendingOffers
        .where((offer) => offer.id == _selectedIncomingOfferId)
        .firstOrNull;
    final incomingOverlayTrip = trip?.hasPendingCounterOffer == true
        ? trip
        : selectedIncomingOffer;
    final isPreviewingRoute =
        incomingOverlayTrip != null && previewTripId == incomingOverlayTrip.id;
    final mapTrip =
        incomingOverlayTrip ?? (_hasLiveTripStatus(trip) ? trip : null);
    final mapTripStatus =
        incomingOverlayTrip != null && _hasPendingOffer(incomingOverlayTrip)
        ? 'accepted'
        : mapTrip?.status;
    final showIncomingRouteOnMap = incomingOverlayTrip != null;
    final defaultHomeIdleZoom = _wideMapMode
        ? (_kFixedZoom - 0.33)
        : _kFixedZoom;
    final defaultHomeIdleBearing = _savedHomeBearing ?? _kFixedMapBearing;
    final homeIdleZoom = _savedHomeZoom ?? defaultHomeIdleZoom;
    final routeColor = trip?.status == 'in_progress'
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFF97316);
    final focusBounds = _buildDriverFocusBounds(
      driverLat: driverLat,
      driverLng: driverLng,
      trip: mapTrip,
      previewingRoute: showIncomingRouteOnMap,
    );
    final session = ref.watch(driverSessionProvider);
    if (widget.openOffersFromDrawer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onOffersDrawerHandled();
        _showAvailableTripsSheet(
          tripAsync: tripAsync,
          trip: trip,
          offersAsync: offersAsync,
        );
      });
    }
    if (shouldResumeHome && !_resumeOverlayScheduled) {
      _resumeOverlayScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(driverHomeResumeOverlayProvider.notifier).clear();
        _showHomeResumeOverlay();
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DriverMapSurface(
              viewportCacheKey: 'driver_shared_premium_map',
              routePersistenceKey: mapTrip == null
                  ? null
                  : 'driver_trip_route_${mapTrip.id}',
              routePersistenceReadKeys: mapTrip == null
                  ? null
                  : driverTripRouteReadKeys(
                      mapTrip.id,
                      mapTripStatus ?? mapTrip.status,
                    ),
              routePersistenceWriteKeys: mapTrip == null
                  ? null
                  : driverTripRouteWriteKeys(
                      mapTrip.id,
                      mapTripStatus ?? mapTrip.status,
                    ),
              prefetchRoutePersistenceKey: mapTrip == null
                  ? null
                  : driverTripRoutePrefetchKey(
                      mapTrip.id,
                      mapTripStatus ?? mapTrip.status,
                    ),
              available: available,
              tripAccepted:
                  showIncomingRouteOnMap ||
                  const {
                    'accepted',
                    'arriving',
                    'at_pickup',
                    'in_progress',
                  }.contains(mapTrip?.status),
              driverLat: driverLat,
              driverLng: driverLng,
              headingDegrees: driverHeading,
              vehicleType: (mapTrip?.vehicleType?.isNotEmpty ?? false)
                  ? mapTrip!.vehicleType!
                  : session.vehicleType,
              tripStatus: mapTripStatus,
              pickupLat: mapTrip?.pickupLat,
              pickupLng: mapTrip?.pickupLng,
              destinationLat: mapTrip?.destinationLat,
              destinationLng: mapTrip?.destinationLng,
              idleZoomLevel: homeIdleZoom,
              maxZoomPreference: 16.5,
              idleTilt: 0,
              idleBearingOverride: defaultHomeIdleBearing,
              navigationTilt: 0,
              driverMarkerScale: _debugMarkerScale,
              driverMarkerOffsetX: _debugMarkerOffsetX,
              driverMarkerOffsetY: _debugMarkerOffsetY,
              driverMarkerStyle: _debugMarkerStyle,
              showStatusBadge: false,
              routeColor: routeColor,
              focusBounds: focusBounds,
              focusSignal: _mapFocusSignal,
              lockToFocusBounds: showIncomingRouteOnMap,
              onDebugTelemetryChanged:
                  ({
                    required double centerLat,
                    required double centerLng,
                    required double zoom,
                    required double tilt,
                    required double cameraBearing,
                    required double iconBearing,
                    required double displayLat,
                    required double displayLng,
                  }) {
                    _onHomeMapTelemetry(
                      zoom: zoom,
                      cameraBearing: cameraBearing,
                    );
                  },
              onRouteUpdated: () {
                if (!mounted) {
                  return;
                }
                if (showIncomingRouteOnMap) {
                  return;
                }
                showTopNotice(
                  context,
                  'Ruta actualizada. La app ya corrigio el camino.',
                  tone: NoticeTone.info,
                );
              },
              onOfflineRouteRetained: () {
                if (!mounted) {
                  return;
                }
                showTopNotice(
                  context,
                  '',
                  tone: NoticeTone.info,
                  icon: Icons.cloud_off_rounded,
                  compact: true,
                  iconOnly: true,
                  rightSide: true,
                  duration: const Duration(seconds: 3),
                  backgroundColor: const Color(0xF40B1220),
                  foregroundColor: const Color(0xFFFACC15),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFFFFF).withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFFFFFFFF).withValues(alpha: 0.12),
                  ],
                  stops: const [0, 0.20, 0.62, 1],
                ),
              ),
            ),
          ),
        ),
        if (incomingOverlayTrip == null)
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.pagePadding,
                10,
                metrics.pagePadding,
                14,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: DriverHomeHeader(
                      available: available,
                      onMenuTap: () => _openHomeQuickSheet(
                        available: available,
                        fullName: session.fullName,
                        trip: trip,
                        offersAsync: offersAsync,
                      ),
                      onAvailabilityTap: () async {
                        await ref
                            .read(driverStateProvider.notifier)
                            .toggleAvailability(!available);
                      },
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 100,
                    child: _DriverSpeedBubble(speedKph: speedKph),
                  ),
                  Positioned(
                    left: 0,
                    right: 72,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDFEFE),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x200D1828),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            color: Color(0xFF087F5B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'CALLE ACTUAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _streetChipLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0D1828),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 22,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 40,
                      ),
                      child: DriverHomeFab(
                        vehicleLabel: session.vehicleType.isEmpty
                            ? 'Vehículo'
                            : session.vehicleType,
                        onCenter: _openDriverCenterSheet,
                        onMapMode: _toggleAdvancedMapMode,
                        onOffers: () => _openAvailableTripsPage(
                          trip: trip,
                          offersAsync: offersAsync,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (incomingOverlayTrip != null)
          _DriverIncomingRequestOverlay(
            trip: incomingOverlayTrip,
            isPreviewingRoute: isPreviewingRoute,
            onClose: () {
              setState(() => _selectedIncomingOfferId = null);
              ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(null);
              _openAvailableTripsPage(trip: trip, offersAsync: offersAsync);
            },
          ),
        if (_showResumeOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _resumeOverlayOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFFFFFFF).withValues(alpha: 0.08),
                        const Color(0xFFF8FBFF).withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF20B1220),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6EA8FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Cargando inicio...',
                            style: textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeQuickActionTile extends StatelessWidget {
  const _HomeQuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Icon(icon, size: 30, color: const Color(0xFF111111)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeNavigatorCard extends StatelessWidget {
  const _HomeNavigatorCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 60) / 2,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverSpeedBubble extends StatelessWidget {
  const _DriverSpeedBubble({required this.speedKph});

  final double speedKph;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF252A34),
        border: Border.all(color: const Color(0xFF4B5563), width: 2.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            speedKph.isFinite ? speedKph.round().toString() : '0',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'km/h',
            style: TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTripsTab extends ConsumerWidget {
  const _DriverTripsTab({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.rapigoPalette;
    final historyAsync = ref.watch(driverTripHistoryProvider);
    return DriverPageShell(
      eyebrow: 'Actividad',
      title: 'Tus viajes',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: palette.surfacePrimary,
                foregroundColor: palette.textPrimary,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      child: historyAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => DriverEmptyCard(
          title: 'No pudimos cargar el historial',
          subtitle: error.toString().replaceFirst('Exception: ', ''),
        ),
        data: (history) {
          if (history.isEmpty) {
            return const DriverEmptyCard(
              title: 'Todavia no hay viajes',
              subtitle:
                  'Activa disponibilidad para empezar a recibir solicitudes reales.',
            );
          }

          return Column(
            children: [
              for (final item in history) ...[
                _DriverHistoryCard(
                  trip: item,
                  title:
                      const {
                        'accepted',
                        'arriving',
                        'at_pickup',
                        'in_progress',
                      }.contains(item.status)
                      ? 'Viaje actual'
                      : 'Viaje realizado',
                  isCurrentTrip: const {
                    'accepted',
                    'arriving',
                    'at_pickup',
                    'in_progress',
                  }.contains(item.status),
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DriverAccountTab extends ConsumerWidget {
  const _DriverAccountTab({
    required this.fullName,
    required this.phone,
    this.onBack,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final String fullName;
  final String phone;
  final VoidCallback? onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    return DriverPageShell(
      eyebrow: 'Cuenta',
      title: 'Perfil del conductor',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: palette.surfacePrimary,
                foregroundColor: palette.textPrimary,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      trailing: IconButton.filledTonal(
        onPressed: onOpenProfile,
        style: IconButton.styleFrom(
          backgroundColor: palette.surfacePrimary,
          foregroundColor: palette.accentYellow,
        ),
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: palette.surfacePrimary,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: palette.outlineStrong),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: palette.surfaceSecondary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 36,
                    color: palette.textPrimary,
                  ),
                ),
                SizedBox(width: metrics.itemGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phone,
                        style: textTheme.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DriverMenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notificaciones',
            subtitle:
                'Avisos de central, autorizaciones y mensajes operativos.',
            onTap: onOpenNotifications,
          ),
          const SizedBox(height: 14),
          DriverMenuTile(
            icon: Icons.settings_outlined,
            title: 'Descarga de mapa',
            subtitle:
                'Guarda Potosi ciudad para usar el mapa aun con señal baja.',
            onTap: onOpenSettings,
          ),
          const SizedBox(height: 14),
          DriverMenuTile(
            icon: Icons.support_agent,
            title: 'Soporte',
            subtitle:
                'Reporta fallas de la app o incidencias del servicio a central.',
            onTap: onOpenHelp,
          ),
        ],
      ),
    );
  }
}

class _DriverCompactInfoRow extends StatelessWidget {
  const _DriverCompactInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9F978F),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverHomeOfferCard extends StatelessWidget {
  const _DriverHomeOfferCard({
    required this.trip,
    required this.isPreviewingRoute,
    required this.pickupDistanceLabel,
    required this.pickupEtaLabel,
    required this.onReject,
    required this.onPrimaryAction,
    required this.onExpired,
    required this.onCounterOffer,
  });

  final DriverTrip trip;
  final bool isPreviewingRoute;
  final String pickupDistanceLabel;
  final String pickupEtaLabel;
  final VoidCallback onReject;
  final VoidCallback onPrimaryAction;
  final VoidCallback onExpired;
  final VoidCallback onCounterOffer;

  @override
  Widget build(BuildContext context) {
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';
    final pending = trip.hasPendingCounterOffer;
    final expiresAt = pending ? null : _visibleOfferExpiresAt(trip);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1828),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF29374A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pending
                ? 'Esperando al pasajero'
                : isPreviewingRoute
                ? 'Revisa la ruta y ofrece'
                : 'Un nuevo viaje para ti',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pending
                ? 'Propusiste Bs ${trip.counterOfferAmount?.toStringAsFixed(2)}. El viaje continúa solo si el pasajero acepta.'
                : isPreviewingRoute
                ? 'El pasajero elegirá entre las ofertas que reciba.'
                : 'Revisa la recogida y el destino antes de enviar tu oferta.',
            style: const TextStyle(
              color: Color(0xFFADBBD0),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _DriverOfferFarePanel(trip: trip),
          if (trip.myOfferStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                trip.myOfferStatus == 'pending'
                    ? 'Tu oferta: Bs ${trip.myOfferAmount?.toStringAsFixed(2)} · Esperando respuesta'
                    : trip.myOfferStatus == 'ignored'
                    ? 'El pasajero ignoró tu oferta.'
                    : 'Revisa el recorrido y vuelve a enviar tu oferta.',
                style: const TextStyle(color: Color(0xFFFFC400)),
              ),
            ),
          const SizedBox(height: 16),
          DriverRequestRoute(
            pickup: trip.passengerPickup,
            destination: trip.destination,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _DriverRequestTopMetric(
                icon: Icons.near_me_outlined,
                label: '$pickupDistanceLabel a recogida',
                color: const Color(0xFFFFC400),
              ),
              _DriverRequestTopMetric(
                icon: Icons.schedule_rounded,
                label: '~$pickupEtaLabel',
                color: const Color(0xFFADBBD0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DriverRequestPassengerBlock(
            passengerName: passengerName,
            passengerPhone: (trip.passengerPhone ?? '').trim(),
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 12),
            _DriverOfferCountdown(
              expiresAt: expiresAt,
              onExpired: onExpired,
              showLabel: true,
              compact: true,
            ),
          ],
          const SizedBox(height: 16),
          if (!pending &&
              !trip.isPromotional &&
              trip.myOfferStatus != 'ignored') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCounterOffer,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC400),
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Proponer otro precio'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Cancelar solicitud'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF536176)),
                      minimumSize: const Size(0, 54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Ignorar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: trip.myOfferStatus == 'ignored'
                        ? null
                        : onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC400),
                      foregroundColor: const Color(0xFF0D1828),
                      minimumSize: const Size(0, 54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Ofrecer Bs ${trip.fareAmount.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DriverRequestTopMetric extends StatelessWidget {
  const _DriverRequestTopMetric({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverOfferFarePanel extends StatelessWidget {
  const _DriverOfferFarePanel({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    final paymentIcon = trip.paymentMethod == 'qr'
        ? Icons.qr_code_2_rounded
        : Icons.payments_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33FFC400)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC400),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: Color(0xFF091223),
              size: 24,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Oferta del pasajero',
                style: TextStyle(
                  color: Color(0xFFB9C4D6),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bs ${trip.fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1422),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x243A4558)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(paymentIcon, color: const Color(0xFFFFC400), size: 18),
                const SizedBox(width: 7),
                Text(
                  trip.paymentMethodLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverRequestPassengerBlock extends StatelessWidget {
  const _DriverRequestPassengerBlock({
    required this.passengerName,
    required this.passengerPhone,
  });

  final String passengerName;
  final String passengerPhone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1726),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x243A4558)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC400).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFFFFC400),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passengerName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (passengerPhone.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    passengerPhone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _visibleOfferExpiresAt(DriverTrip trip) => trip.offerExpiresAt;

class _DriverIncomingRequestOverlay extends ConsumerWidget {
  const _DriverIncomingRequestOverlay({
    required this.trip,
    required this.isPreviewingRoute,
    required this.onClose,
  });

  final DriverTrip trip;
  final bool isPreviewingRoute;
  final VoidCallback onClose;

  double _distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (endLat - startLat) * math.pi / 180;
    final dLng = (endLng - startLng) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(startLat * math.pi / 180) *
            math.cos(endLat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatEta(double meters) {
    final minutes = (meters / 320).clamp(1, 99).round();
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(driverStateProvider);
    final pickupDistance = _distanceMeters(
      startLat: driverState.lat,
      startLng: driverState.lng,
      endLat: trip.pickupLat,
      endLng: trip.pickupLng,
    );
    final double destinationDistance =
        trip.destinationLat != null && trip.destinationLng != null
        ? _distanceMeters(
            startLat: trip.pickupLat,
            startLng: trip.pickupLng,
            endLat: trip.destinationLat!,
            endLng: trip.destinationLng!,
          )
        : 0.0;
    final pickupDistanceLabel = _formatDistance(pickupDistance);
    final pickupEtaLabel = _formatEta(pickupDistance);
    final destinationDistanceLabel =
        trip.destinationLat != null && trip.destinationLng != null
        ? _formatDistance(destinationDistance)
        : '--';
    final destinationEtaLabel =
        trip.destinationLat != null && trip.destinationLng != null
        ? _formatEta(destinationDistance)
        : '--';

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x1A05111F),
                    const Color(0x1205111F),
                    const Color(0xA606111F),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: onClose,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1828),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver a solicitudes'),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE90A162A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x33FFC400)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: Color(0xFFFFC400),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            trip.hasPendingCounterOffer
                                ? 'Contraoferta enviada'
                                : isPreviewingRoute
                                ? 'Recorrido reservado'
                                : 'Solicitud entrante',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPreviewingRoute)
                      _DriverPreviewRouteBadge(
                        pickupEtaLabel: pickupEtaLabel,
                        pickupDistanceLabel: pickupDistanceLabel,
                        destinationEtaLabel: destinationEtaLabel,
                        destinationDistanceLabel: destinationDistanceLabel,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _DriverHomeOfferCard(
                          trip: trip,
                          isPreviewingRoute: isPreviewingRoute,
                          pickupDistanceLabel: pickupDistanceLabel,
                          pickupEtaLabel: pickupEtaLabel,
                          onCounterOffer: () => showDialog<void>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => DriverCounterOfferDialog(
                              originalFare: trip.fareAmount,
                              onSubmit: (amount) => ref
                                  .read(offeredTripProvider.notifier)
                                  .sendCounterOffer(trip, amount),
                            ),
                          ),
                          onExpired: () {
                            ref
                                .read(driverOffersProvider.notifier)
                                .loadOffers();
                            ref.read(offeredTripProvider.notifier).loadOffer();
                            ref
                                .read(driverOfferPreviewTripIdProvider.notifier)
                                .setTrip(null);
                          },
                          onReject: () async {
                            try {
                              if (trip.hasPendingCounterOffer) {
                                await ref
                                    .read(offeredTripProvider.notifier)
                                    .updateTripStatus('cancelled');
                                await ref
                                    .read(offeredTripProvider.notifier)
                                    .loadOffer();
                                return;
                              }
                              if (isPreviewingRoute) {
                                ref
                                    .read(
                                      driverOfferPreviewTripIdProvider.notifier,
                                    )
                                    .setTrip(null);
                              }
                              await ref
                                  .read(driverOffersProvider.notifier)
                                  .rejectOffer(trip.id);
                              final currentOffer = ref
                                  .read(offeredTripProvider)
                                  .value;
                              if (currentOffer?.id == trip.id) {
                                await ref
                                    .read(offeredTripProvider.notifier)
                                    .clearTrip();
                              }
                              await ref
                                  .read(driverOffersProvider.notifier)
                                  .loadOffers();
                              if (context.mounted) {
                                showTopNotice(
                                  context,
                                  'Solicitud ignorada para tu conductor.',
                                  tone: NoticeTone.info,
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showTopNotice(
                                  context,
                                  error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                  tone: NoticeTone.error,
                                );
                              }
                            }
                          },
                          onPrimaryAction: () async {
                            try {
                              await ref
                                  .read(offeredTripProvider.notifier)
                                  .sendCounterOffer(trip, trip.fareAmount);
                              if (context.mounted) {
                                showTopNotice(
                                  context,
                                  'Oferta enviada. Espera que el pasajero te elija.',
                                  tone: NoticeTone.success,
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showTopNotice(
                                  context,
                                  error.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                  tone: NoticeTone.warning,
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverPreviewRouteBadge extends StatelessWidget {
  const _DriverPreviewRouteBadge({
    required this.pickupEtaLabel,
    required this.pickupDistanceLabel,
    required this.destinationEtaLabel,
    required this.destinationDistanceLabel,
  });

  final String pickupEtaLabel;
  final String pickupDistanceLabel;
  final String destinationEtaLabel;
  final String destinationDistanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE60B1730),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x4D55A4FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D001C46),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF55A4FF), Color(0xFF2979FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pickupEtaLabel · $pickupDistanceLabel',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hasta recogida',
                  style: const TextStyle(
                    color: Color(0xFFA8C7F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFF7DB7FF),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$destinationEtaLabel · $destinationDistanceLabel al destino',
                        style: const TextStyle(
                          color: Color(0xFFD7E7FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAvailableTripsPage extends ConsumerWidget {
  const _DriverAvailableTripsPage({
    required this.hasLiveTrip,
    required this.offersAsync,
    required this.pendingOffers,
    required this.onViewDetails,
    required this.onAccept,
    required this.onReject,
    required this.onExpired,
  });

  final bool hasLiveTrip;
  final AsyncValue<List<DriverTrip>> offersAsync;
  final List<DriverTrip> pendingOffers;
  final ValueChanged<DriverTrip> onViewDetails;
  final ValueChanged<DriverTrip?> onAccept;
  final ValueChanged<DriverTrip> onReject;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(driverOffersProvider);
    final pendingOffers = offersAsync.value ?? const <DriverTrip>[];
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07111F),
        foregroundColor: Colors.white,
        title: Text(
          'Solicitudes · Pedir taxi',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: offersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => DriverEmptyCard(
              title: 'No pudimos cargar ofertas',
              subtitle: error.toString().replaceFirst('Exception: ', ''),
            ),
            data: (_) {
              if (pendingOffers.isEmpty) {
                if (hasLiveTrip) {
                  return const DriverEmptyCard(
                    title: 'Ya tienes un viaje en curso',
                    subtitle:
                        'Termina o actualiza ese viaje para recibir una nueva solicitud.',
                  );
                }
                return const DriverEmptyCard(
                  title: 'No hay viajes disponibles',
                  subtitle:
                      'En cuanto entre una nueva solicitud, la veras aqui.',
                );
              }

              return ListView.separated(
                itemCount: pendingOffers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final pendingOffer = pendingOffers[index];
                  return _DriverAvailableTripCard(
                    trip: pendingOffer,
                    accentColor: const Color(0xFFFFC400),
                    onViewDetails: () => onViewDetails(pendingOffer),
                    onAccept: () => onAccept(pendingOffer),
                    onReject: () => onReject(pendingOffer),
                    onExpired: onExpired,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DriverOfferCountdown extends StatefulWidget {
  const _DriverOfferCountdown({
    required this.expiresAt,
    required this.onExpired,
    this.compact = false,
    this.showLabel = false,
  });

  final String expiresAt;
  final VoidCallback onExpired;
  final bool compact;
  final bool showLabel;

  @override
  State<_DriverOfferCountdown> createState() => _DriverOfferCountdownState();
}

class _DriverOfferCountdownState extends State<_DriverOfferCountdown> {
  Timer? _timer;
  late DateTime? _expiresAt;
  late int _initialSeconds;
  bool _notifiedExpired = false;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant _DriverOfferCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) {
      _configure();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _configure() {
    _timer?.cancel();
    _expiresAt = DateTime.tryParse(widget.expiresAt)?.toLocal();
    _initialSeconds = _remainingSeconds().clamp(1, 999).toInt();
    _notifiedExpired = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final remaining = _remainingSeconds();
      if (remaining <= 0 && !_notifiedExpired) {
        _notifiedExpired = true;
        widget.onExpired();
      }
      setState(() {});
    });
  }

  int _remainingSeconds() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) {
      return 0;
    }
    return expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingSeconds();
    final progress = _initialSeconds <= 0
        ? 0.0
        : (remaining / _initialSeconds).clamp(0.0, 1.0).toDouble();
    final urgent = remaining <= 5;
    final color = urgent ? const Color(0xFFFB7185) : const Color(0xFFFFC400);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 16,
        vertical: widget.compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: widget.compact ? 0.12 : 0.16),
        borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
        border: Border.all(
          color: color.withValues(alpha: widget.compact ? 0.32 : 0.52),
          width: widget.compact ? 1 : 1.4,
        ),
        boxShadow: widget.compact
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showLabel) ...[
            Text(
              'Tiempo para aceptar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: widget.compact ? 10 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: widget.compact ? 5 : 8),
          ],
          Row(
            children: [
              Icon(
                Icons.timer_rounded,
                color: color,
                size: widget.compact ? 16 : 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: widget.compact ? 6 : 8,
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                remaining > 0 ? '${remaining}s' : '0s',
                style: TextStyle(
                  color: color,
                  fontSize: widget.compact ? 12 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverAvailableTripCard extends StatelessWidget {
  const _DriverAvailableTripCard({
    required this.trip,
    required this.accentColor,
    required this.onViewDetails,
    required this.onAccept,
    required this.onReject,
    required this.onExpired,
  });

  final DriverTrip trip;
  final Color accentColor;
  final VoidCallback onViewDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onExpired;

  @override
  Widget build(BuildContext context) {
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';
    const rejectLabel = 'Ignorar';
    final requestBadgeLabel = trip.isDirectedRequest ? 'Directa' : 'Abierta';
    final requestBadgeColor = trip.isDirectedRequest
        ? const Color(0xFFFF7A59)
        : const Color(0xFF38BDF8);
    final freshnessBadgeLabel = trip.isPromotional ? 'Promo' : 'Nueva';
    final freshnessBadgeColor = trip.isPromotional
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFFC400);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(switch ((trip.vehicleType ?? '').toLowerCase()) {
                  'moto' => Icons.two_wheeler_rounded,
                  _ => Icons.local_taxi_rounded,
                }, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(trip.vehicleType ?? 'taxi').toUpperCase()} solicitado',
                      style: const TextStyle(
                        color: Color(0xFFFFC89B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: requestBadgeColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      requestBadgeLabel,
                      style: TextStyle(
                        color: requestBadgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: freshnessBadgeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      freshnessBadgeLabel,
                      style: TextStyle(
                        color: freshnessBadgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTile(
            label: 'Precio',
            value: 'Bs ${trip.fareAmount.toStringAsFixed(2)}',
          ),
          if (trip.myOfferStatus != null)
            _InfoTile(
              label: 'Tu oferta',
              value:
                  'Bs ${trip.myOfferAmount?.toStringAsFixed(2)} · ${trip.myOfferStatus == 'pending' ? 'Enviada' : 'Ignorada'}',
            ),
          _InfoTile(label: 'Recojo', value: trip.passengerPickup),
          _InfoTile(label: 'Destino', value: trip.destination),
          if (trip.passengerPhone?.trim().isNotEmpty ?? false)
            _InfoTile(label: 'Telefono', value: trip.passengerPhone!.trim()),
          if (trip.offerExpiresAt?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            _DriverOfferCountdown(
              expiresAt: trip.offerExpiresAt!,
              onExpired: onExpired,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD8BF),
                    side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Ver detalle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC9C9),
                    side: const BorderSide(color: Color(0x44EF4444)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(rejectLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: const Color(0xFF0F0F10),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Ver ruta',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFD8BF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTripProgressBar extends StatelessWidget {
  const _DriverTripProgressBar({required this.status});

  final String status;

  static const _steps = [
    ('searching', 'Solicitud'),
    ('accepted', 'Aceptado'),
    ('arriving', 'En camino'),
    ('at_pickup', 'Llego'),
    ('in_progress', 'En curso'),
    ('completed', 'Finalizado'),
  ];

  int get _activeIndex {
    switch (status) {
      case 'requested':
      case 'searching':
        return 0;
      case 'accepted':
        return 1;
      case 'arriving':
        return 2;
      case 'at_pickup':
        return 3;
      case 'in_progress':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final segmentIndex = index ~/ 2;
              final isActive = segmentIndex < _activeIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFF97316)
                        : const Color(0x55F97316),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final isReached = stepIndex <= _activeIndex;
            return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isReached
                    ? const Color(0xFFF97316)
                    : const Color(0xFF25252B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReached
                      ? const Color(0xFFF97316)
                      : const Color(0x55F97316),
                ),
              ),
              child: Icon(
                isReached ? Icons.check : Icons.circle,
                size: isReached ? 14 : 8,
                color: isReached
                    ? const Color(0xFF0F0F10)
                    : const Color(0xFFFFC89B),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _steps.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value.$2;
            final highlighted = index <= _activeIndex;
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: highlighted
                      ? const Color(0xFFFFF4EC)
                      : const Color(0xFFFFC89B),
                  fontSize: 10,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DriverHistoryCard extends ConsumerWidget {
  const _DriverHistoryCard({
    required this.trip,
    required this.title,
    required this.isCurrentTrip,
  });

  final DriverTrip trip;
  final String title;
  final bool isCurrentTrip;

  bool get _canChat {
    final phone = (trip.passengerPhone ?? '').trim();
    return phone.isNotEmpty &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(trip.status);
  }

  bool get _canCancel {
    return const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status);
  }

  String? _normalizeWhatsAppPhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('591')) {
      return digits;
    }
    return '591$digits';
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final normalizedPhone = _normalizeWhatsAppPhone(trip.passengerPhone);
    if (normalizedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay numero valido del pasajero para WhatsApp.'),
        ),
      );
      return;
    }
    final passengerName = (trip.passengerName ?? '').trim().isEmpty
        ? 'pasajero'
        : trip.passengerName!.trim();
    final message = trip.status == 'at_pickup'
        ? 'Hola $passengerName, ya llegue al punto de recojo en RAPIGO PRO.'
        : 'Hola $passengerName, te escribo por tu viaje de RAPIGO PRO.';
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp en este momento.'),
        ),
      );
    }
  }

  Future<void> _cancelTrip(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(offeredTripProvider.notifier)
          .updateTripStatus('cancelled');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Viaje cancelado.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _showDetails(BuildContext context) {
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x55F97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Detalle del viaje',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (trip.isPromotional) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1F22C55E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x3322C55E)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Color(0xFF86EFAC),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Viaje promocional',
                                    style: TextStyle(
                                      color: Color(0xFFE9FFF0),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Este viaje se realizo con el beneficio promocional del pasajero y la promo aplicaba solo para el cliente registrado.',
                              style: TextStyle(
                                color: Color(0xFFCFF7DB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _InfoTile(label: 'Pasajero', value: passengerName),
                    _InfoTile(
                      label: 'Estado',
                      value: _historyStatusLabel(trip.status),
                    ),
                    _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                    _InfoTile(label: 'Destino', value: trip.destination),
                    if (trip.passengerPhone?.isNotEmpty ?? false)
                      _InfoTile(label: 'Telefono', value: trip.passengerPhone!),
                    if (trip.vehicleType?.isNotEmpty ?? false)
                      _InfoTile(
                        label: 'Tipo de vehiculo',
                        value: trip.vehicleType!.toUpperCase(),
                      ),
                    if (trip.vehicleLabel?.isNotEmpty ?? false)
                      _InfoTile(label: 'Vehiculo', value: trip.vehicleLabel!),
                    if (trip.vehicleColor?.isNotEmpty ?? false)
                      _InfoTile(label: 'Color', value: trip.vehicleColor!),
                    if (trip.vehiclePlate?.isNotEmpty ?? false)
                      _InfoTile(label: 'Placa', value: trip.vehiclePlate!),
                    if (trip.requestedAt?.isNotEmpty ?? false)
                      _InfoTile(
                        label: 'Fecha del pedido',
                        value: trip.requestedAt!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _historyAccentColor(trip.status);
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';
    final vehicleSummary = (trip.vehicleLabel ?? trip.vehicleType ?? '').trim();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    passengerName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                ),
                if (trip.isPromotional) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1F22C55E),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x3322C55E)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard_rounded,
                          size: 14,
                          color: Color(0xFF86EFAC),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Promo',
                          style: TextStyle(
                            color: Color(0xFF86EFAC),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _historyStatusLabel(trip.status),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DriverMiniBadge(icon: Icons.badge_outlined, label: title),
                if (trip.requestedAt?.isNotEmpty ?? false)
                  _DriverMiniBadge(
                    icon: Icons.schedule_rounded,
                    label: trip.requestedAt!,
                  ),
                if (vehicleSummary.isNotEmpty)
                  _DriverMiniBadge(
                    icon: (trip.vehicleType ?? '').toLowerCase() == 'moto'
                        ? Icons.two_wheeler_rounded
                        : Icons.local_taxi_rounded,
                    label: vehicleSummary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF25252B),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del viaje',
                    style: TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DriverCompactInfoRow(
                    icon: Icons.radio_button_checked_rounded,
                    label: 'Recojo',
                    value: trip.passengerPickup,
                    iconColor: const Color(0xFFF97316),
                  ),
                  const SizedBox(height: 10),
                  _DriverCompactInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Destino',
                    value: trip.destination,
                    iconColor: const Color(0xFF22C55E),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DriverTripProgressBar(status: trip.status),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetails(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD8BF),
                    side: BorderSide(color: accent.withValues(alpha: 0.32)),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Detalle'),
                ),
                if (_canChat)
                  FilledButton.tonalIcon(
                    onPressed: () => _openWhatsApp(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3A2A),
                      foregroundColor: const Color(0xFFB6F5C8),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('WhatsApp'),
                  ),
                if (_canCancel)
                  FilledButton.tonalIcon(
                    onPressed: () => _cancelTrip(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3A1F1F),
                      foregroundColor: const Color(0xFFFFC9C9),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _historyAccentColor(String status) {
    return switch (status) {
      'completed' => const Color(0xFF22C55E),
      'cancelled' => const Color(0xFFEF4444),
      'in_progress' => const Color(0xFF0EA5E9),
      _ => const Color(0xFFF97316),
    };
  }

  String _historyStatusLabel(String status) {
    return switch (status) {
      'requested' => 'Solicitado',
      'searching' => 'Buscando',
      'accepted' => 'Aceptado',
      'arriving' => 'En camino',
      'at_pickup' => 'Llego',
      'in_progress' => 'En curso',
      'completed' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }
}

class _DriverMiniBadge extends StatelessWidget {
  const _DriverMiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFF97316)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF4EC),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
