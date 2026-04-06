import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../map/data/location_controller.dart';
import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';

class RideTab extends ConsumerStatefulWidget {
  const RideTab({
    super.key,
    required this.onMenuTap,
    required this.onProfileTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<RideTab> createState() => _RideTabState();
}

class _RideTabState extends ConsumerState<RideTab> {
  final TextEditingController _destinationController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Timer? _refreshTimer;
  Timer? _notificationTimer;
  ProviderSubscription<TripState>? _tripSubscription;
  io.Socket? _socket;
  double _sheetSize = 0.34;
  String? _floatingNotification;
  RideMode _rideMode = RideMode.destino;
  String? _joinedTripId;
  String? _selectedDriverId;
  String? _ratingPromptedTripId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_syncDashboard);
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _syncDashboard());
    _connectSocket();
    Future<void>.microtask(_requestNotificationPermission);
    _tripSubscription = ref.listenManual<TripState>(tripProvider, (previous, next) {
      final previousStatus = previous?.request.status;
      final currentStatus = next.request.status;
      if (previousStatus != currentStatus) {
        _handleTripStatusChange(next.request);
      }
    });
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
    await LocalNotifications.ensureInitialized();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationTimer?.cancel();
    _tripSubscription?.close();
    _socket?.dispose();
    _sheetController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _connectSocket() {
    _socket?.dispose();
    _socket = io.io(
      AppConfig.websocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket?.onConnect((_) {
      final tripId = ref.read(tripProvider).request.activeTripId;
      if (tripId != null && tripId.isNotEmpty) {
        _joinTripRoom(tripId);
      }
    });
    _socket?.on('trip:accepted', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final etaMinutes = map['etaMinutes'] is num
          ? (map['etaMinutes'] as num).toInt()
          : int.tryParse(map['etaMinutes']?.toString() ?? '');
      if (tripId != null && tripId.isNotEmpty) {
        ref.read(tripProvider.notifier).markTripAccepted(
              tripId: tripId,
              etaMinutes: etaMinutes,
            );
      }
    });
    _socket?.on('trip:status_changed', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final status = map['status']?.toString();
      if (tripId != null && status != null && tripId.isNotEmpty && status.isNotEmpty) {
        ref.read(tripProvider.notifier).markTripAccepted(tripId: tripId, status: status);
      }
    });
    _socket?.connect();
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

  Future<void> _syncDashboard() async {
    final session = ref.read(sessionProvider);
    final location = ref.read(passengerLocationProvider).position;
    if (!mounted || !session.isAuthenticated || location == null) {
      return;
    }

    await ref.read(tripProvider.notifier).loadDashboard(
          token: session.token,
          passengerId: session.userId,
          userLocation: location,
        );
  }

  Future<void> _requestRide() async {
    final session = ref.read(sessionProvider);
    final locationState = ref.read(passengerLocationProvider);
    final location = locationState.position;
    final destination = _destinationController.text.trim();
    final resolvedDestination =
        _rideMode == RideMode.cercano && destination.isEmpty ? 'Abordaje inmediato' : destination;
    final selectedDriverId = _rideMode == RideMode.cercano ? _selectedDriverId : null;

    if (location == null) {
      _showMessage(locationState.errorMessage ?? 'Activa tu ubicacion para pedir un taxi.');
      return;
    }

    if (resolvedDestination.isEmpty) {
      _showMessage('Ingresa un destino para continuar.');
      return;
    }

    await ref.read(tripProvider.notifier).requestRide(
          token: session.token,
          passengerId: session.userId,
          userLocation: location,
          destinationAddress: resolvedDestination,
          preferredDriverId: selectedDriverId,
        );

    final error = ref.read(tripProvider).errorMessage;
    if (error != null && mounted) {
      _showMessage(error.replaceFirst('Exception: ', ''));
      return;
    }

    if (mounted) {
      final selectedDriver =
          _findDriverById(ref.read(tripProvider).nearbyDrivers, selectedDriverId);
      _showFloatingNotification(
        selectedDriver == null
            ? 'Solicitud enviada. Estamos buscando un conductor.'
            : 'Solicitud enviada a ${selectedDriver.vehicleLabel}. Esperando respuesta.',
      );
    }
  }

