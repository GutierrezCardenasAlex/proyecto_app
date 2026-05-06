import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/ui/top_notice.dart';
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
  bool _isSyncingDashboard = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_syncDashboard);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _syncDashboard());
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
      _socket?.emit('join:drivers_live');
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
    _socket?.on('driver:location', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final location = ref.read(passengerLocationProvider).position;
      if (location == null) {
        return;
      }
      final driverId = map['driverId']?.toString() ?? '';
      final lat = double.tryParse(map['lat']?.toString() ?? '');
      final lng = double.tryParse(map['lng']?.toString() ?? '');
      if (driverId.isEmpty || lat == null || lng == null) {
        return;
      }

      final current = _findDriverById(ref.read(tripProvider).nearbyDrivers, driverId);
      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        location,
        LatLng(lat, lng),
      );
      if (distanceMeters > 50000) {
        return;
      }

      ref.read(tripProvider.notifier).upsertLiveDriver(
            NearbyDriver(
              driverId: driverId,
              lat: lat,
              lng: lng,
              distanceMeters: distanceMeters,
              rating: current?.rating ?? 5,
              etaMinutes: current?.etaMinutes ?? (distanceMeters / 350).round().clamp(2, 60),
              vehicleType: current?.vehicleType ?? 'taxi',
              vehicleLabel: current?.vehicleLabel ?? 'Flash Go',
              vehicleDetail: current?.vehicleDetail ?? 'Disponible',
              priceLabel: current?.priceLabel ?? 'Bs ${(8 + distanceMeters / 300).toStringAsFixed(0)}',
            ),
          );
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
    if (_isSyncingDashboard) {
      return;
    }

    final session = ref.read(sessionProvider);
    final location = ref.read(passengerLocationProvider).position;
    if (!mounted || !session.isAuthenticated || location == null) {
      return;
    }

    _isSyncingDashboard = true;
    try {
      await ref.read(tripProvider.notifier).loadDashboard(
            token: session.token,
            passengerId: session.userId,
            userLocation: location,
          );
    } finally {
      _isSyncingDashboard = false;
    }
  }

  Future<void> _requestRide() async {
    final session = ref.read(sessionProvider);
    final locationState = ref.read(passengerLocationProvider);
    final location = locationState.position;
    final destination = _destinationController.text.trim();
    final resolvedDestination =
        _rideMode == RideMode.cercano && destination.isEmpty ? 'Abordaje inmediato' : destination;
    final selectedDriverId = _rideMode == RideMode.cercano ? _selectedDriverId : null;
    final selectedDriver = _findDriverById(ref.read(tripProvider).nearbyDrivers, selectedDriverId);

    if (location == null) {
      _showMessage(locationState.errorMessage ?? 'Activa tu ubicacion para pedir un taxi.');
      return;
    }

    if (resolvedDestination.isEmpty) {
      _showMessage('Ingresa un destino para continuar.');
      return;
    }

    if (_rideMode == RideMode.cercano &&
        selectedDriver != null &&
        selectedDriver.distanceMeters > 1000) {
      _showMessage(
        'Ese auto esta a ${selectedDriver.distanceMeters.toStringAsFixed(0)} m. Para tomar taxi debe estar dentro de 1000 m.',
      );
      return;
    }

    await ref.read(tripProvider.notifier).requestRide(
          token: session.token,
          passengerId: session.userId,
          userLocation: location,
          destinationAddress: resolvedDestination,
          dispatchMode: _rideMode == RideMode.destino ? 'broadcast' : 'nearby',
          preferredDriverId: selectedDriverId,
        );

    final error = ref.read(tripProvider).errorMessage;
    if (error != null && mounted) {
      _showMessage(error.replaceFirst('Exception: ', ''));
      return;
    }

    if (mounted) {
      _showFloatingNotification(
        selectedDriver == null
            ? 'Solicitud enviada. Estamos buscando un conductor.'
            : 'Solicitud enviada a ${selectedDriver.vehicleLabel}. Esperando respuesta.',
      );
    }
  }

  Future<void> _toggleSheet() async {
    final target = _sheetSize <= 0.08 ? (_hasActiveTrip ? 0.26 : 0.34) : 0.0;
    await _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _hasActiveTrip {
    final activeTripId = ref.read(tripProvider).request.activeTripId;
    return activeTripId != null && activeTripId.isNotEmpty;
  }

  Future<void> _selectNearestTaxi() async {
    final nearbyDrivers = ref.read(tripProvider).nearbyDrivers;
    final drivers = _requestableDrivers(nearbyDrivers);
    if (drivers.isEmpty) {
      if (nearbyDrivers.isNotEmpty) {
        final nearest = nearbyDrivers.first;
        _showMessage(
          'El auto mas cercano esta a ${nearest.distanceMeters.toStringAsFixed(0)} m. Para tomar taxi debe estar dentro de 1000 m.',
        );
      } else {
        _showMessage('No hay taxis cercanos disponibles en este momento.');
      }
      return;
    }

    final nearest = drivers.first;
    setState(() => _selectedDriverId = nearest.driverId);
    await _requestRide();
  }

  void _selectDriver(String driverId) {
    setState(() => _selectedDriverId = driverId);
  }

  String _rideDestinationPreview() {
    final destination = _destinationController.text.trim();
    if (_rideMode == RideMode.cercano) {
      return destination.isEmpty ? 'Abordaje inmediato' : destination;
    }
    return destination.isEmpty ? 'Destino por confirmar' : destination;
  }

  void _showNearbyDriverDetails(NearbyDriver driver) {
    final isSelected = driver.driverId == (_selectedDriverId ?? '');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF121214),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFFFB067)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _vehicleIcon(driver.vehicleType),
                      color: const Color(0xFF0F0F10),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.vehicleLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFF4EC),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driver.vehicleDetail,
                          style: const TextStyle(
                            color: Color(0xFFFFC89B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TripBadge(
                    icon: driver.vehicleType.toLowerCase() == 'moto'
                        ? Icons.two_wheeler_rounded
                        : Icons.local_taxi_rounded,
                    label: driver.vehicleType.toUpperCase(),
                  ),
                  _TripBadge(
                    icon: Icons.place_rounded,
                    label: '${driver.distanceMeters.toStringAsFixed(0)} m',
                  ),
                  _TripBadge(
                    icon: Icons.schedule_rounded,
                    label: '${driver.etaMinutes} min',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1D),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x44F97316)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen del viaje',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TripInfoRow(label: 'Destino', value: _rideDestinationPreview()),
                    _TripInfoRow(label: 'Tipo', value: driver.vehicleType),
                    _TripInfoRow(label: 'Detalle', value: driver.vehicleDetail),
                    _TripInfoRow(label: 'Llegada', value: '${driver.etaMinutes} min'),
                    _TripInfoRow(
                      label: 'Distancia',
                      value: '${driver.distanceMeters.toStringAsFixed(0)} m',
                    ),
                    _TripInfoRow(label: 'Calificacion', value: driver.rating.toStringAsFixed(1)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Revisa bien el auto y luego decide si quieres elegirlo.',
                style: const TextStyle(
                  color: Color(0xFFFFC89B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFC89B),
                        side: const BorderSide(color: Color(0x55F97316)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _selectDriver(driver.driverId);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      child: Text(isSelected ? 'Seleccionado' : 'Elegir este'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    showTopNotice(
      context,
      message,
      backgroundColor: const Color(0xFFF97316),
      foregroundColor: const Color(0xFF0F0F10),
    );
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

  Future<void> _openWhatsApp({
    required String? phone,
    required String message,
  }) async {
    final normalizedPhone = _normalizeWhatsAppPhone(phone);
    if (normalizedPhone == null) {
      _showMessage('Todavia no hay un numero disponible para WhatsApp.');
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _showMessage('No se pudo abrir WhatsApp en este momento.');
    }
  }

  void _showPassengerTripOptions(TripState tripState) {
    final request = tripState.request;
    final activeTripId = request.activeTripId;
    if (activeTripId == null || activeTripId.isEmpty) {
      return;
    }

    final status = request.status;
    final session = ref.read(sessionProvider);
    final canCancel = !const {'completed', 'cancelled'}.contains(status);
    final canChat = request.driverPhone != null &&
        request.driverPhone!.trim().isNotEmpty &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(status);
    final canStartTrip = status == 'at_pickup';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF121214),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                'Opciones del viaje',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFF4EC),
                ),
              ),
              const SizedBox(height: 14),
              if (canStartTrip)
                _TripOptionTile(
                  icon: Icons.play_arrow_rounded,
                  title: 'Estoy listo para salir',
                  subtitle: 'Marca que ya estas listo para iniciar.',
                  accentColor: const Color(0xFFF97316),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(tripProvider.notifier).updateTripStatus(
                          token: session.token,
                          tripId: activeTripId,
                          status: 'in_progress',
                        );
                  },
                ),
              if (canChat)
                _TripOptionTile(
                  icon: Icons.chat_bubble_rounded,
                  title: 'Hablar por WhatsApp',
                  subtitle: request.driverPhone ?? 'Numero del conductor',
                  accentColor: const Color(0xFFF97316),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openWhatsApp(
                      phone: request.driverPhone,
                      message:
                          'Hola ${request.driverName ?? 'conductor'}, te escribo desde Flash Go sobre mi viaje.',
                    );
                  },
                ),
              if (canCancel)
                _TripOptionTile(
                  icon: Icons.close_rounded,
                  title: 'Cancelar viaje',
                  subtitle: 'Cancela esta solicitud o viaje activo.',
                  accentColor: const Color(0xFFF97316),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(tripProvider.notifier).updateTripStatus(
                          token: session.token,
                          tripId: activeTripId,
                          status: 'cancelled',
                        );
                  },
                ),
            ],
          ),
        );
      },
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
                'Ver estados',
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _StatusBanner(
                message: _tripStatusHeadline(request.status),
                color: const Color(0xFFFFE6D5),
                textColor: const Color(0xFFC2410C),
                icon: Icons.timeline_rounded,
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
                label: 'Tipo',
                value: (request.vehicleType?.isNotEmpty ?? false)
                    ? request.vehicleType!
                    : 'Por confirmar',
              ),
              _TripInfoRow(
                label: 'Color',
                value: (request.vehicleColor?.isNotEmpty ?? false)
                    ? request.vehicleColor!
                    : 'Por confirmar',
              ),
              _TripInfoRow(
                label: 'Placa',
                value: (request.vehiclePlate?.isNotEmpty ?? false)
                    ? request.vehiclePlate!
                    : 'Por confirmar',
              ),
              _TripInfoRow(
                label: 'Conductor',
                value: (request.driverName?.isNotEmpty ?? false)
                    ? request.driverName!
                    : 'Pendiente',
              ),
              _TripInfoRow(
                label: 'Telefono',
                value: (request.driverPhone?.isNotEmpty ?? false)
                    ? request.driverPhone!
                    : 'Pendiente',
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
      title: 'Flash Go',
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
                            color: const Color(0xFFF97316),
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

    final request = tripState.request;
    final status = request.status;
    final hasOptions = !const {'completed', 'cancelled'}.contains(status) ||
        (request.driverPhone != null &&
            request.driverPhone!.trim().isNotEmpty &&
            const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(status));

    if (!hasOptions) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  List<NearbyDriver> _requestableDrivers(List<NearbyDriver> drivers) {
    return drivers.where((driver) => driver.distanceMeters <= 1000).toList(growable: false);
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
    final offlineState = ref.watch(offlineMapProvider);
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
    final displayNearbyDrivers = _requestableDrivers(tripState.nearbyDrivers);
    final activeDriverKey = activeDriverPoint == null
        ? null
        : '${activeDriverPoint.latitude.toStringAsFixed(6)}:${activeDriverPoint.longitude.toStringAsFixed(6)}';
    final allDriverPoints = tripState.nearbyDrivers
        .map(
          (driver) => PotosiMapDriverMarker(
            point: LatLng(driver.lat, driver.lng),
            vehicleType: driver.vehicleType,
          ),
        )
        .toList(growable: true);
    if (activeDriverPoint != null) {
      final alreadyIncluded = allDriverPoints.any(
        (marker) =>
            '${marker.point.latitude.toStringAsFixed(6)}:${marker.point.longitude.toStringAsFixed(6)}' ==
            activeDriverKey,
      );
      if (!alreadyIncluded) {
        allDriverPoints.add(
          PotosiMapDriverMarker(
            point: activeDriverPoint,
            vehicleType: tripState.request.vehicleType,
          ),
        );
      }
    }
    final driverPoints = allDriverPoints;

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0E0F12), Color(0xFF2A1406)],
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
                    const Color(0xFF101114).withValues(alpha: 0.92),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF121316),
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
                          'Flash Go',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFF4EC),
                          ),
                        ),
                      ),
                    ),
                    _GlassIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () async {
                        await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
                        await _syncDashboard();
                      },
                    ),
                    if (hasActiveTrip) ...[
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.tune_rounded,
                        onTap: () => _showPassengerTripOptions(tripState),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x33F97316), width: 2),
                        color: const Color(0xFF1A1A1D).withValues(alpha: 0.90),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onProfileTap,
                        child: const Icon(Icons.person, color: Color(0xFFF97316)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _PassengerModeCard(
                        activeTrip: hasActiveTrip,
                        rideMode: _rideMode,
                        status: tripState.request.status,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PassengerDashboardActionCard(
                          icon: hasActiveTrip ? Icons.badge_rounded : Icons.directions_car_filled_rounded,
                          title: hasActiveTrip ? 'Conductor asignado' : 'Solicitud de viaje',
                          subtitle: hasActiveTrip
                              ? ((tripState.request.driverName?.isNotEmpty ?? false)
                                  ? tripState.request.driverName!
                                  : 'Datos del conductor disponibles')
                              : (_rideMode == RideMode.destino
                                  ? 'Envia tu pedido a taxis y motos disponibles'
                                  : 'Elige el auto mas cercano a tu punto'),
                          accentColor: hasActiveTrip
                              ? _tripStatusAccentColor(tripState.request.status)
                              : const Color(0xFFF97316),
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
                        color: const Color(0xFF0F0F10).withValues(alpha: 0.94),
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
                          const Icon(Icons.notifications_active, color: Color(0xFFF97316)),
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
          left: 20,
          right: hasActiveTrip ? 156 : 92,
          bottom: 170,
          child: _PassengerFloatingStatusPill(
            title: hasActiveTrip
                ? _tripStatusShortLabel(tripState.request.status)
                : (_rideMode == RideMode.destino ? 'Pedir taxi' : 'Tomar taxi'),
            subtitle: hasActiveTrip
                ? _tripStatusMiniDetail(tripState.request)
                : 'Potosi, Bolivia',
            accentColor: hasActiveTrip
                ? _tripStatusAccentColor(tripState.request.status)
                : const Color(0xFFF97316),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 170,
          child: Column(
            children: [
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
              if (hasActiveTrip) ...[
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.radar_rounded,
                  accentColor: _tripStatusAccentColor(tripState.request.status),
                  onTap: () => _showTripRequestSheet(tripState),
                ),
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.tune_rounded,
                  onTap: () => _showTripRequestSheet(tripState),
                ),
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.download_for_offline_rounded,
                  showBadge: !offlineState.isReady,
                  onTap: () => showOfflineMapSheet(context),
                ),
              ] else ...[
                const SizedBox(height: 12),
                _MapActionButton(
                  icon: Icons.download_for_offline_rounded,
                  showBadge: !offlineState.isReady,
                  onTap: () => showOfflineMapSheet(context),
                ),
              ],
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
            minChildSize: 0.0,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: hasActiveTrip
                ? const [0.0, 0.26, 0.34, 0.58, 0.80]
                : const [0.0, 0.34, 0.58, 0.80],
            builder: (context, scrollController) {
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFF121214),
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
                          color: const Color(0x66F97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E22),
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
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFFC2410C)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _destinationController,
                                decoration: const InputDecoration(
                                  hintText: '¿A dónde quieres ir?',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Color(0xFFB7ABA0)),
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
                        icon: Icons.location_off_rounded,
                      ),
                    if (tripState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _StatusBanner(
                          message: tripState.errorMessage!.replaceFirst('Exception: ', ''),
                          color: const Color(0xFFFFDAD6),
                          textColor: const Color(0xFF93000A),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    if (tripState.request.activeTripId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _LargeTripStatusCard(
                          status: tripState.request.status,
                          vehicleLabel: tripState.request.vehicleLabel,
                          vehiclePlate: tripState.request.vehiclePlate,
                          vehicleType: tripState.request.vehicleType,
                          vehicleColor: tripState.request.vehicleColor,
                          driverName: tripState.request.driverName,
                          driverPhone: tripState.request.driverPhone,
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
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rideMode == RideMode.destino
                          ? 'Aqui solo preparas la solicitud desde tu ubicacion actual.'
                          : 'Mira los taxis cercanos para subir al que te convenga mas rapido.',
                      style: const TextStyle(color: Color(0xFFFFC89B), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    if (_rideMode == RideMode.cercano) ...[
                      if (displayNearbyDrivers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Solo aparecen autos con disponibilidad activa dentro de 1000 m.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFC89B),
                            ),
                          ),
                        ),
                      ..._buildVehicleCards(displayNearbyDrivers),
                    ],
                    if (_rideMode == RideMode.destino)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1F),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF303035)),
                        ),
                        child: const Text(
                          'Los taxis cercanos solo aparecen en "Tomar taxi". En este modo la app envia una solicitud normal de viaje.',
                          style: TextStyle(
                            color: Color(0xFFFFC89B),
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
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: const Color(0xFF0F0F10),
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
          rating: driver.rating.toStringAsFixed(1),
          distance: '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km',
          icon: _vehicleIcon(driver.vehicleType),
          highlighted: isSelected,
          selectedLabel: isSelected ? 'Elegido' : 'Ver detalle',
          onTap: () => _showNearbyDriverDetails(driver),
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

  String _tripStatusShortLabel(String status) {
    return switch (status) {
      'requested' => 'Solicitado',
      'searching' => 'Buscando',
      'accepted' => 'Aceptado',
      'arriving' => 'En camino',
      'at_pickup' => 'Llego',
      'in_progress' => 'En curso',
      'completed' => 'Finalizado',
      _ => 'Activo',
    };
  }

  String _tripStatusMiniDetail(TripRequest request) {
    if (request.etaMinutes != null &&
        (request.status == 'accepted' || request.status == 'arriving')) {
      return '${request.etaMinutes} min';
    }
    if ((request.vehicleLabel?.isNotEmpty ?? false)) {
      return request.vehicleLabel!;
    }
    return 'Ver detalle';
  }

  Color _tripStatusAccentColor(String status) {
    return switch (status) {
      'requested' || 'searching' || 'accepted' || 'arriving' => const Color(0xFFF97316),
      'at_pickup' => const Color(0xFF22C55E),
      'in_progress' => const Color(0xFF0EA5E9),
      'completed' => const Color(0xFF9CA3AF),
      _ => const Color(0xFFF97316),
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
      color: const Color(0xFF1A1A1D).withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      shadowColor: const Color(0x22000000),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFFF97316)),
        ),
      ),
    );
  }
}

