part of 'driver_home_page.dart';

class DriverSocketListener extends ConsumerStatefulWidget {
  const DriverSocketListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverSocketListener> createState() =>
      _DriverSocketListenerState();
}

class _DriverSocketListenerState extends ConsumerState<DriverSocketListener>
    with WidgetsBindingObserver {
  static const String _backgroundNoticeSeenKey =
      'rapigo_pro_driver_background_notice_seen';

  io.Socket? _socket;
  String? _joinedDriverId;
  String? _joinedTripId;
  String? _restoredDriverId;
  bool _bootstrappedExperience = false;
  bool _isPreparingExperience = false;
  bool _isRefreshingAuthorization = false;
  Timer? _sessionRefreshTimer;
  Timer? _socketReconnectTimer;
  int _socketReconnectAttempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => Future<void>.microtask(_refreshDriverAccessState),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _sessionRefreshTimer?.cancel();
    _socketReconnectTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future<void>.microtask(_restoreDriverOperationalState);
    }
  }

  void _showDriverOverlayNotice(
    String message, {
    NoticeTone tone = NoticeTone.info,
    IconData? icon,
  }) {
    if (!mounted) {
      return;
    }
    showTopNotice(
      context,
      message,
      tone: tone,
      icon: icon,
      compact: true,
      centered: true,
      horizontalInset: 28,
      duration: const Duration(seconds: 4),
      backgroundColor: const Color(0xF40B1220),
      foregroundColor: const Color(0xFFF8FAFC),
      onTap: () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DriverNotificationsPage()),
        );
      },
    );
  }

  String _statusMessage(String status) {
    return switch (status) {
      'arriving' => 'Dirigete al punto de recogida.',
      'at_pickup' => 'Marcaste llegada al punto.',
      'in_progress' => 'Viaje en progreso.',
      'completed' => 'Viaje finalizado.',
      'cancelled' => 'Viaje cancelado.',
      _ => 'Estado actualizado: $status',
    };
  }

  void _joinTripRoom(String tripId) {
    if (_joinedTripId == tripId) {
      return;
    }
    if (_joinedTripId != null && _joinedTripId!.isNotEmpty) {
      _socket?.emit('leave:trip', _joinedTripId);
    }
    _socket?.emit('join:trip', tripId);
    _joinedTripId = tripId;
  }

  void _ensureSocket(String driverId) {
    if (_socket != null && _joinedDriverId == driverId) {
      return;
    }

    _socketReconnectTimer?.cancel();
    _socket?.dispose();
    _socket = io.io(
      shared_config.AppConfig.websocketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket?.onConnect((_) {
      _socketReconnectAttempt = 0;
      _socket?.emit('join:driver', driverId);
      _joinedDriverId = driverId;
      DriverStartupTrace.markSocketConnected();
      final tripId = ref.read(offeredTripProvider).value?.id;
      if (tripId != null && tripId.isNotEmpty) {
        _joinTripRoom(tripId);
      }
    });
    _socket?.onConnectError((_) => _scheduleSocketReconnect(driverId));
    _socket?.onError((_) => _scheduleSocketReconnect(driverId));
    _socket?.onDisconnect((_) {
      _joinedDriverId = null;
      _scheduleSocketReconnect(driverId);
    });
    _socket?.on('driver:trip_offer', (_) {
      final currentTrip = ref.read(offeredTripProvider).value;
      if (currentTrip != null &&
          const {'accepted', 'arriving', 'at_pickup', 'in_progress'}
              .contains(currentTrip.status)) {
        return;
      }
      ref.read(offeredTripProvider.notifier).loadOffer();
      ref.read(driverOffersProvider.notifier).loadOffers();
      ref.invalidate(driverTripHistoryProvider);
      LocalNotifications.show(
        id: 2001,
        title: 'RAPIGO - PRO',
        body: 'Tienes una solicitud de viaje disponible.',
        kind: DriverLocalNotificationKind.rideRequest,
      );
      _showDriverOverlayNotice(
        'Nueva oferta disponible. Revisa el viaje entrante.',
        tone: NoticeTone.warning,
        icon: Icons.local_taxi_rounded,
      );
    });
    _socket?.on('trip:status_changed', (data) {
      final map =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final status = map['status']?.toString();
      final currentTripId = ref.read(offeredTripProvider).value?.id;
      if (tripId != null &&
          status != null &&
          tripId.isNotEmpty &&
          status.isNotEmpty &&
          currentTripId == tripId) {
        ref.read(offeredTripProvider.notifier).setLocalStatus(status);
        _showDriverOverlayNotice(
          _statusMessage(status),
          tone: status == 'at_pickup' || status == 'completed'
              ? NoticeTone.success
              : status == 'cancelled'
                  ? NoticeTone.warning
                  : NoticeTone.info,
          icon: status == 'completed'
              ? Icons.check_circle_outline_rounded
              : status == 'cancelled'
                  ? Icons.info_outline_rounded
                  : Icons.directions_car_filled_rounded,
        );
        ref.invalidate(driverTripHistoryProvider);
      }
    });
    _socket?.on('trip:destination_updated', (_) async {
      await ref.read(offeredTripProvider.notifier).loadOffer();
      _showDriverOverlayNotice(
        'El pasajero actualizo el destino del viaje.',
        tone: NoticeTone.success,
        icon: Icons.edit_location_alt_rounded,
      );
    });
    _socket?.on('driver:trip_destination_updated', (_) async {
      await ref.read(offeredTripProvider.notifier).loadOffer();
      _showDriverOverlayNotice(
        'Destino recibido. Ya puedes seguir la nueva ruta.',
        tone: NoticeTone.success,
        icon: Icons.alt_route_rounded,
      );
    });
    _socket?.on('driver:trip_rejected', (_) {
      ref.read(driverOffersProvider.notifier).loadOffers();
      ref.invalidate(driverTripHistoryProvider);
    });
    _socket?.on('driver:trip_accepted', (_) {
      ref.read(driverOffersProvider.notifier).loadOffers();
      ref.read(offeredTripProvider.notifier).loadOffer();
      ref.invalidate(driverTripHistoryProvider);
    });
    _socket?.connect();
  }

  void _scheduleSocketReconnect(String driverId) {
    if (!mounted || _socketReconnectTimer?.isActive == true) {
      return;
    }
    _socketReconnectAttempt++;
    final seconds = (_socketReconnectAttempt * 2).clamp(2, 12);
    _socketReconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) {
        return;
      }
      final session = ref.read(driverSessionProvider);
      if (session.accessStatus == 'AUTORIZADO' && session.driverId == driverId) {
        _ensureSocket(driverId);
      }
    });
  }

  Future<void> _prepareDriverExperience() async {
    if (_isPreparingExperience) {
      return;
    }
    _isPreparingExperience = true;
    try {
      await _ensureCriticalPermissions();
      await _maybeShowBackgroundServiceNotice();
      await LocalNotifications.ensureInitialized();

      if (!mounted) {
        return;
      }

      final offlineController = ref.read(offlineMapProvider.notifier);
      await offlineController.ensureOfflineAvailability();
    } catch (_) {
      // Keep startup stable if permissions/network are temporarily unavailable.
    } finally {
      _isPreparingExperience = false;
    }
  }

  Future<void> _ensureCriticalPermissions() async {
    while (mounted) {
      final notificationStatus = await Permission.notification.request();
      final locationStatus = await Permission.locationWhenInUse.request();
      PermissionStatus backgroundLocationStatus = PermissionStatus.granted;
      if (Platform.isAndroid &&
          (locationStatus.isGranted || locationStatus.isLimited)) {
        backgroundLocationStatus = await Permission.locationAlways.request();
      }
      final notificationsReady =
          notificationStatus.isGranted || notificationStatus.isLimited;
      final locationReady =
          (locationStatus.isGranted || locationStatus.isLimited) &&
          (backgroundLocationStatus.isGranted ||
              backgroundLocationStatus.isLimited);
      if (notificationsReady && locationReady) {
        return;
      }
      await _showPermissionsRequiredDialog(
        notificationsReady: notificationsReady,
        locationReady: locationReady,
      );
    }
  }

  Future<void> _showPermissionsRequiredDialog({
    required bool notificationsReady,
    required bool locationReady,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181B),
          title: const Text(
            'Activa los permisos',
            style: TextStyle(
              color: Color(0xFFFFF4EC),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RAPIGO PRO necesita ubicacion y notificaciones activas para trabajar correctamente desde el inicio.',
                style: TextStyle(color: Color(0xFFFFD8BF)),
              ),
              const SizedBox(height: 12),
              Text(
                '${locationReady ? '✓' : '•'} Ubicacion siempre activa',
                style: TextStyle(
                  color: locationReady
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${notificationsReady ? '✓' : '•'} Notificaciones activas',
                style: TextStyle(
                  color: notificationsReady
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async => openAppSettings(),
              child: const Text('Configuracion'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: const Color(0xFF0F0F10),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _maybeShowBackgroundServiceNotice() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_backgroundNoticeSeenKey) == true || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181B),
          title: const Text(
            'RAPIGO PRO seguira activo',
            style: TextStyle(
              color: Color(0xFFFFF4EC),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Veras una notificacion fija mientras RAPIGO PRO conductor envie ubicacion en segundo plano. Es normal y necesaria para no perder viajes, seguir mandando GPS y recibir alertas aunque bloquees el celular.',
            style: TextStyle(color: Color(0xFFFFD8BF), height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: const Color(0xFF0F0F10),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
    await prefs.setBool(_backgroundNoticeSeenKey, true);
  }

  Future<void> _restoreDriverOperationalState() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(driverStateProvider.notifier).restoreOperationalState();
      await ref.read(offeredTripProvider.notifier).loadOffer();
      await ref.read(driverOffersProvider.notifier).loadOffers();
    } catch (_) {
      // Keep lifecycle restoration non-blocking.
    }
  }

  Future<void> _refreshAuthorizationStatus() async {
    if (_isRefreshingAuthorization) {
      return;
    }
    _isRefreshingAuthorization = true;
    try {
      await ref.read(driverSessionProvider.notifier).refreshAccessStatus();
    } finally {
      _isRefreshingAuthorization = false;
    }
  }

  Future<void> _refreshDriverAccessState() async {
    await ref.read(driverSessionProvider.notifier).refreshSessionStatus();
    final updatedSession = ref.read(driverSessionProvider);
    if (updatedSession.deviceStatus != 'AUTORIZADO') {
      return;
    }
    await _refreshAuthorizationStatus();
  }

  @override
  Widget build(BuildContext context) {
    final accessStatus = ref.watch(driverSessionProvider.select((s) => s.accessStatus));
    final driverId = ref.watch(driverSessionProvider.select((s) => s.driverId));
    final deviceStatus = ref.watch(driverSessionProvider.select((s) => s.deviceStatus));

    if (!_bootstrappedExperience) {
      _bootstrappedExperience = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future<void>.microtask(_prepareDriverExperience);
        }
      });
    }

    if (accessStatus != 'AUTORIZADO') {
      Future<void>.microtask(_refreshAuthorizationStatus);
    }

    if (accessStatus == 'AUTORIZADO' &&
        _restoredDriverId != driverId &&
        driverId.isNotEmpty) {
      _restoredDriverId = driverId;
      Future<void>.microtask(_restoreDriverOperationalState);
    }

    if (accessStatus == 'AUTORIZADO' && driverId.isNotEmpty) {
      _ensureSocket(driverId);
    }

    final currentTrip = ref.watch(offeredTripProvider).value;
    if (currentTrip != null &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}
            .contains(currentTrip.status)) {
      _joinTripRoom(currentTrip.id);
    }

    if (deviceStatus != 'AUTORIZADO') {
      _socketReconnectTimer?.cancel();
    }

    return widget.child;
  }
}
