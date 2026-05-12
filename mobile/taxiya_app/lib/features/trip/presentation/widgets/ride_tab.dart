import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/potosi_places.dart';
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
  });

  final VoidCallback onMenuTap;

  @override
  ConsumerState<RideTab> createState() => _RideTabState();
}

class _RideTabState extends ConsumerState<RideTab> with WidgetsBindingObserver {
  static const String _lastPassengerLatKey = 'flashgo_passenger_last_lat';
  static const String _lastPassengerLngKey = 'flashgo_passenger_last_lng';
  static const String _customDestinationLabel = 'Destino marcado en mapa';
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
  PotosiPlace? _selectedDestinationPlace;
  LatLng? _customDestinationPoint;
  int _mapFocusSignal = 0;
  bool _isSyncingDashboard = false;
  bool _isPreparingExperience = false;
  bool _offlineSheetQueued = false;
  LatLng? _lastKnownLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(_syncDashboard);
    _startRefreshLoop();
    _connectSocket();
    Future<void>.microtask(_preparePassengerExperience);
    _tripSubscription = ref.listenManual<TripState>(tripProvider, (previous, next) {
      final previousStatus = previous?.request.status;
      final currentStatus = next.request.status;
      if (previousStatus != currentStatus) {
        _handleTripStatusChange(next.request);
      }
    });
  }

  Future<void> _preparePassengerExperience() async {
    if (_isPreparingExperience) {
      return;
    }
    _isPreparingExperience = true;
    try {
      await _ensureCriticalPermissions();
      await LocalNotifications.ensureInitialized();
      await _restoreLastKnownLocation();
      await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
      final currentLocation = ref.read(passengerLocationProvider).position;
      if (currentLocation != null) {
        await _persistLastKnownLocation(currentLocation);
      }

      if (!mounted) {
        return;
      }

      final offlineController = ref.read(offlineMapProvider.notifier);
      await offlineController.refreshStatus();
      final offlineState = ref.read(offlineMapProvider);
      if (AppConfig.hasDedicatedOfflineTileSource &&
          !offlineState.isReady &&
          !offlineState.isDownloading &&
          !_offlineSheetQueued) {
        _offlineSheetQueued = true;
        Future<void>.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) {
            return;
          }
          await showOfflineMapSheet(context);
        });
      }
    } catch (_) {
      // Keep startup resilient on low-resource or partially configured devices.
    } finally {
      _isPreparingExperience = false;
    }
  }

  Future<void> _ensureCriticalPermissions() async {
    while (mounted) {
      final notificationStatus = await Permission.notification.request();
      final locationStatus = await Permission.locationWhenInUse.request();
      final notificationsReady = notificationStatus.isGranted || notificationStatus.isLimited;
      final locationReady = locationStatus.isGranted || locationStatus.isLimited;
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
            style: TextStyle(color: Color(0xFFFFF4EC), fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flash Go necesita estos permisos completos para entrar con todo listo y evitar fallos despues.',
                style: TextStyle(color: Color(0xFFFFD8BF)),
              ),
              const SizedBox(height: 12),
              Text(
                '${locationReady ? '✓' : '•'} Ubicacion activa',
                style: TextStyle(
                  color: locationReady ? const Color(0xFF86EFAC) : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${notificationsReady ? '✓' : '•'} Notificaciones activas',
                style: TextStyle(
                  color: notificationsReady ? const Color(0xFF86EFAC) : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
              },
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

  @override
  void dispose() {
    final location = ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
    if (location != null) {
      unawaited(_persistLastKnownLocation(location));
    }
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _notificationTimer?.cancel();
    _tripSubscription?.close();
    _socket?.dispose();
    _sheetController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshLoop();
      Future<void>.microtask(_syncDashboard);
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final location = ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
      if (location != null) {
        unawaited(_persistLastKnownLocation(location));
      }
      _stopRefreshLoop();
    }
  }

  void _startRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => Future<void>.microtask(_syncDashboard),
    );
  }

  void _stopRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
    _socket?.on('trip:destination_updated', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final destinationAddress = map['destinationAddress']?.toString();
      final destinationLat = double.tryParse(map['destinationLat']?.toString() ?? '');
      final destinationLng = double.tryParse(map['destinationLng']?.toString() ?? '');
      if (destinationAddress != null && destinationLat != null && destinationLng != null) {
        ref.read(tripProvider.notifier).applyTripDestinationUpdate(
              destinationAddress: destinationAddress,
              destinationLat: destinationLat,
              destinationLng: destinationLng,
            );
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
    final location = ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
    if (!mounted || !session.isAuthenticated || location == null) {
      return;
    }

    _isSyncingDashboard = true;
    try {
      await _persistLastKnownLocation(location);
      await ref.read(tripProvider.notifier).loadDashboard(
            token: session.token,
            passengerId: session.userId,
            userLocation: location,
          );
    } catch (_) {
      // Swallow transient backend/network errors to avoid noisy crashes on timer refresh.
    } finally {
      _isSyncingDashboard = false;
    }
  }

  Future<void> _restoreLastKnownLocation() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_lastPassengerLatKey);
    final longitude = preferences.getDouble(_lastPassengerLngKey);
    if (latitude == null || longitude == null || !mounted) {
      return;
    }
    setState(() {
      _lastKnownLocation = LatLng(latitude, longitude);
    });
  }

  Future<void> _persistLastKnownLocation(LatLng point) async {
    final current = _lastKnownLocation;
    final unchanged = current != null &&
        (current.latitude - point.latitude).abs() < 0.000001 &&
        (current.longitude - point.longitude).abs() < 0.000001;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_lastPassengerLatKey, point.latitude);
    await preferences.setDouble(_lastPassengerLngKey, point.longitude);
    if (!mounted || unchanged) {
      return;
    }
    setState(() {
      _lastKnownLocation = point;
    });
  }

  List<PotosiPlace> _destinationSuggestions() {
    final query = _destinationController.text.trim();
    if (query.isEmpty) {
      return PotosiPlaces.search('', limit: 5);
    }
    return PotosiPlaces.search(query, limit: 6);
  }

  void _handleDestinationChanged(String value) {
    final selected = _selectedDestinationPlace;
    if (selected == null) {
      if (_customDestinationPoint != null &&
          value.trim().toLowerCase() != _customDestinationLabel.toLowerCase()) {
        setState(() {
          _customDestinationPoint = null;
        });
        return;
      }
      setState(() {});
      return;
    }

    if (value.trim().toLowerCase() != selected.name.toLowerCase()) {
      setState(() {
        _selectedDestinationPlace = null;
      });
      return;
    }

    setState(() {});
  }

  void _selectDestinationPlace(PotosiPlace place) {
    _destinationController.value = TextEditingValue(
      text: place.name,
      selection: TextSelection.collapsed(offset: place.name.length),
    );
    setState(() {
      _selectedDestinationPlace = place;
      _customDestinationPoint = null;
    });
  }

  PotosiPlace? _resolveDestinationPlace() {
    return _selectedDestinationPlace ?? PotosiPlaces.findExact(_destinationController.text.trim());
  }

  LatLng? _resolveDestinationPoint() {
    return _resolveDestinationPlace()?.point ?? _customDestinationPoint;
  }

  bool _canChooseDestinationForActiveTrip(TripRequest request) {
    return (request.activeTripId?.isNotEmpty ?? false) && request.status == 'at_pickup';
  }

  bool _activeTripNeedsDestination(TripRequest request) {
    if (!_canChooseDestinationForActiveTrip(request)) {
      return false;
    }
    final currentAddress = request.destinationAddress.trim().toLowerCase();
    return request.destinationLat == null ||
        request.destinationLng == null ||
        currentAddress.isEmpty ||
        currentAddress == 'abordaje inmediato' ||
        currentAddress == 'destino por confirmar';
  }

  Future<void> _saveActiveTripDestination() async {
    final request = ref.read(tripProvider).request;
    final session = ref.read(sessionProvider);
    final destinationPoint = _resolveDestinationPoint();
    final destinationAddress = _destinationController.text.trim();
    if (!_canChooseDestinationForActiveTrip(request) || request.activeTripId == null) {
      return;
    }
    if (destinationPoint == null) {
      _showMessage('Marca o selecciona primero el destino final del viaje.');
      return;
    }
    if (destinationAddress.isEmpty) {
      _showMessage('Escribe o marca el destino para poder guardarlo.');
      return;
    }
    await ref.read(tripProvider.notifier).updateTripDestination(
          token: session.token,
          tripId: request.activeTripId!,
          destinationAddress: destinationAddress,
          destinationLocation: destinationPoint,
        );
    final error = ref.read(tripProvider).errorMessage;
    if (error != null) {
      _showMessage(error.replaceFirst('Exception: ', ''));
      return;
    }
    _showFloatingNotification('Destino guardado. Ya pueden iniciar el viaje con la ruta correcta.');
  }

  void _selectDestinationFromMap(LatLng point) {
    if (!mounted) {
      return;
    }
    _destinationController.value = const TextEditingValue(
      text: _customDestinationLabel,
      selection: TextSelection.collapsed(offset: _customDestinationLabel.length),
    );
    setState(() {
      _selectedDestinationPlace = null;
      _customDestinationPoint = point;
      _mapFocusSignal++;
    });
    _showFloatingNotification('Destino marcado en el mapa. Ese punto sera el final del viaje.');
  }

  Future<void> _requestRide() async {
    final session = ref.read(sessionProvider);
    final locationState = ref.read(passengerLocationProvider);
    final location = locationState.position ?? _lastKnownLocation;
    final request = ref.read(tripProvider).request;
    final isRetryingRequest =
        (request.activeTripId?.isNotEmpty ?? false) &&
        const {'requested', 'searching'}.contains(request.status);
    if (const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(request.status) &&
        (request.activeTripId?.isNotEmpty ?? false)) {
      _showMessage('Ya tienes un conductor asignado. Ahora solo puedes seguir ese viaje activo.');
      return;
    }
    final destination = _destinationController.text.trim();
    final resolvedDestinationPoint = _resolveDestinationPoint();
    final resolvedDestination =
        _rideMode == RideMode.cercano && destination.isEmpty
            ? 'Abordaje inmediato'
            : (destination.isEmpty && resolvedDestinationPoint != null ? _customDestinationLabel : destination);
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

    if (_rideMode == RideMode.destino && resolvedDestinationPoint == null) {
      _showMessage('Selecciona un lugar sugerido o marca tu destino tocando el mapa.');
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
          destinationLocation: resolvedDestinationPoint,
          preferredDriverId: selectedDriverId,
        );

    final error = ref.read(tripProvider).errorMessage;
    if (error != null && mounted) {
      _showMessage(error.replaceFirst('Exception: ', ''));
      return;
    }

    if (mounted) {
      if (isRetryingRequest) {
        _showFloatingNotification('Solicitud reenviada. Seguimos buscando un conductor para ti.');
      } else {
        _showFloatingNotification(
          selectedDriver == null
              ? 'Solicitud enviada. Estamos buscando un conductor.'
              : 'Solicitud enviada a ${selectedDriver.vehicleLabel}. Esperando respuesta.',
        );
      }
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
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.84,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
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
              ),
            ),
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

  void _showTripRequestSheet(TripState tripState) {
    final request = tripState.request;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEFEFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
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
              if (request.isPromotional && request.status == 'in_progress') ...[
                const SizedBox(height: 10),
                const _StatusBanner(
                  message: 'Viaje gratis activo',
                  color: Color(0x1422C55E),
                  textColor: Color(0xFF86EFAC),
                  icon: Icons.card_giftcard_rounded,
                ),
              ],
              const SizedBox(height: 16),
              _TripInfoRow(label: 'Estado', value: request.status),
              if (request.isPromotional && request.status == 'in_progress') ...[
                const _TripInfoRow(label: 'Promo', value: 'Este viaje no se cobra al pasajero'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showPassengerPromoNotice(request),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0x1F22C55E),
                      foregroundColor: const Color(0xFFE9FFF0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: const Text(
                      'Ver aviso de viaje gratis',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPassengerPromoNotice(TripRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.74,
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
                          color: const Color(0x5522C55E),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0x1F22C55E),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF86EFAC)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Tu viaje gratis',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFF4EC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1D),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x3322C55E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TripInfoRow(label: 'Destino', value: request.destinationAddress),
                          _TripInfoRow(label: 'Conductor', value: request.driverName?.isNotEmpty == true ? request.driverName! : 'Pendiente'),
                          _TripInfoRow(label: 'Vehiculo', value: request.vehicleLabel?.isNotEmpty == true ? request.vehicleLabel! : 'Pendiente'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0x1F22C55E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x3322C55E)),
                      ),
                      child: const Text(
                        'AVISO FLASH GO - VIAJE PREMIADO\n\nTu viaje gratis por promocion es valido solo para ti como cliente registrado en la app Flash Go.\n\nNota importante: El beneficio cubre solamente a una (1) persona. Si viajas con acompañantes, el conductor podra realizar el cobro normal correspondiente por ellos. Gracias por usar Flash Go y disfrutar tu premio.',
                        style: TextStyle(
                          color: Color(0xFFE9FFF0),
                          fontWeight: FontWeight.w700,
                          height: 1.5,
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

    if (request.status == 'completed' || request.status == 'cancelled') {
      final finalPoint =
          request.status == 'completed' &&
                  request.destinationLat != null &&
                  request.destinationLng != null
              ? LatLng(request.destinationLat!, request.destinationLng!)
              : ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
      if (finalPoint != null) {
        unawaited(_persistLastKnownLocation(finalPoint));
      }
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
                content: SingleChildScrollView(
                  child: Column(
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

  LatLngBounds? _buildPassengerFocusBounds({
    required LatLng userLocation,
    LatLng? activeDriverPoint,
    LatLng? activeDestinationPoint,
    required bool isRideInProgress,
  }) {
    if (isRideInProgress && activeDriverPoint != null && activeDestinationPoint != null) {
      return LatLngBounds.fromPoints([activeDriverPoint, activeDestinationPoint]);
    }
    if (activeDriverPoint != null) {
      return LatLngBounds.fromPoints([userLocation, activeDriverPoint]);
    }
    return null;
  }

  String _primaryActionLabel(TripState tripState) {
    if (tripState.isRequestingTrip) {
      return 'Enviando solicitud...';
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        const {'requested', 'searching'}.contains(tripState.request.status)) {
      return 'Volver a enviar solicitud';
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
    final userLocation = locationState.position ?? _lastKnownLocation ?? const LatLng(-19.5836, -65.7531);
    final hasActiveTrip = activeTripId != null && activeTripId.isNotEmpty;
      final rideLocked = hasActiveTrip &&
          const {'accepted', 'arriving', 'at_pickup', 'in_progress'}
              .contains(tripState.request.status);
    final activeDriverPoint =
        tripState.request.driverLat != null && tripState.request.driverLng != null
            ? LatLng(tripState.request.driverLat!, tripState.request.driverLng!)
            : null;
    final selectedDestinationPoint = _resolveDestinationPoint();
    final activeDestinationPoint =
        tripState.request.destinationLat != null && tripState.request.destinationLng != null
            ? LatLng(tripState.request.destinationLat!, tripState.request.destinationLng!)
            : selectedDestinationPoint;
    final activeStatus = tripState.request.status;
    final canChooseActiveTripDestination = _canChooseDestinationForActiveTrip(tripState.request);
    final activeTripNeedsDestination = _activeTripNeedsDestination(tripState.request);
    final isRideInProgress = activeStatus == 'in_progress';
    final focusBounds = _buildPassengerFocusBounds(
      userLocation: userLocation,
      activeDriverPoint: activeDriverPoint,
      activeDestinationPoint: activeDestinationPoint,
      isRideInProgress: isRideInProgress,
    );
    final mapRouteColor = hasActiveTrip
        ? (isRideInProgress ? const Color(0xFF0EA5E9) : const Color(0xFFF97316))
        : const Color(0xFFF97316);
    final mapRouteStart = hasActiveTrip && isRideInProgress ? activeDriverPoint : null;
    final mapRouteTarget = hasActiveTrip
        ? (isRideInProgress ? activeDestinationPoint : activeDriverPoint)
        : selectedDestinationPoint;
    final shouldDrawPreviewRoute = hasActiveTrip
        ? (isRideInProgress ? (mapRouteStart != null && mapRouteTarget != null) : activeDriverPoint != null)
        : _rideMode == RideMode.destino && selectedDestinationPoint != null;
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
                drivers: driverPoints,
                userLocation: userLocation,
                routeStart: mapRouteStart,
                routeTarget: mapRouteTarget,
                secondaryMarker: hasActiveTrip && !isRideInProgress ? activeDestinationPoint : null,
                showRoute: shouldDrawPreviewRoute,
                showTargetMarker: mapRouteTarget != null,
                routeColor: mapRouteColor,
                focusBounds: focusBounds,
                focusSignal: _mapFocusSignal,
                onRouteUpdated: () {
                  if (!mounted) {
                    return;
                  }
                  _showFloatingNotification('Ruta actualizada. Seguimos el mejor camino hacia tu destino.');
                },
                onMapTap: ((!rideLocked && _rideMode == RideMode.destino) || canChooseActiveTripDestination)
                    ? _selectDestinationFromMap
                    : null,
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
                    const Spacer(),
                    _GlassIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () async {
                        await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
                        await _syncDashboard();
                        if (mounted) {
                          setState(() => _mapFocusSignal++);
                        }
                      },
                    ),
                    if (hasActiveTrip) ...[
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.radar_rounded,
                        onTap: () => _showTripRequestSheet(tripState),
                      ),
                    ],
                  ],
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
          right: 20,
          bottom: 170,
          child: Column(
            children: [
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
                    if (!rideLocked)
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
                                  _selectedDestinationPlace = null;
                                  _customDestinationPoint = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ModeButton(
                                label: 'Tomar taxi',
                                selected: _rideMode == RideMode.cercano,
                                onTap: () => setState(() {
                                  _rideMode = RideMode.cercano;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    if ((!rideLocked && _rideMode == RideMode.destino) || canChooseActiveTripDestination)
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
                                onChanged: _handleDestinationChanged,
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
                    if ((!rideLocked && _rideMode == RideMode.destino) || canChooseActiveTripDestination) ...[
                      const SizedBox(height: 12),
                      if (_selectedDestinationPlace != null || _customDestinationPoint != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17181B),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0x33F97316)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: Color(0xFFF97316),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDestinationPlace?.name ?? _customDestinationLabel,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFFF4EC),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedDestinationPlace != null
                                          ? 'Destino exacto listo para la ruta del conductor'
                                          : 'Punto personalizado listo para guiar el viaje',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFFC89B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  _destinationController.clear();
                                  setState(() {
                                    _selectedDestinationPlace = null;
                                    _customDestinationPoint = null;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, color: Color(0xFFFFF4EC)),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF17181B),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0x2610B981)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.touch_app_rounded,
                                    color: Color(0xFF10B981),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Si tu destino no aparece, toca el mapa para marcarlo exacto.',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFE6FFF5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _destinationSuggestions()
                                  .map(
                                    (place) => ActionChip(
                                      onPressed: () => _selectDestinationPlace(place),
                                      avatar: const Icon(
                                        Icons.near_me_rounded,
                                        size: 18,
                                        color: Color(0xFFF97316),
                                      ),
                                      backgroundColor: const Color(0xFF1A1B1F),
                                      side: const BorderSide(color: Color(0x26F97316)),
                                      label: Text(
                                        place.name,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFFFF4EC),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                    ],
                    if ((!rideLocked && _rideMode == RideMode.destino) || canChooseActiveTripDestination)
                      const SizedBox(height: 18),
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
                    if (activeTripNeedsDestination)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0x1410B981),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x3310B981)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.route_rounded, color: Color(0xFF10B981)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Marca el destino antes de iniciar el viaje',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFE6FFF5),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tu conductor ya llegó. Ahora puedes tocar el mapa o elegir un lugar para dejar guardado el destino final.',
                                style: TextStyle(
                                  color: Color(0xFFD6FFF0),
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _saveActiveTripDestination,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: const Color(0xFF0B1210),
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text(
                                    'Guardar destino del viaje',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildTripActions(tripState),
                    const SizedBox(height: 12),
                    if (rideLocked)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1F),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF303035)),
                        ),
                        child: const Text(
                          'Tu conductor ya acepto el viaje. Ahora solo puedes ver sus datos, el progreso y esperar la llegada.',
                          style: TextStyle(
                            color: Color(0xFFFFC89B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (tripState.request.isPromotional)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0x1416A34A),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0x3322C55E)),
                        ),
                        child: const Text(
                          'Este pedido usara tu viaje gratis por promocion.',
                          style: TextStyle(
                            color: Color(0xFFDCFCE7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else ...[
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
                    ],
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
          child: Icon(icon, color: const Color(0xFFF97316)),
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