class _PassengerModeCard extends StatelessWidget {
  const _PassengerModeCard({
    required this.activeTrip,
    required this.rideMode,
    required this.status,
  });

  final bool activeTrip;
  final RideMode rideMode;
  final String status;

  @override
  Widget build(BuildContext context) {
    final accentColor = activeTrip
        ? switch (status) {
            'at_pickup' => const Color(0xFF22C55E),
            'in_progress' => const Color(0xFF0EA5E9),
            'completed' => const Color(0xFF9CA3AF),
            _ => const Color(0xFFF97316),
          }
        : const Color(0xFFF97316);
    final icon = activeTrip
        ? switch (status) {
            'accepted' || 'arriving' => Icons.directions_car_filled_rounded,
            'at_pickup' => Icons.place_rounded,
            'in_progress' => Icons.alt_route_rounded,
            'completed' => Icons.verified_rounded,
            _ => Icons.route_rounded,
          }
        : (rideMode == RideMode.destino ? Icons.route_rounded : Icons.local_taxi_rounded);
    final title = activeTrip ? 'Tu viaje' : (rideMode == RideMode.destino ? 'Pedir' : 'Tomar');

    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17181B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFF4EC),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerDashboardActionCard extends StatelessWidget {
  const _PassengerDashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17181B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFF4EC),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD8BF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.onTap,
    this.accentColor = const Color(0xFFF97316),
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: const Color(0xFF1A1A1D),
          borderRadius: BorderRadius.circular(18),
          elevation: 6,
          shadowColor: const Color(0x14000003),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icon, color: accentColor),
            ),
          ),
        ),
        if (showBadge)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF111214), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33F97316),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PassengerFloatingStatusPill extends StatelessWidget {
  const _PassengerFloatingStatusPill({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF17181B).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFFFF4EC),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD8BF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
      color: selected ? const Color(0xFFF97316) : Colors.transparent,
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
              color: selected ? const Color(0xFF0F0F10) : const Color(0xFFFFC89B),
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
    required this.rating,
    required this.distance,
    required this.icon,
    required this.highlighted,
    required this.selectedLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String eta;
  final String rating;
  final String distance;
  final IconData icon;
  final bool highlighted;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? const Color(0xFF20160F) : const Color(0xFF18191C),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: highlighted ? const Color(0xFFF97316) : const Color(0xFF2E2E34),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: highlighted ? const Color(0xFF0F0F10) : const Color(0xFF25252B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? const Color(0xFFF97316) : const Color(0xFFFFC89B),
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
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFFFFC89B), fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Llega en $eta · $distance',
                      style: const TextStyle(color: Color(0xFFFFDCC1), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (highlighted) ...[
                    const Icon(Icons.check_circle, color: Color(0xFFC2410C), size: 18),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFF97316), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF4EC),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: highlighted ? const Color(0xFFF97316) : const Color(0xFF25252B),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: highlighted ? const Color(0xFFF97316) : const Color(0x44F97316),
                      ),
                    ),
                    child: Text(
                      selectedLabel,
                      style: TextStyle(
                        color: highlighted ? const Color(0xFF0F0F10) : const Color(0xFFFFC89B),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
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
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF303035)),
      ),
      child: const Text(
        'Todavia no vemos taxis activos. Usa "mi ubicacion" y espera unos segundos para cargar autos cercanos.',
        style: TextStyle(
          color: Color(0xFFFFC89B),
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
    this.vehicleType,
    this.vehicleColor,
    this.driverName,
    this.driverPhone,
    this.etaMinutes,
  });

  final String status;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final String? vehicleType;
  final String? vehicleColor;
  final String? driverName;
  final String? driverPhone;
  final int? etaMinutes;

  String get _title => switch (status) {
        'requested' => 'Solicitud enviada',
        'searching' => 'Buscando conductor',
        'accepted' => 'Taxi aceptado',
        'arriving' => 'Taxi en camino',
        'at_pickup' => 'Taxi listo para subir',
        'in_progress' => 'Viaje en progreso',
        'completed' => 'Viaje finalizado',
        'cancelled' => 'Viaje cancelado',
        _ => 'Estado del viaje',
      };

  String get _subtitle => switch (status) {
        'requested' => 'Estamos enviando tu solicitud a los conductores disponibles.',
        'searching' => 'Muy pronto veras quien acepta tu viaje.',
        'accepted' => etaMinutes == null
            ? 'Tu conductor ya confirmo el viaje.'
            : 'Tu conductor ya confirmo el viaje y llega en $etaMinutes min.',
        'arriving' => etaMinutes == null
            ? 'Sigue el recorrido del conductor hacia tu punto.'
            : 'Tu conductor va en camino y llega en $etaMinutes min.',
        'at_pickup' => 'Verifica el auto y sube cuando estes listo.',
        'in_progress' => 'Viaje en progreso.',
        'completed' => 'Gracias por viajar con Flash Go.',
        'cancelled' => 'Puedes volver a solicitar un taxi cuando quieras.',
        _ => 'Estamos actualizando el estado de tu viaje.',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10).withValues(alpha: 0.92),
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
              color: Color(0xFFFFC89B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _TripProgressBar(status: status),
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
                if ((vehicleColor ?? '').isNotEmpty)
                  _TripBadge(icon: Icons.palette_outlined, label: 'Color ${vehicleColor!}'),
                if ((vehicleType ?? '').isNotEmpty)
                  _TripBadge(
                    icon: (vehicleType ?? '').toLowerCase() == 'moto'
                        ? Icons.two_wheeler_rounded
                        : Icons.local_taxi_rounded,
                    label: 'Tipo ${vehicleType!}',
                  ),
                if ((driverName ?? '').isNotEmpty)
                  _TripBadge(icon: Icons.person_outline_rounded, label: driverName!),
                if ((driverPhone ?? '').isNotEmpty)
                  _TripBadge(icon: Icons.phone_outlined, label: driverPhone!),
              ],
            ),
          ],
          if ((driverName ?? '').isNotEmpty || (driverPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Contacto del conductor',
                    style: TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((driverName ?? '').isNotEmpty)
                    _TripContactRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Nombre',
                      value: driverName!,
                    ),
                  if ((driverPhone ?? '').isNotEmpty) ...[
                    if ((driverName ?? '').isNotEmpty) const SizedBox(height: 10),
                    _TripContactRow(
                      icon: Icons.phone_outlined,
                      label: 'WhatsApp',
                      value: driverPhone!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripProgressBar extends StatelessWidget {
  const _TripProgressBar({
    required this.status,
  });

  final String status;

  static const _steps = [
    ('requested', 'Solicitado'),
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
                    color: isActive ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.18),
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
                color: isReached ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReached ? const Color(0xFFF97316) : Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                isReached ? Icons.check : Icons.circle,
                size: isReached ? 14 : 8,
                color: isReached ? const Color(0xFF0F0F10) : Colors.white.withValues(alpha: 0.45),
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
                  color: highlighted ? Colors.white : Colors.white.withValues(alpha: 0.58),
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
          Icon(icon, color: const Color(0xFFF97316), size: 16),
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

class _TripContactRow extends StatelessWidget {
  const _TripContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFF97316)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFFD8BF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
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

class _TripOptionTile extends StatelessWidget {
  const _TripOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x44F97316)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFFF4EC),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFFFC89B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: accentColor),
              ],
            ),
          ),
        ),
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
                color: Color(0xFFFFD8BF),
                fontWeight: FontWeight.w700,
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.textColor,
    this.icon = Icons.radar_rounded,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
