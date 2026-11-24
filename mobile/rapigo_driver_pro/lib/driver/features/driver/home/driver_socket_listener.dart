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
      if (!mounted) return;
      ref.read(driverConnectionProvider.notifier).setConnected(true);
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
    _socket?.on('driver:offers_changed', (_) async {
      await ref.read(driverOffersProvider.notifier).loadOffers();
      await ref.read(offeredTripProvider.notifier).loadOffer();
    });
    _socket?.on('driver:counter_offer', (_) async {
      await ref.read(offeredTripProvider.notifier).loadOffer();
      await ref
          .read(driverStateProvider.notifier)
          .restoreOperationalState(force: true);
      await ref.read(driverOffersProvider.notifier).loadOffers();
      ref.invalidate(driverTripHistoryProvider);
    });
    _socket?.on('driver:trip_offer', (_) {
      final currentTrip = ref.read(offeredTripProvider).value;
      if (currentTrip != null &&
          const {
            'accepted',
            'arriving',
            'at_pickup',
            'in_progress',
          }.contains(currentTrip.status)) {
        return;
      }
      ref.read(offeredTripProvider.notifier).loadOffer();
      ref.read(driverOffersProvider.notifier).loadOffers();
      ref.invalidate(driverTripHistoryProvider);
      LocalNotifications.show(
        id: 2001,
        title: 'RAPIGO',
        body: 'Nueva solicitud de viaje.',
        kind: DriverLocalNotificationKind.rideRequest,
      );
      _showDriverOverlayNotice(
        'Nueva oferta disponible. Revisa el viaje entrante.',
        tone: NoticeTone.warning,
        icon: Icons.local_taxi_rounded,
      );
    });
    _socket?.on('trip:status_changed', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final status = map['status']?.toString();
      final currentTripId = ref.read(offeredTripProvider).value?.id;
      if (tripId != null &&
          status != null &&
          tripId.isNotEmpty &&
          status.isNotEmpty &&
          currentTripId == tripId) {
        final wasCounterOffer =
            ref.read(offeredTripProvider).value?.hasPendingCounterOffer == true;
        ref.read(offeredTripProvider.notifier).setLocalStatus(status);
        if (wasCounterOffer && status == 'cancelled') {
          unawaited(
            ref
                .read(driverStateProvider.notifier)
                .restoreOperationalState(force: true),
          );
        }
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
    _socket?.on('driver:trip_unavailable', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      if (tripId == null || tripId.isEmpty) {
        ref.read(driverOffersProvider.notifier).loadOffers();
        return;
      }
      final currentTrip = ref.read(offeredTripProvider).value;
      final isPendingCurrentTrip =
          currentTrip?.id == tripId &&
          const {'requested', 'searching'}.contains(currentTrip?.status);
      ref.read(driverOffersProvider.notifier).removeOfferLocally(tripId);
      ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(null);
      if (isPendingCurrentTrip) {
        ref.read(offeredTripProvider.notifier).clearTrip();
      }
      ref.read(driverOffersProvider.notifier).loadOffers();
      final reason = map['reason']?.toString();
      final message = reason == 'accepted'
          ? 'Ese viaje ya fue tomado por otro conductor.'
          : 'La solicitud paso al siguiente conductor disponible.';
      _showDriverOverlayNotice(
        message,
        tone: NoticeTone.warning,
        icon: Icons.info_outline_rounded,
      );
    });
    _socket?.connect();
  }

  void _scheduleSocketReconnect(String driverId) {
    if (mounted) {
      ref.read(driverConnectionProvider.notifier).setConnected(false);
    }
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
      if (session.accessStatus == 'AUTORIZADO' &&
          session.driverId == driverId) {
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
      if (mounted) await _restoreDriverOperationalState();
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
    if (!mounted) return;
    await LocationConsent.request(context, driver: true);
    if (!mounted) return;
    // Notifications are optional; refusal must never trap the user in a loop.
    await Permission.notification.request();
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

  }

  @override
  Widget build(BuildContext context) {
    final accessStatus = ref.watch(
      driverSessionProvider.select((s) => s.accessStatus),
    );
    final driverId = ref.watch(driverSessionProvider.select((s) => s.driverId));
    final deviceStatus = ref.watch(
      driverSessionProvider.select((s) => s.deviceStatus),
    );

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
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(currentTrip.status)) {
      _joinTripRoom(currentTrip.id);
    }

    if (deviceStatus != 'AUTORIZADO') {
      _socketReconnectTimer?.cancel();
    }

    return widget.child;
  }
}