  Future<void> _toggleSheet() async {
    final target = _sheetSize <= 0.08 ? 0.34 : 0.0;
    await _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectNearestTaxi() {
    final drivers = ref.read(tripProvider).nearbyDrivers;
    if (drivers.isEmpty) {
      _showMessage('No hay taxis cercanos disponibles en este momento.');
      return;
    }

    final nearest = drivers.first;
    setState(() => _selectedDriverId = nearest.driverId);
    _showFloatingNotification(
      '${nearest.vehicleLabel} fue seleccionado. Llega en ${nearest.etaMinutes} min.',
    );
  }

  void _selectDriver(String driverId) {
    setState(() => _selectedDriverId = driverId);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showTripRequestSheet(TripState tripState) {
    final request = tripState.request;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFFEFEFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E2E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Pedido de taxi',
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _StatusBanner(
                message: _tripStatusHeadline(request.status),
                color: const Color(0xFFEAFBFD),
                textColor: const Color(0xFF00616D),
              ),
              const SizedBox(height: 16),
              _TripInfoRow(label: 'Estado', value: request.status),
              _TripInfoRow(label: 'Recojo', value: request.pickupAddress),
              _TripInfoRow(
                label: 'Taxi',
                value: (request.vehicleLabel?.isNotEmpty ?? false)
                    ? request.vehicleLabel!
                    : 'Aun sin asignar',
              ),
              _TripInfoRow(
                label: 'Placa',
                value: (request.vehiclePlate?.isNotEmpty ?? false)
                    ? request.vehiclePlate!
                    : 'Por confirmar',
              ),
              _TripInfoRow(
                label: 'Llegada',
                value: request.etaMinutes == null ? 'Calculando...' : '${request.etaMinutes} min',
              ),
              _TripInfoRow(
                label: 'Ubicacion taxi',
                value: request.driverLat == null || request.driverLng == null
                    ? 'Aun no disponible'
                    : '${request.driverLat!.toStringAsFixed(5)}, ${request.driverLng!.toStringAsFixed(5)}',
              ),
            ],
          ),
        );
      },
    );
  }

  String _tripStatusHeadline(String status) {
    return switch (status) {
      'requested' => 'Tu pedido esta enviado y esperando conductor.',
      'searching' => 'Estamos buscando el taxi mas adecuado.',
      'accepted' => 'Un conductor ya acepto tu viaje.',
      'arriving' => 'Tu taxi va en camino a recogerte.',
      'at_pickup' => 'Tu taxi ya esta listo para subir.',
      'in_progress' => 'Tu viaje esta en progreso.',
      'completed' => 'El viaje ya fue finalizado.',
      _ => 'Seguimiento activo del pedido.',
    };
  }

  void _showFloatingNotification(String message) {
    _notificationTimer?.cancel();
    setState(() => _floatingNotification = message);
    LocalNotifications.show(
      id: message.hashCode,
      title: 'Taxi Ya',
      body: message,
    );
    _notificationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _floatingNotification = null);
      }
    });
  }

  void _handleTripStatusChange(TripRequest request) {
    final message = switch (request.status) {
      'accepted' => 'Tu taxi fue aceptado.',
      'arriving' => 'El conductor va en camino a recogerte.',
      'at_pickup' => 'Tu taxi ya llegó al punto de recogida.',
      'in_progress' => 'Viaje en progreso.',
      'completed' => 'Viaje finalizado.',
      'cancelled' => 'El viaje fue cancelado.',
      _ => null,
    };

    if (message != null) {
      _showFloatingNotification(message);
    }

    if (request.status == 'completed' &&
        request.activeTripId != null &&
        _ratingPromptedTripId != request.activeTripId) {
      _ratingPromptedTripId = request.activeTripId;
      Future<void>.microtask(() => _showPassengerRatingDialog(request.activeTripId!));
    }
  }

  Future<void> _showPassengerRatingDialog(String tripId) async {
    int selectedScore = 5;
    final commentController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Califica al conductor'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: List<Widget>.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () => setDialogState(() => selectedScore = value),
                          icon: Icon(
                            value <= selectedScore ? Icons.star : Icons.star_border,
                            color: const Color(0xFF00E3FD),
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Comentario opcional',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Luego'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Enviar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true) {
        await ref.read(tripProvider.notifier).submitRating(
              token: ref.read(sessionProvider).token,
              tripId: tripId,
              score: selectedScore,
              comment: commentController.text,
            );
        await _syncDashboard();
      }
    } finally {
      commentController.dispose();
    }
  }

  Widget _buildTripActions(TripState tripState) {
    final activeTripId = tripState.request.activeTripId;
    if (activeTripId == null || activeTripId.isEmpty) {
      return const SizedBox.shrink();
    }

    final status = tripState.request.status;
    final session = ref.read(sessionProvider);

    if (status == 'at_pickup') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () => ref.read(tripProvider.notifier).updateTripStatus(
                  token: session.token,
                  tripId: activeTripId,
                  status: 'in_progress',
                ),
            child: const Text('Estoy listo para salir'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  NearbyDriver? _findDriverById(List<NearbyDriver> drivers, String? driverId) {
    if (driverId == null || driverId.isEmpty) {
      return null;
    }
    for (final driver in drivers) {
      if (driver.driverId == driverId) {
        return driver;
      }
    }
    return null;
  }

  String _primaryActionLabel(TripState tripState) {
    if (tripState.isRequestingTrip) {
      return 'Enviando solicitud...';
    }
    if (_rideMode == RideMode.cercano) {
      return _selectedDriverId == null ? 'Elegir taxi mas cercano' : 'Solicitar este taxi';
    }
    return _selectedDriverId == null ? 'Solicitar taxi' : 'Solicitar este auto';
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(passengerLocationProvider);
    final tripState = ref.watch(tripProvider);
    final activeTripId = tripState.request.activeTripId;
    if (activeTripId != null && activeTripId.isNotEmpty && _socket?.connected == true) {
      _joinTripRoom(activeTripId);
    }
    final userLocation = locationState.position ?? const LatLng(-19.5836, -65.7531);
    final hasActiveTrip = activeTripId != null && activeTripId.isNotEmpty;
    final activeDriverPoint =
        tripState.request.driverLat != null && tripState.request.driverLng != null
            ? LatLng(tripState.request.driverLat!, tripState.request.driverLng!)
            : null;
    final driverPoints = hasActiveTrip
        ? [
            activeDriverPoint,
          ].whereType<LatLng>().toList(growable: false)
        : tripState.nearbyDrivers
              .map((driver) => LatLng(driver.lat, driver.lng))
              .toList(growable: false);

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEDF8FB), Color(0xFFF9F9FB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: PotosiMap(
                key: ValueKey(
                  'passenger-map-${tripState.request.status}-${activeDriverPoint?.latitude}-${activeDriverPoint?.longitude}',
                ),
                drivers: driverPoints,
                userLocation: userLocation,
                routeTarget: activeDriverPoint,
                showRoute: hasActiveTrip && activeDriverPoint != null,
                showTargetMarker: false,
              ),
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
                    const Color(0xFFF9F9FB).withValues(alpha: 0.90),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFFF9F9FB),
                  ],
                  stops: const [0, 0.18, 0.72, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassIconButton(
                      icon: Icons.menu,
                      onTap: widget.onMenuTap,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Taxi Ya',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF000003),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onProfileTap,
                        child: const Icon(Icons.person, color: Color(0xFF000003)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000003),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place, color: Color(0xFF006875)),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu ubicacion',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF000003),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Potosi, Bolivia',
                                  style: TextStyle(
                                    color: Color(0xFF47464B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (tripState.request.activeTripId != null)
                        FilledButton.tonalIcon(
                          onPressed: () => _showTripRequestSheet(tripState),
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Pedido de taxi'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.86),
                            foregroundColor: const Color(0xFF001F24),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_floatingNotification != null) ...[
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(_floatingNotification),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000003).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000003),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFF00E3FD)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _floatingNotification!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 170,
          child: Column(
            children: [
              _MapActionButton(
                icon: Icons.my_location,
                onTap: () async {
                  await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
                  await _syncDashboard();
                },
              ),
              const SizedBox(height: 12),
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
            ],
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if ((_sheetSize - notification.extent).abs() > 0.01) {
              setState(() => _sheetSize = notification.extent);
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.34,
            minChildSize: hasActiveTrip ? 0.26 : 0.0,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: hasActiveTrip ? const [0.26, 0.34, 0.58, 0.80] : const [0.0, 0.34, 0.58, 0.80],
            builder: (context, scrollController) {
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFFEFEFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x16000003),
                      blurRadius: 40,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeButton(
                              label: 'Pedir taxi',
                              selected: _rideMode == RideMode.destino,
                              onTap: () => setState(() {
                                _rideMode = RideMode.destino;
                                _selectedDriverId = null;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ModeButton(
                              label: 'Tomar taxi',
                              selected: _rideMode == RideMode.cercano,
                              onTap: () => setState(() => _rideMode = RideMode.cercano),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_rideMode == RideMode.destino)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF006875)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _destinationController,
                                decoration: const InputDecoration(
                                  hintText: '¿A dónde quieres ir?',
                                  border: InputBorder.none,
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.schedule, color: Color(0xFF77767C)),
                          ],
                        ),
                      ),
                    if (_rideMode == RideMode.destino) const SizedBox(height: 18),
                    if (locationState.errorMessage != null)
                      _StatusBanner(
                        message: locationState.errorMessage!,
                        color: const Color(0xFFFFDAD6),
                        textColor: const Color(0xFF93000A),
                      ),
                    if (tripState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _StatusBanner(
                          message: tripState.errorMessage!.replaceFirst('Exception: ', ''),
                          color: const Color(0xFFFFDAD6),
                          textColor: const Color(0xFF93000A),
                        ),
                      ),
                    if (tripState.request.activeTripId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _LargeTripStatusCard(
                          status: tripState.request.status,
                          vehicleLabel: tripState.request.vehicleLabel,
                          vehiclePlate: tripState.request.vehiclePlate,
                          etaMinutes: tripState.request.etaMinutes,
                        ),
                      ),
                    _buildTripActions(tripState),
                    const SizedBox(height: 12),
                    Text(
                      _rideMode == RideMode.destino ? 'Solicitud de viaje' : 'Que taxi tomar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF000003),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rideMode == RideMode.destino
                          ? 'Aqui solo preparas la solicitud desde tu ubicacion actual.'
                          : 'Mira los taxis cercanos para subir al que te convenga mas rapido.',
                      style: const TextStyle(
                        color: Color(0xFF47464B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_rideMode == RideMode.cercano) ..._buildVehicleCards(tripState.nearbyDrivers),
                    if (_rideMode == RideMode.destino)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text(
                          'Los taxis cercanos solo aparecen en "Tomar taxi". En este modo la app envia una solicitud normal de viaje.',
                          style: TextStyle(
                            color: Color(0xFF47464B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: tripState.isRequestingTrip
                            ? null
                            : (_rideMode == RideMode.destino
                                ? _requestRide
                                : (_selectedDriverId == null ? _selectNearestTaxi : _requestRide)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00E3FD),
                          foregroundColor: const Color(0xFF001F24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: tripState.isRequestingTrip
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : Text(
                                _primaryActionLabel(tripState),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        locationState.position == null
                            ? 'Estamos esperando tu GPS para afinar la oferta.'
                            : 'Tu punto actual esta dentro del radio operativo de Potosi.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF77767C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVehicleCards(List<NearbyDriver> drivers) {
    if (drivers.isEmpty) {
      return const [
        _EmptyRideCard(),
      ];
    }
    const names = ['Taxi Eco', 'Taxi Plus', 'Taxi Ejecutivo', 'Taxi Max'];

    return List<Widget>.generate(drivers.length, (index) {
      final driver = drivers[index];
      final isSelected = driver.driverId == (_selectedDriverId ?? drivers.first.driverId);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _VehicleOptionCard(
          title: driver.vehicleLabel.isEmpty ? names[index % names.length] : driver.vehicleLabel,
          subtitle: driver.vehicleDetail,
          eta: '${driver.etaMinutes} min',
          price: driver.priceLabel,
          rating: driver.rating.toStringAsFixed(1),
          distance: '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km',
          icon: _vehicleIcon(driver.vehicleType),
          highlighted: isSelected,
          onTap: () => _selectDriver(driver.driverId),
        ),
      );
    });
  }

  IconData _vehicleIcon(String? vehicleType) {
    return switch ((vehicleType ?? '').toLowerCase()) {
      'moto' => Icons.two_wheeler_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }
}

enum RideMode {
  destino,
  cercano,
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFF000003)),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: const Color(0x14000003),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: const Color(0xFF1A1C1D)),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF00E3FD) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF001F24) : const Color(0xFF47464B),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleOptionCard extends StatelessWidget {
  const _VehicleOptionCard({
    required this.title,
    required this.subtitle,
    required this.eta,
    required this.price,
    required this.rating,
    required this.distance,
    required this.icon,
    required this.highlighted,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String eta;
  final String price;
  final String rating;
  final String distance;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFFF3F3F5) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: highlighted ? const Color(0xFF00E3FD) : const Color(0x1AC8C5CC),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: highlighted ? const Color(0xFF000003) : const Color(0xFFE8E8EA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? const Color(0xFF00E3FD) : const Color(0xFF000003),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF77767C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Llega en $eta · $distance',
                      style: const TextStyle(
                        color: Color(0xFF47464B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (highlighted) ...[
                    const Icon(Icons.check_circle, color: Color(0xFF006875), size: 18),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    price,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFF00E3FD), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRideCard extends StatelessWidget {
  const _EmptyRideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Todavia no vemos taxis activos. Usa "mi ubicacion" y espera unos segundos para cargar autos cercanos.',
        style: TextStyle(
          color: Color(0xFF47464B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LargeTripStatusCard extends StatelessWidget {
  const _LargeTripStatusCard({
    required this.status,
    this.vehicleLabel,
    this.vehiclePlate,
    this.etaMinutes,
  });

  final String status;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final int? etaMinutes;

  String get _title => switch (status) {
        'accepted' => 'Taxi aceptado',
        'arriving' => 'Taxi en camino',
        'at_pickup' => 'Taxi listo para subir',
        'in_progress' => 'Viaje en progreso',
        'completed' => 'Viaje finalizado',
        'cancelled' => 'Viaje cancelado',
        _ => 'Estado del viaje',
      };

  String get _subtitle => switch (status) {
        'accepted' => etaMinutes == null
            ? 'Tu conductor ya confirmo el viaje.'
            : 'Tu conductor ya confirmo el viaje y llega en $etaMinutes min.',
        'arriving' => etaMinutes == null
            ? 'Sigue el recorrido del conductor hacia tu punto.'
            : 'Tu conductor va en camino y llega en $etaMinutes min.',
        'at_pickup' => 'Verifica el auto y sube cuando estes listo.',
        'in_progress' => 'Viaje en progreso.',
        'completed' => 'Gracias por viajar con Taxi Ya.',
        'cancelled' => 'Puedes volver a solicitar un taxi cuando quieras.',
        _ => 'Estamos actualizando el estado de tu viaje.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF001F24).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000003),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            style: const TextStyle(
              color: Color(0xFFD4F9FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((vehicleLabel ?? '').isNotEmpty || (vehiclePlate ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (etaMinutes != null && const {'accepted', 'arriving'}.contains(status))
                  _TripBadge(icon: Icons.schedule, label: 'Llega en $etaMinutes min'),
                if ((vehicleLabel ?? '').isNotEmpty)
                  _TripBadge(
                    icon: (vehicleLabel ?? '').toLowerCase().contains('moto')
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_filled_rounded,
                    label: vehicleLabel!,
                  ),
                if ((vehiclePlate ?? '').isNotEmpty)
                  _TripBadge(icon: Icons.badge_outlined, label: 'Placa $vehiclePlate'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TripBadge extends StatelessWidget {
  const _TripBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00E3FD), size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripInfoRow extends StatelessWidget {
  const _TripInfoRow({
    required this.label,
    required this.value,
  });

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
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF657684),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF102A3B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
