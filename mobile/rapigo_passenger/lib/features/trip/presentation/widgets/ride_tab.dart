// ignore_for_file: unused_element, unused_local_variable, unused_element_parameter

import 'dart:async';
import 'dart:io';

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
import '../../../../core/config/app_brand.dart';
import '../../../../core/config/potosi_places.dart';
import '../../../../core/map/geocoding_service.dart';
import '../../../../core/map/map_navigation_banner.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/ui/top_notice.dart';
import '../../../map/data/location_controller.dart';
import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import '../pages/route_preview_page.dart';
import '../pages/take_taxi_page.dart';
import 'destination_search_sheet.dart';
import 'map_home_drawer.dart';
import 'route_review_view.dart';

class RideTab extends ConsumerStatefulWidget {
  const RideTab({
    super.key,
    required this.onMenuTap,
    this.initialMode = RideMode.destino,
    this.openFlowOnStart = false,
    this.initialDestinationLabel,
    this.initialDestinationPoint,
    this.startInMapPicker = false,
    this.onBackToLauncher,
  });

  final VoidCallback onMenuTap;
  final RideMode initialMode;
  final bool openFlowOnStart;
  final String? initialDestinationLabel;
  final LatLng? initialDestinationPoint;
  final bool startInMapPicker;
  final VoidCallback? onBackToLauncher;

  @override
  ConsumerState<RideTab> createState() => _RideTabState();
}

enum RideFlowState { reposo, busquedaTexto, seleccionManual, rutaConfirmacion }

class _RideTabState extends ConsumerState<RideTab> with WidgetsBindingObserver {
  static const String _lastPassengerLatKey = 'rapigo_passenger_last_lat';
  static const String _lastPassengerLngKey = 'rapigo_passenger_last_lng';
  static const String _backgroundNoticeSeenKey =
      'rapigo_passenger_background_notice_seen';
  static const String _rideUiStateKey = 'rapigo_passenger_ride_ui_state_v1';
  static const String _customDestinationLabel = 'Destino marcado en mapa';
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  Timer? _refreshTimer;
  Timer? _notificationTimer;
  Timer? _scheduledDashboardSync;
  Timer? _destinationMoveDebounce;
  ProviderSubscription<TripState>? _tripSubscription;
  io.Socket? _socket;
  String? _floatingNotification;
  NoticeTone _floatingNotificationTone = NoticeTone.info;
  RideMode _rideMode = RideMode.destino;
  String? _joinedTripId;
  String? _selectedDriverId;
  String? _ratingPromptedTripId;
  PotosiPlace? _selectedDestinationPlace;
  LatLng? _customDestinationPoint;
  bool _destinationMoveMode = false;
  int _mapFocusSignal = 0;
  bool _isSyncingDashboard = false;
  bool _isPreparingExperience = false;
  bool _isDraggingDestinationMap = false;
  bool _topActionsExpanded = false;
  bool _homeDrawerExpanded = false;
  bool _isRoutePreviewPageOpen = false;
  bool _isTakeTaxiPageOpen = false;
  bool _suspendTakeTaxiAutoOpen = false;
  bool _isEndingTripFlow = false;
  bool _journeyDetailsExpanded = false;
  bool _journeyStartedFromTakeTaxi = false;
  String _selectedServiceType = 'taxi';
  LatLng? _lastKnownLocation;
  LatLng? _movingDestinationCenter;
  String _currentAddressText = 'Buscando ubicación...';
  final Map<String, String> _reverseGeocodeCache = <String, String>{};
  int _mapCenterSignal = 0;
  int _destinationLookupRequestId = 0;
  RideFlowState _flowState = RideFlowState.reposo;
  String? _lastUiStateSignature;

  @override
  void initState() {
    super.initState();
    _rideMode = widget.initialMode;
    _flowState =
        widget.openFlowOnStart && widget.initialMode == RideMode.destino
        ? RideFlowState.busquedaTexto
        : RideFlowState.reposo;
    WidgetsBinding.instance.addObserver(this);
    _runAfterBuild(_syncDashboard);
    _startRefreshLoop();
    _connectSocket();
    _runAfterBuild(_preparePassengerExperience);
    if (!widget.openFlowOnStart) {
      _runAfterBuild(_restoreRideUiState);
    }
    if (widget.openFlowOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (widget.initialMode == RideMode.cercano) {
          _activateNearbyMode();
        } else if (widget.startInMapPicker) {
          _activateDestinationMode();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_destinationMoveMode) {
              _toggleDestinationMoveMode();
            }
          });
        } else if (widget.initialDestinationPoint != null) {
          _applyInitialDestination(
            widget.initialDestinationLabel ?? _customDestinationLabel,
            widget.initialDestinationPoint!,
          );
        } else {
          _activateDestinationMode();
        }
      });
    }
    _tripSubscription = ref.listenManual<TripState>(tripProvider, (
      previous,
      next,
    ) {
      final previousStatus = previous?.request.status;
      final currentStatus = next.request.status;
      if (previousStatus != currentStatus) {
        _handleTripStatusChange(next.request);
      }
    });
  }

  Future<void> _restoreRideUiState() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_rideUiStateKey);
    if (raw == null || raw.isEmpty || !mounted) {
      return;
    }
    final payload = raw.split('|');
    if (payload.length < 9) {
      return;
    }
    final restoredMode = payload[0] == RideMode.cercano.name
        ? RideMode.cercano
        : RideMode.destino;
    final restoredFlow = RideFlowState.values.firstWhere(
      (state) => state.name == payload[1],
      orElse: () => RideFlowState.reposo,
    );
    final customLat = double.tryParse(payload[4]);
    final customLng = double.tryParse(payload[5]);
    final destinationLabel = payload[3].isEmpty ? null : payload[3];
    setState(() {
      _rideMode = restoredMode;
      _flowState = restoredFlow;
      _destinationMoveMode = payload[2] == '1';
      _selectedDriverId = payload[6].isEmpty ? null : payload[6];
      _selectedServiceType = payload[7].isEmpty ? 'taxi' : payload[7];
      _journeyDetailsExpanded = payload[8] == '1';
      if (customLat != null && customLng != null) {
        _customDestinationPoint = LatLng(customLat, customLng);
      }
      if (destinationLabel != null && destinationLabel.trim().isNotEmpty) {
        _destinationController.text = destinationLabel;
      }
    });
  }

  Future<void> _persistRideUiState() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = <String>[
      _rideMode.name,
      _flowState.name,
      _destinationMoveMode ? '1' : '0',
      _destinationController.text.trim(),
      _customDestinationPoint?.latitude.toString() ?? '',
      _customDestinationPoint?.longitude.toString() ?? '',
      _selectedDriverId ?? '',
      _selectedServiceType,
      _journeyDetailsExpanded ? '1' : '0',
    ].join('|');
    await preferences.setString(_rideUiStateKey, raw);
  }

  Future<void> _preparePassengerExperience() async {
    if (_isPreparingExperience) {
      return;
    }
    _isPreparingExperience = true;
    try {
      await _ensureCriticalPermissions();
      await _maybeShowBackgroundServiceNotice();
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
      await offlineController.ensureOfflineAvailability();
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
                'RAPIGO necesita estos permisos completos para entrar con todo listo y evitar fallos despues.',
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
            'RAPIGO seguira activo',
            style: TextStyle(
              color: Color(0xFFFFF4EC),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Veras una notificacion fija mientras RAPIGO use ubicacion en segundo plano. Es normal: sirve para que el mapa, las alertas y el seguimiento del viaje sigan funcionando aunque bloquees el celular.',
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

  @override
  void dispose() {
    final location = _lastKnownLocation;
    if (location != null) {
      unawaited(_persistLastKnownLocation(location));
    }
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scheduledDashboardSync?.cancel();
    _notificationTimer?.cancel();
    _tripSubscription?.close();
    _socket?.dispose();
    _destinationMoveDebounce?.cancel();
    _sheetController.dispose();
    _destinationController.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshLoop();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final location =
          ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
      if (location != null) {
        unawaited(_persistLastKnownLocation(location));
      }
      _stopRefreshLoop();
    }
  }

  void _startRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_syncDashboard()),
    );
  }

  void _stopRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _scheduleDashboardSync([
    Duration delay = const Duration(milliseconds: 500),
  ]) {
    if (_destinationMoveMode) {
      return;
    }
    _scheduledDashboardSync?.cancel();
    _scheduledDashboardSync = Timer(delay, () {
      unawaited(_syncDashboard());
    });
  }

  void _runAfterBuild(Future<void> Function() action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(action());
    });
  }

  String _mainMapViewportKey({required bool hasActiveTrip}) {
    if (_destinationMoveMode) {
      return 'passenger_manual_destination';
    }
    if (hasActiveTrip) {
      return 'passenger_active_trip';
    }
    return 'passenger_home_map';
  }

  String _reverseGeocodeCacheKey(LatLng point) {
    final latitude = point.latitude.toStringAsFixed(4);
    final longitude = point.longitude.toStringAsFixed(4);
    return '$latitude,$longitude';
  }

  void _storeReverseGeocodeCache(String key, String label) {
    if (_reverseGeocodeCache.containsKey(key)) {
      _reverseGeocodeCache.remove(key);
    }
    _reverseGeocodeCache[key] = label;
    if (_reverseGeocodeCache.length > 40) {
      _reverseGeocodeCache.remove(_reverseGeocodeCache.keys.first);
    }
  }

  void _connectSocket() {
    _socket?.dispose();
    _socket = io.io(
      AppConfig.websocketUrl,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(['websocket', 'polling'])
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
      _scheduleDashboardSync();
    });
    _socket?.on('trip:accepted', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final etaMinutes = map['etaMinutes'] is num
          ? (map['etaMinutes'] as num).toInt()
          : int.tryParse(map['etaMinutes']?.toString() ?? '');
      if (tripId != null && tripId.isNotEmpty) {
        ref
            .read(tripProvider.notifier)
            .markTripAccepted(tripId: tripId, etaMinutes: etaMinutes);
        _scheduleDashboardSync();
      }
    });
    _socket?.on('trip:status_changed', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final status = map['status']?.toString();
      if (tripId != null &&
          status != null &&
          tripId.isNotEmpty &&
          status.isNotEmpty) {
        ref
            .read(tripProvider.notifier)
            .markTripAccepted(tripId: tripId, status: status);
        _scheduleDashboardSync();
      }
    });
    _socket?.on('trip:destination_updated', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final destinationAddress = map['destinationAddress']?.toString();
      final destinationLat = double.tryParse(
        map['destinationLat']?.toString() ?? '',
      );
      final destinationLng = double.tryParse(
        map['destinationLng']?.toString() ?? '',
      );
      if (destinationAddress != null &&
          destinationLat != null &&
          destinationLng != null) {
        ref
            .read(tripProvider.notifier)
            .applyTripDestinationUpdate(
              destinationAddress: destinationAddress,
              destinationLat: destinationLat,
              destinationLng: destinationLng,
            );
        _scheduleDashboardSync();
      }
    });
    _socket?.on('driver:location', (data) {
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
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

      final current = _findDriverById(
        ref.read(tripProvider).nearbyDrivers,
        driverId,
      );
      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        location,
        LatLng(lat, lng),
      );
      if (distanceMeters > 50000) {
        return;
      }

      ref
          .read(tripProvider.notifier)
          .upsertLiveDriver(
            NearbyDriver(
              driverId: driverId,
              lat: lat,
              lng: lng,
              distanceMeters: distanceMeters,
              rating: current?.rating ?? 5,
              etaMinutes:
                  current?.etaMinutes ??
                  (distanceMeters / 350).round().clamp(2, 60),
              vehicleType: current?.vehicleType ?? 'taxi',
              vehicleLabel: current?.vehicleLabel ?? 'RAPIGO',
              vehicleDetail: current?.vehicleDetail ?? 'Disponible',
              priceLabel:
                  current?.priceLabel ??
                  'Bs ${(8 + distanceMeters / 300).toStringAsFixed(0)}',
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
    if (!mounted) {
      return;
    }
    if (_destinationMoveMode || _flowState == RideFlowState.seleccionManual) {
      return;
    }
    if (_isSyncingDashboard) {
      return;
    }

    final session = ref.read(sessionProvider);
    final location =
        ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
    if (!mounted || !session.isAuthenticated || location == null) {
      return;
    }

    _isSyncingDashboard = true;
    try {
      await _persistLastKnownLocation(location);
      await ref
          .read(tripProvider.notifier)
          .loadDashboard(
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
    final unchanged =
        current != null &&
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
          _destinationMoveMode = false;
          if (_rideMode == RideMode.destino) {
            _flowState = RideFlowState.busquedaTexto;
          }
        });
        return;
      }
      setState(() {
        if (_rideMode == RideMode.destino) {
          _flowState = RideFlowState.busquedaTexto;
        }
      });
      return;
    }

    if (value.trim().toLowerCase() != selected.name.toLowerCase()) {
      setState(() {
        _selectedDestinationPlace = null;
        _destinationMoveMode = false;
        if (_rideMode == RideMode.destino) {
          _flowState = RideFlowState.busquedaTexto;
        }
      });
      return;
    }

    setState(() {
      if (_rideMode == RideMode.destino) {
        _flowState = RideFlowState.busquedaTexto;
      }
    });
  }

  void _selectDestinationPlace(PotosiPlace place) {
    _destinationController.value = TextEditingValue(
      text: place.name,
      selection: TextSelection.collapsed(offset: place.name.length),
    );
    setState(() {
      _selectedDestinationPlace = place;
      _customDestinationPoint = null;
      _destinationMoveMode = false;
      if (_rideMode == RideMode.destino) {
        _flowState = RideFlowState.rutaConfirmacion;
      }
    });
  }

  PotosiPlace? _resolveDestinationPlace() {
    return _selectedDestinationPlace ??
        PotosiPlaces.findExact(_destinationController.text.trim());
  }

  LatLng? _resolveDestinationPoint() {
    return _resolveDestinationPlace()?.point ?? _customDestinationPoint;
  }

  bool _canChooseDestinationForActiveTrip(TripRequest request) {
    return (request.activeTripId?.isNotEmpty ?? false) &&
        request.status == 'at_pickup';
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
        currentAddress == 'destino por confirmar' ||
        currentAddress == 'destino no esta marcado';
  }

  Future<void> _saveActiveTripDestination() async {
    final request = ref.read(tripProvider).request;
    final session = ref.read(sessionProvider);
    final destinationPoint = _resolveDestinationPoint();
    final destinationAddress = _destinationController.text.trim();
    if (!_canChooseDestinationForActiveTrip(request) ||
        request.activeTripId == null) {
      return;
    }
    if (destinationPoint == null) {
      _showMessage(
        'Marca o selecciona primero el destino final del viaje.',
        tone: NoticeTone.error,
      );
      return;
    }
    if (destinationAddress.isEmpty) {
      _showMessage(
        'Escribe o marca el destino para poder guardarlo.',
        tone: NoticeTone.error,
      );
      return;
    }
    await ref
        .read(tripProvider.notifier)
        .updateTripDestination(
          token: session.token,
          tripId: request.activeTripId!,
          destinationAddress: destinationAddress,
          destinationLocation: destinationPoint,
        );
    final error = ref.read(tripProvider).errorMessage;
    if (error != null) {
      _showMessage(
        error.replaceFirst('Exception: ', ''),
        tone: NoticeTone.error,
      );
      return;
    }
    _showFloatingNotification(
      'Destino guardado. Ya pueden iniciar el viaje con la ruta correcta.',
      tone: NoticeTone.success,
    );
    if (mounted) {
      setState(() {
        _destinationMoveMode = false;
      });
    }
  }

  void _selectDestinationFromMap(LatLng point) {
    if (!mounted) {
      return;
    }
    _destinationController.value = const TextEditingValue(
      text: _customDestinationLabel,
      selection: TextSelection.collapsed(
        offset: _customDestinationLabel.length,
      ),
    );
    setState(() {
      _selectedDestinationPlace = null;
      _customDestinationPoint = point;
      _mapFocusSignal++;
    });
    _showFloatingNotification(
      _destinationMoveMode
          ? 'Destino movido en tiempo real. Revisa el punto exacto y guardalo cuando este listo.'
          : 'Destino marcado en el mapa. Ese punto sera el final del viaje.',
      tone: NoticeTone.info,
    );
  }

  void _handleDestinationMapCenterChanged(LatLng center, bool hasGesture) {
    if (!_destinationMoveMode) {
      return;
    }
    if (_isDraggingDestinationMap != hasGesture && mounted) {
      setState(() {
        _isDraggingDestinationMap = hasGesture;
      });
    }
    _movingDestinationCenter = center;
    _destinationMoveDebounce?.cancel();
    if (hasGesture && _currentAddressText != 'Buscando ubicación...') {
      setState(() {
        _currentAddressText = 'Buscando ubicación...';
      });
    }
    _destinationMoveDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_resolveMovingDestinationAddress(center));
    });
  }

  Future<void> _resolveMovingDestinationAddress(LatLng point) async {
    final requestId = ++_destinationLookupRequestId;
    final cacheKey = _reverseGeocodeCacheKey(point);
    final cachedLabel = _reverseGeocodeCache[cacheKey];
    if (cachedLabel != null && cachedLabel.isNotEmpty) {
      if (!mounted ||
          !_destinationMoveMode ||
          requestId != _destinationLookupRequestId) {
        return;
      }
      setState(() {
        _currentAddressText = cachedLabel;
      });
      return;
    }
    try {
      final details = await ref
          .read(geocodingServiceProvider)
          .reverseLookup(point);
      if (!mounted ||
          !_destinationMoveMode ||
          requestId != _destinationLookupRequestId) {
        return;
      }
      final label = details.fullAddress.trim().isNotEmpty
          ? details.fullAddress
          : '${details.primary}${details.secondary.isNotEmpty ? ' · ${details.secondary}' : ''}';
      final resolvedLabel = label.isNotEmpty ? label : 'Potosí';
      _storeReverseGeocodeCache(cacheKey, resolvedLabel);
      setState(() {
        _currentAddressText = resolvedLabel;
      });
    } catch (_) {
      if (!mounted ||
          !_destinationMoveMode ||
          requestId != _destinationLookupRequestId) {
        return;
      }
      _storeReverseGeocodeCache(cacheKey, 'Potosí');
      setState(() {
        _currentAddressText = 'Potosí';
      });
    }
  }

  Future<void> _confirmMovingDestination() async {
    final point =
        _movingDestinationCenter ??
        _resolveDestinationPoint() ??
        ref.read(passengerLocationProvider).position ??
        _lastKnownLocation;
    if (point == null) {
      _showMessage(
        'No pudimos leer el punto del mapa. Intenta moverlo nuevamente.',
        tone: NoticeTone.error,
      );
      return;
    }
    final resolvedLabel = _currentAddressText.trim().isNotEmpty
        ? _currentAddressText.trim()
        : _customDestinationLabel;
    _destinationController.value = TextEditingValue(
      text: resolvedLabel,
      selection: TextSelection.collapsed(offset: resolvedLabel.length),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDestinationPlace = null;
      _customDestinationPoint = point;
      _destinationMoveMode = false;
      _isDraggingDestinationMap = false;
      _mapFocusSignal++;
      _flowState = RideFlowState.rutaConfirmacion;
    });
    if (_canChooseDestinationForActiveTrip(ref.read(tripProvider).request)) {
      await _saveActiveTripDestination();
    }
    _showFloatingNotification(
      'Destino confirmado. Ya puedes revisar la ruta y pedir el taxi.',
      tone: NoticeTone.success,
    );
    if (!_canChooseDestinationForActiveTrip(ref.read(tripProvider).request) &&
        _rideMode == RideMode.cercano) {
      await _reopenTakeTaxiPageAfterDestinationPick();
    }
  }

  Future<void> _cancelActiveTrip() async {
    final session = ref.read(sessionProvider);
    final request = ref.read(tripProvider).request;
    final tripId = request.activeTripId;
    if (!session.isAuthenticated || tripId == null || tripId.isEmpty) {
      return;
    }
    await ref
        .read(tripProvider.notifier)
        .updateTripStatus(
          token: session.token,
          tripId: tripId,
          status: 'cancelled',
        );
    final error = ref.read(tripProvider).errorMessage;
    if (error != null) {
      _showMessage(
        error.replaceFirst('Exception: ', ''),
        tone: NoticeTone.error,
      );
      return;
    }
    await _syncDashboard();
    _showFloatingNotification(
      'Viaje cancelado. Puedes volver a solicitar cuando quieras.',
      tone: NoticeTone.warning,
    );
  }

  Future<void> _retryRideRequest() async {
    await _requestRide();
  }

  void _editDestinationFromStatus() {
    if (_rideMode != RideMode.destino) {
      setState(() {
        _rideMode = RideMode.destino;
      });
    }
    setState(() {
      _flowState = RideFlowState.busquedaTexto;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _destinationFocusNode.requestFocus();
      }
    });
  }

  void _clearDestinationSelection() {
    _destinationController.clear();
    setState(() {
      _selectedDestinationPlace = null;
      _customDestinationPoint = null;
      _destinationMoveMode = false;
      _flowState = RideFlowState.busquedaTexto;
    });
  }

  void _toggleDestinationMoveMode() {
    final nextState = !_destinationMoveMode;
    final initialPoint =
        _customDestinationPoint ??
        _resolveDestinationPlace()?.point ??
        ref.read(passengerLocationProvider).position ??
        _lastKnownLocation;
    setState(() {
      _destinationMoveMode = nextState;
      if (nextState) {
        _isDraggingDestinationMap = false;
        _movingDestinationCenter = initialPoint;
        _currentAddressText = 'Buscando ubicación...';
        _flowState = RideFlowState.seleccionManual;
      } else {
        _isDraggingDestinationMap = false;
        if (_rideMode == RideMode.destino) {
          _flowState = _resolveDestinationPoint() != null
              ? RideFlowState.rutaConfirmacion
              : RideFlowState.busquedaTexto;
        } else if (_rideMode == RideMode.cercano) {
          _flowState = RideFlowState.rutaConfirmacion;
        }
      }
    });
    if (nextState && initialPoint != null) {
      unawaited(_resolveMovingDestinationAddress(initialPoint));
    } else if (!nextState && _rideMode == RideMode.cercano) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _destinationMoveMode || _rideMode != RideMode.cercano) {
          return;
        }
        unawaited(_reopenTakeTaxiPageAfterDestinationPick());
      });
    }
    _showFloatingNotification(
      _destinationMoveMode
          ? 'Desliza el mapa y fija el destino exacto con el pin central.'
          : 'Modo mover destino desactivado.',
      tone: NoticeTone.info,
    );
  }

  Future<void> _requestRide() async {
    final session = ref.read(sessionProvider);
    final locationState = ref.read(passengerLocationProvider);
    final location = locationState.position ?? _lastKnownLocation;
    final request = ref.read(tripProvider).request;
    final isRetryingRequest =
        (request.activeTripId?.isNotEmpty ?? false) &&
        const {'requested', 'searching'}.contains(request.status);
    if (const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(request.status) &&
        (request.activeTripId?.isNotEmpty ?? false)) {
      _showMessage(
        'Ya tienes un conductor asignado. Ahora solo puedes seguir ese viaje activo.',
        tone: NoticeTone.warning,
      );
      return;
    }
    final destination = _destinationController.text.trim();
    final resolvedDestinationPoint = _resolveDestinationPoint();
    final resolvedDestination =
        destination.isEmpty && resolvedDestinationPoint != null
        ? _customDestinationLabel
        : destination;
    final selectedDriverId = _rideMode == RideMode.cercano
        ? _selectedDriverId
        : null;
    final selectedDriver = _findDriverById(
      _requestableDrivers(ref.read(tripProvider).nearbyDrivers),
      selectedDriverId,
    );

    if (location == null) {
      _showMessage(
        locationState.errorMessage ?? 'Activa tu ubicacion para pedir un taxi.',
        tone: NoticeTone.error,
      );
      return;
    }

    if (resolvedDestination.isEmpty) {
      _showMessage(
        'Marca o escribe el destino para continuar.',
        tone: NoticeTone.error,
      );
      return;
    }

    if (resolvedDestinationPoint == null) {
      _showMessage(
        'Selecciona un lugar sugerido o marca tu destino tocando el mapa.',
        tone: NoticeTone.error,
      );
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

    await ref
        .read(tripProvider.notifier)
        .requestRide(
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
      _showMessage(
        error.replaceFirst('Exception: ', ''),
        tone: NoticeTone.error,
      );
      return;
    }

    if (mounted) {
      if (isRetryingRequest) {
        _showFloatingNotification(
          'Solicitud reenviada. Seguimos buscando un conductor para ti.',
          tone: NoticeTone.info,
        );
      } else {
        _showFloatingNotification(
          selectedDriver == null
              ? 'Solicitud enviada. Estamos buscando un conductor.'
              : 'Solicitud enviada a ${selectedDriver.vehicleLabel}. Esperando respuesta.',
          tone: NoticeTone.success,
        );
      }
    }
  }

  Future<void> _expandSheet(double target) async {
    if (!_sheetController.isAttached) {
      return;
    }
    await _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _activateNearbyMode() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _rideMode = RideMode.cercano;
      _flowState = RideFlowState.rutaConfirmacion;
      _topActionsExpanded = false;
      _homeDrawerExpanded = false;
    });
    unawaited(_expandSheet(0.58));
  }

  void _activateDestinationMode({bool focusSearch = false}) {
    if (!focusSearch) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _rideMode = RideMode.destino;
      _selectedDriverId = null;
      _selectedDestinationPlace = null;
      _customDestinationPoint = null;
      _flowState = RideFlowState.busquedaTexto;
      _topActionsExpanded = false;
      _homeDrawerExpanded = false;
    });
    if (focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _destinationFocusNode.requestFocus();
        }
      });
    }
  }

  void _applyInitialDestination(String label, LatLng point) {
    _destinationController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    setState(() {
      _rideMode = RideMode.destino;
      _selectedDriverId = null;
      _selectedDestinationPlace = null;
      _customDestinationPoint = point;
      _flowState = RideFlowState.rutaConfirmacion;
      _topActionsExpanded = false;
      _homeDrawerExpanded = false;
    });
    unawaited(_expandSheet(0.58));
  }

  void _applyNearbyDestination(String label, LatLng point) {
    _destinationController.value = TextEditingValue(
      text: label,
      selection: TextSelection.collapsed(offset: label.length),
    );
    setState(() {
      _rideMode = RideMode.cercano;
      _selectedDestinationPlace = null;
      _customDestinationPoint = point;
      _flowState = RideFlowState.rutaConfirmacion;
      _topActionsExpanded = false;
      _homeDrawerExpanded = false;
    });
    if (_canChooseDestinationForActiveTrip(ref.read(tripProvider).request)) {
      unawaited(_saveActiveTripDestination());
      return;
    }
    unawaited(_reopenTakeTaxiPageAfterDestinationPick());
  }

  Future<void> _reopenTakeTaxiPageAfterDestinationPick() async {
    if (!mounted || _destinationMoveMode || _rideMode != RideMode.cercano) {
      return;
    }
    final tripState = ref.read(tripProvider);
    if (tripState.request.activeTripId?.isNotEmpty ?? false) {
      return;
    }
    final userLocation =
        ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
    if (userLocation == null) {
      return;
    }
    _suspendTakeTaxiAutoOpen = false;
    final driverPoints = _requestableDrivers(tripState.nearbyDrivers)
        .map(
          (driver) => PotosiMapDriverMarker(
            point: LatLng(driver.lat, driver.lng),
            driverId: driver.driverId,
            vehicleType: driver.vehicleType,
            isHighlighted: driver.driverId == _selectedDriverId,
          ),
        )
        .toList(growable: false);
    await _openTakeTaxiPage(
      userLocation: userLocation,
      driverPoints: driverPoints,
    );
  }

  String _currentOriginLabel() {
    final position =
        ref.read(passengerLocationProvider).position ?? _lastKnownLocation;
    if (position == null) {
      return 'Potosí';
    }
    return 'Potosí · ubicación actual';
  }

  Future<void> _openDestinationSearchSheetFromMap() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final navigator = Navigator.of(sheetContext);
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: DestinationSearchSheet(
            originLabel: _currentOriginLabel(),
            autofocusSearch: false,
            onClose: () => navigator.pop(),
            onMapTap: () {
              navigator.pop();
              _activateDestinationMode();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_destinationMoveMode) {
                  _toggleDestinationMoveMode();
                }
              });
            },
            onSuggestionTap: (label, point) {
              navigator.pop();
              _applyInitialDestination(label, point);
            },
          ),
        );
      },
    );
  }

  Future<void> _openNearbyDestinationSearchSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _suspendTakeTaxiAutoOpen = true;
    bool destinationChanged = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final navigator = Navigator.of(sheetContext);
        return FractionallySizedBox(
          heightFactor: 0.96,
          child: DestinationSearchSheet(
            originLabel: _currentOriginLabel(),
            autofocusSearch: false,
            onClose: () => navigator.pop(),
            onMapTap: () {
              navigator.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_destinationMoveMode) {
                  _toggleDestinationMoveMode();
                }
              });
            },
            onSuggestionTap: (label, point) {
              destinationChanged = true;
              navigator.pop();
              _applyNearbyDestination(label, point);
            },
          ),
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (_suspendTakeTaxiAutoOpen &&
        !_destinationMoveMode &&
        _rideMode == RideMode.cercano) {
      _suspendTakeTaxiAutoOpen = false;
      await _reopenTakeTaxiPageAfterDestinationPick();
    }
  }

  Future<void> _reopenServiceLauncher() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _suspendTakeTaxiAutoOpen = false;
    if (widget.onBackToLauncher != null) {
      widget.onBackToLauncher!.call();
      return;
    }
    setState(() {
      _flowState = RideFlowState.reposo;
      _destinationMoveMode = false;
      _selectedDestinationPlace = null;
      _customDestinationPoint = null;
      _selectedDriverId = null;
      _topActionsExpanded = false;
      _homeDrawerExpanded = false;
    });
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showUpcomingOptionsSheet() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
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
                      color: const Color(0xFFD7DCE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Opciones',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estas acciones llegarán pronto a RAPIGO.',
                  style: TextStyle(
                    color: AppBrand.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List<Widget>.generate(3, (index) {
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 52) / 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE8ECF2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              index == 0
                                  ? Icons.alt_route_rounded
                                  : index == 1
                                  ? Icons.bookmark_border_rounded
                                  : Icons.tune_rounded,
                              color: AppBrand.textPrimary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Próximamente',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppBrand.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _returnToMainMapAfterTripEnd({
    String? noticeMessage,
    NoticeTone tone = NoticeTone.success,
  }) async {
    if (_isEndingTripFlow || !mounted) {
      return;
    }
    _isEndingTripFlow = true;
    try {
      if (noticeMessage != null && noticeMessage.trim().isNotEmpty) {
        _showFloatingNotification(noticeMessage, tone: tone);
        await Future<void>.delayed(const Duration(milliseconds: 950));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }

      if (_isRoutePreviewPageOpen) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          await navigator.maybePop(RoutePreviewAction.back);
          await Future<void>.delayed(const Duration(milliseconds: 160));
        }
      }

      if (!mounted) {
        return;
      }
      await _reopenServiceLauncher();
    } finally {
      _isEndingTripFlow = false;
    }
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
      return destination.isEmpty
          ? TripRepository.destinationPendingLabel
          : destination;
    }
    return destination.isEmpty
        ? TripRepository.destinationPendingLabel
        : destination;
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
                          label:
                              '${driver.distanceMeters.toStringAsFixed(0)} m',
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
                          _TripInfoRow(
                            label: 'Destino',
                            value: _rideDestinationPreview(),
                          ),
                          _TripInfoRow(
                            label: 'Tipo',
                            value: driver.vehicleType,
                          ),
                          _TripInfoRow(
                            label: 'Detalle',
                            value: driver.vehicleDetail,
                          ),
                          _TripInfoRow(
                            label: 'Llegada',
                            value: '${driver.etaMinutes} min',
                          ),
                          _TripInfoRow(
                            label: 'Distancia',
                            value:
                                '${driver.distanceMeters.toStringAsFixed(0)} m',
                          ),
                          _TripInfoRow(
                            label: 'Calificacion',
                            value: driver.rating.toStringAsFixed(1),
                          ),
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
                            child: Text(
                              isSelected ? 'Seleccionado' : 'Elegir este',
                            ),
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

  void _showMessage(String message, {NoticeTone tone = NoticeTone.warning}) {
    showTopNotice(context, message, tone: tone);
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatusBanner(
                      message: _tripStatusHeadline(request.status),
                      color: const Color(0xFFFFE6D5),
                      textColor: const Color(0xFFC2410C),
                      icon: Icons.timeline_rounded,
                    ),
                    if (request.isPromotional &&
                        request.status == 'in_progress') ...[
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
                    if (request.isPromotional &&
                        request.status == 'in_progress') ...[
                      const _TripInfoRow(
                        label: 'Promo',
                        value: 'Este viaje no se cobra al pasajero',
                      ),
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
                      value: request.etaMinutes == null
                          ? 'Calculando...'
                          : '${request.etaMinutes} min',
                    ),
                    _TripInfoRow(
                      label: 'Ubicacion taxi',
                      value:
                          request.driverLat == null || request.driverLng == null
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
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFF86EFAC),
                          ),
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
                          _TripInfoRow(
                            label: 'Destino',
                            value: request.destinationAddress,
                          ),
                          _TripInfoRow(
                            label: 'Conductor',
                            value: request.driverName?.isNotEmpty == true
                                ? request.driverName!
                                : 'Pendiente',
                          ),
                          _TripInfoRow(
                            label: 'Vehiculo',
                            value: request.vehicleLabel?.isNotEmpty == true
                                ? request.vehicleLabel!
                                : 'Pendiente',
                          ),
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
                        'AVISO RAPIGO - VIAJE PREMIADO\n\nTu viaje gratis por promocion es valido solo para ti como cliente registrado en la app RAPIGO.\n\nNota importante: El beneficio cubre solamente a una (1) persona. Si viajas con acompañantes, el conductor podra realizar el cobro normal correspondiente por ellos. Gracias por usar RAPIGO y disfrutar tu premio.',
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

  void _showFloatingNotification(
    String message, {
    NoticeTone tone = NoticeTone.info,
  }) {
    _notificationTimer?.cancel();
    setState(() {
      _floatingNotification = message;
      _floatingNotificationTone = tone;
    });
    LocalNotifications.show(
      id: message.hashCode,
      title: 'RAPIGO',
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
      _showFloatingNotification(
        message,
        tone: switch (request.status) {
          'accepted' => NoticeTone.info,
          'arriving' => NoticeTone.info,
          'at_pickup' => NoticeTone.success,
          'in_progress' => NoticeTone.info,
          'completed' => NoticeTone.success,
          'cancelled' => NoticeTone.warning,
          _ => NoticeTone.info,
        },
      );
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

    if (request.status == 'cancelled') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _returnToMainMapAfterTripEnd(
            noticeMessage: 'Puedes volver a solicitar un taxi cuando quieras.',
            tone: NoticeTone.warning,
          ),
        );
      });
    }

    if (request.status == 'completed' &&
        request.activeTripId != null &&
        _ratingPromptedTripId != request.activeTripId) {
      _ratingPromptedTripId = request.activeTripId;
      _runAfterBuild(() => _showPassengerRatingDialog(request.activeTripId!));
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
                            onPressed: () =>
                                setDialogState(() => selectedScore = value),
                            icon: Icon(
                              value <= selectedScore
                                  ? Icons.star
                                  : Icons.star_border,
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
        await ref
            .read(tripProvider.notifier)
            .submitRating(
              token: ref.read(sessionProvider).token,
              tripId: tripId,
              score: selectedScore,
              comment: commentController.text,
            );
        await _syncDashboard();
      }
    } finally {
      commentController.dispose();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          unawaited(
            _returnToMainMapAfterTripEnd(
              noticeMessage: 'Gracias por utilizar RAPIGO',
              tone: NoticeTone.success,
            ),
          );
        });
      }
    }
  }

  Widget _buildTripActions(TripState tripState) {
    final activeTripId = tripState.request.activeTripId;
    if (activeTripId == null || activeTripId.isEmpty) {
      return const SizedBox.shrink();
    }

    final request = tripState.request;
    final status = request.status;
    final hasOptions =
        !const {'completed', 'cancelled'}.contains(status) ||
        (request.driverPhone != null &&
            request.driverPhone!.trim().isNotEmpty &&
            const {
              'accepted',
              'arriving',
              'at_pickup',
              'in_progress',
            }.contains(status));

    if (!hasOptions) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  List<NearbyDriver> _requestableDrivers(List<NearbyDriver> drivers) {
    return drivers
        .where(
          (driver) =>
              driver.distanceMeters <= 1000 &&
              _matchesSelectedServiceType(driver.vehicleType),
        )
        .toList(growable: false);
  }

  bool _matchesSelectedServiceType(String? vehicleType) {
    final normalized = (vehicleType ?? 'taxi').trim().toLowerCase();
    if (_selectedServiceType == 'moto') {
      return normalized == 'moto';
    }
    return normalized != 'moto';
  }

  void _selectServiceType(String type) {
    if (_selectedServiceType == type) {
      return;
    }
    setState(() {
      _selectedServiceType = type;
      _selectedDriverId = null;
    });
  }

  Future<void> _openRoutePreviewPage({
    required LatLng userLocation,
    required List<PotosiMapDriverMarker> driverPoints,
    required _RoutePreviewData routePreview,
    required String destinationLabel,
  }) async {
    if (_isRoutePreviewPageOpen || !mounted) {
      return;
    }
    _isRoutePreviewPageOpen = true;
    final result = await Navigator.of(context).push<RoutePreviewAction>(
      MaterialPageRoute(
        builder: (context) => RoutePreviewPage(
          drivers: driverPoints,
          nearbyDrivers: _requestableDrivers(
            ref.read(tripProvider).nearbyDrivers,
          ),
          userLocation: userLocation,
          userAccuracyMeters: ref
              .read(passengerLocationProvider)
              .accuracyMeters,
          userHeadingDegrees: ref
              .read(passengerLocationProvider)
              .headingDegrees,
          routeTarget: _resolveDestinationPoint(),
          routeColor: const Color(0xFFF97316),
          focusSignal: _mapFocusSignal,
          serviceType: _selectedServiceType,
          originLabel: 'Potosí · ubicación actual',
          destinationLabel: destinationLabel,
          distanceMeters: routePreview.distanceMeters,
          selectedDriverId: _selectedDriverId,
          onSelectDriver: _selectDriver,
          onSelectTaxi: () => _selectServiceType('taxi'),
          onSelectMoto: () => _selectServiceType('moto'),
          onRequest: _requestRide,
          onRetry: _retryRideRequest,
          onCancel: _cancelActiveTrip,
        ),
      ),
    );
    _isRoutePreviewPageOpen = false;
    if (!mounted) {
      return;
    }
    switch (result) {
      case RoutePreviewAction.journey:
        return;
      case RoutePreviewAction.edit:
        _editDestinationFromStatus();
        return;
      case RoutePreviewAction.clear:
        _clearDestinationSelection();
        return;
      case RoutePreviewAction.back:
      case null:
        final finalStatus = ref.read(tripProvider).request.status;
        if (_journeyStartedFromTakeTaxi && finalStatus == 'cancelled') {
          setState(() {
            _journeyStartedFromTakeTaxi = false;
            _rideMode = RideMode.cercano;
            _flowState = _resolveDestinationPoint() != null
                ? RideFlowState.rutaConfirmacion
                : RideFlowState.busquedaTexto;
          });
          return;
        }
        if (_journeyStartedFromTakeTaxi && finalStatus == 'completed') {
          _journeyStartedFromTakeTaxi = false;
          await _reopenServiceLauncher();
          return;
        }
        if (_isEndingTripFlow ||
            const {'completed', 'cancelled'}.contains(finalStatus)) {
          return;
        }
        _journeyStartedFromTakeTaxi = false;
        setState(() {
          _flowState = RideFlowState.busquedaTexto;
        });
        return;
    }
  }

  Future<void> _openTakeTaxiPage({
    required LatLng userLocation,
    required List<PotosiMapDriverMarker> driverPoints,
  }) async {
    if (_isTakeTaxiPageOpen || !mounted) {
      return;
    }
    _suspendTakeTaxiAutoOpen = false;
    _isTakeTaxiPageOpen = true;
    final destinationLabel = _destinationController.text.trim().isEmpty
        ? (ref.read(tripProvider).request.destinationAddress.trim().isEmpty
              ? TripRepository.destinationPendingLabel
              : ref.read(tripProvider).request.destinationAddress.trim())
        : _destinationController.text.trim();
    final result = await Navigator.of(context).push<TakeTaxiPageAction>(
      MaterialPageRoute(
        builder: (context) => TakeTaxiPage(
          drivers: driverPoints,
          nearbyDrivers: _requestableDrivers(
            ref.read(tripProvider).nearbyDrivers,
          ),
          userLocation: userLocation,
          userAccuracyMeters: ref
              .read(passengerLocationProvider)
              .accuracyMeters,
          userHeadingDegrees: ref
              .read(passengerLocationProvider)
              .headingDegrees,
          routeTarget: _resolveDestinationPoint(),
          routeColor: const Color(0xFFF97316),
          focusSignal: _mapFocusSignal,
          serviceType: _selectedServiceType,
          originLabel: 'Potosí',
          destinationLabel: destinationLabel,
          distanceMeters:
              _routePreviewData(
                userLocation,
                _resolveDestinationPoint(),
              )?.distanceMeters ??
              350,
          selectedDriverId: _selectedDriverId,
          onSelectDriver: _selectDriver,
          onSelectTaxi: () => _selectServiceType('taxi'),
          onSelectMoto: () => _selectServiceType('moto'),
          onRequest: _requestRide,
          onRetry: _retryRideRequest,
          onCancel: _cancelActiveTrip,
        ),
      ),
    );
    _isTakeTaxiPageOpen = false;
    if (!mounted) {
      return;
    }
    switch (result) {
      case TakeTaxiPageAction.journey:
        setState(() {
          _journeyStartedFromTakeTaxi = true;
          _rideMode = RideMode.destino;
        });
        final resolvedDestinationPoint = _resolveDestinationPoint();
        final routePreview = _routePreviewData(
          userLocation,
          resolvedDestinationPoint,
        );
        if (routePreview != null) {
          await _openRoutePreviewPage(
            userLocation: userLocation,
            driverPoints: driverPoints,
            routePreview: routePreview,
            destinationLabel: _destinationController.text.trim().isEmpty
                ? _currentAddressText
                : _destinationController.text.trim(),
          );
        }
        return;
      case TakeTaxiPageAction.edit:
        await _openNearbyDestinationSearchSheet();
        return;
      case TakeTaxiPageAction.clear:
        _clearDestinationSelection();
        return;
      case TakeTaxiPageAction.back:
      case null:
        _journeyStartedFromTakeTaxi = false;
        await _reopenServiceLauncher();
        return;
    }
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
    if (isRideInProgress &&
        activeDriverPoint != null &&
        activeDestinationPoint != null) {
      return LatLngBounds.fromPoints([
        activeDriverPoint,
        activeDestinationPoint,
      ]);
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
      return tripState.request.status == 'requested'
          ? 'Buscando conductor...'
          : 'Enviando a taxis cercanos...';
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
        }.contains(tripState.request.status)) {
      return switch (tripState.request.status) {
        'accepted' => 'Taxi asignado · Cancelar',
        'arriving' => 'Taxi en camino · Cancelar',
        'at_pickup' => 'Taxi llegó · Cancelar',
        _ => 'Gestionar viaje',
      };
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        tripState.request.status == 'in_progress') {
      return 'Viaje en curso';
    }
    if (_rideMode == RideMode.cercano) {
      return _selectedDriverId == null
          ? 'Elegir taxi mas cercano'
          : 'Solicitar este taxi';
    }
    return 'Solicitar taxi';
  }

  IconData _primaryActionIcon(TripState tripState) {
    if (tripState.isRequestingTrip) {
      return Icons.hourglass_top_rounded;
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        const {'requested', 'searching'}.contains(tripState.request.status)) {
      return Icons.search_rounded;
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        const {'accepted', 'arriving'}.contains(tripState.request.status)) {
      return Icons.close_rounded;
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        tripState.request.status == 'at_pickup') {
      return Icons.location_on_rounded;
    }
    if ((tripState.request.activeTripId?.isNotEmpty ?? false) &&
        tripState.request.status == 'in_progress') {
      return Icons.navigation_rounded;
    }
    if (_rideMode == RideMode.cercano) {
      return _selectedDriverId == null
          ? Icons.near_me_rounded
          : Icons.local_taxi_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  VoidCallback? _primaryActionHandler(TripState tripState) {
    if (tripState.isRequestingTrip) {
      return null;
    }
    final hasActiveTrip = tripState.request.activeTripId?.isNotEmpty ?? false;
    final status = tripState.request.status;
    if (hasActiveTrip &&
        const {'requested', 'searching', 'in_progress'}.contains(status)) {
      return null;
    }
    if (hasActiveTrip &&
        const {'accepted', 'arriving', 'at_pickup'}.contains(status)) {
      return _cancelActiveTrip;
    }
    if (_rideMode == RideMode.cercano) {
      return _selectedDriverId == null ? _selectNearestTaxi : _requestRide;
    }
    return _requestRide;
  }

  String _compactStatusText(TripState tripState) {
    if ((tripState.request.activeTripId?.isNotEmpty ?? false)) {
      return switch (tripState.request.status) {
        'requested' || 'searching' => 'Buscando conductor',
        'accepted' => 'Conductor asignado',
        'arriving' => 'Conductor en camino',
        'at_pickup' => 'Conductor llegó',
        'in_progress' => 'Viaje en curso',
        'completed' => 'Viaje completado',
        'cancelled' => 'Viaje cancelado',
        _ => 'Estado del viaje',
      };
    }
    if (_rideMode == RideMode.destino && _resolveDestinationPoint() != null) {
      return 'Destino listo · Solicitar taxi';
    }
    return _rideMode == RideMode.destino
        ? 'Elige destino para solicitar taxi'
        : 'Tomar taxi cercano';
  }

  Color _compactStatusColor(TripState tripState) {
    if ((tripState.request.activeTripId?.isNotEmpty ?? false)) {
      return switch (tripState.request.status) {
        'requested' || 'searching' => const Color(0xFF1D4ED8),
        'accepted' || 'arriving' => const Color(0xFFF97316),
        'at_pickup' => const Color(0xFF0EA5E9),
        'in_progress' => const Color(0xFF16A34A),
        'completed' => const Color(0xFF16A34A),
        'cancelled' => const Color(0xFFDC2626),
        _ => AppBrand.primaryBlue,
      };
    }
    if (_rideMode == RideMode.destino && _resolveDestinationPoint() != null) {
      return AppBrand.primaryBlue;
    }
    return _rideMode == RideMode.destino
        ? const Color(0xFF64748B)
        : AppBrand.accentYellow;
  }

  List<String> _compactStatusDetails(TripState tripState, LatLng userLocation) {
    final request = tripState.request;
    final items = <String>[];

    final destinationText =
        request.destinationAddress.trim().isNotEmpty &&
            request.destinationAddress.trim() !=
                TripRepository.destinationPendingLabel
        ? request.destinationAddress.trim()
        : _destinationController.text.trim();
    if (destinationText.isNotEmpty) {
      items.add(_shortDestinationLabel(destinationText));
    }

    final destinationPoint = _resolveDestinationPoint();
    if ((request.activeTripId?.isNotEmpty ?? false) &&
        request.etaMinutes != null) {
      items.add('${request.etaMinutes} min');
    } else if (destinationPoint != null) {
      final distanceMeters = const Distance().as(
        LengthUnit.Meter,
        userLocation,
        destinationPoint,
      );
      final durationMinutes = ((distanceMeters / 5.5) / 60).round().clamp(
        3,
        90,
      );
      final fareAmount = ((distanceMeters / 700).ceil() * 3).clamp(10, 120);
      items.add('$durationMinutes min');
      items.add('Bs $fareAmount');
    }

    if ((request.driverName ?? '').trim().isNotEmpty &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(request.status)) {
      items.add(request.driverName!.trim());
    }

    return items.take(3).toList(growable: false);
  }

  String _shortDestinationLabel(String value) {
    final normalized = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return value;
    }
    return normalized.first;
  }

  _RoutePreviewData? _routePreviewData(LatLng? origin, LatLng? destination) {
    if (origin == null || destination == null) {
      return null;
    }
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      origin,
      destination,
    );
    final distanceKm = distanceMeters / 1000;
    final metersPerSecond = _selectedServiceType == 'moto' ? 6.5 : 5.5;
    final durationMinutes = ((distanceMeters / metersPerSecond) / 60)
        .round()
        .clamp(3, 90);
    final fareDivisor = _selectedServiceType == 'moto' ? 900 : 700;
    final fareMultiplier = _selectedServiceType == 'moto' ? 2 : 3;
    final fareAmount = ((distanceMeters / fareDivisor).ceil() * fareMultiplier)
        .clamp(8, 120);
    return _RoutePreviewData(
      distanceMeters: distanceMeters,
      distanceLabel: distanceKm < 1
          ? '${distanceMeters.round()} m'
          : '${distanceKm.toStringAsFixed(1)} km',
      durationLabel: '$durationMinutes min',
      fareLabel: 'Bs $fareAmount',
      serviceLabel: _selectedServiceType == 'moto' ? 'Moto' : 'Taxi',
    );
  }

  List<_CompactStatusActionData> _compactStatusActions(TripState tripState) {
    final request = tripState.request;
    final hasTrip = request.activeTripId?.isNotEmpty ?? false;
    if (!hasTrip) {
      if (_rideMode == RideMode.destino && _resolveDestinationPoint() != null) {
        return [
          _CompactStatusActionData(
            label: 'Solicitar taxi',
            onTap: tripState.isRequestingTrip ? null : _requestRide,
            primary: true,
          ),
          _CompactStatusActionData(
            label: 'Editar lugar',
            onTap: _editDestinationFromStatus,
          ),
        ];
      }
      if (_rideMode == RideMode.destino) {
        return [
          _CompactStatusActionData(
            label: 'Editar lugar',
            onTap: _editDestinationFromStatus,
          ),
        ];
      }
      return [
        _CompactStatusActionData(
          label: _selectedDriverId == null
              ? 'Elegir cercano'
              : 'Solicitar taxi',
          onTap: tripState.isRequestingTrip
              ? null
              : (_selectedDriverId == null ? _selectNearestTaxi : _requestRide),
          primary: true,
        ),
      ];
    }

    return switch (request.status) {
      'requested' || 'searching' => [
        _CompactStatusActionData(
          label: 'Volver a solicitar',
          onTap: tripState.isRequestingTrip ? null : _retryRideRequest,
          primary: true,
        ),
        _CompactStatusActionData(label: 'Cancelar', onTap: _cancelActiveTrip),
        if (_rideMode == RideMode.destino)
          _CompactStatusActionData(
            label: 'Editar lugar',
            onTap: _editDestinationFromStatus,
          ),
      ],
      'accepted' || 'arriving' || 'at_pickup' => [
        _CompactStatusActionData(label: 'Cancelar', onTap: _cancelActiveTrip),
        _CompactStatusActionData(
          label: 'Editar lugar',
          onTap: _editDestinationFromStatus,
        ),
      ],
      'cancelled' => [
        _CompactStatusActionData(
          label: 'Volver a solicitar',
          onTap: tripState.isRequestingTrip ? null : _retryRideRequest,
          primary: true,
        ),
        _CompactStatusActionData(
          label: 'Editar lugar',
          onTap: _editDestinationFromStatus,
        ),
      ],
      _ => const <_CompactStatusActionData>[],
    };
  }

  String _journeyNavigationBadgeLabel(TripState tripState, String fallback) {
    final request = tripState.request;
    if (request.etaMinutes != null &&
        const {'accepted', 'arriving', 'at_pickup'}.contains(request.status)) {
      return '${request.etaMinutes} min';
    }
    return fallback;
  }

  String _journeyNavigationBadgeCaption(TripState tripState) {
    final status = tripState.request.status;
    return switch (status) {
      'requested' || 'searching' => 'Solicitud',
      'accepted' || 'arriving' || 'at_pickup' => 'Recogida',
      'in_progress' => 'Destino',
      'completed' => 'Completado',
      'cancelled' => 'Cancelado',
      _ => _rideMode == RideMode.destino ? 'Destino' : 'Recogida',
    };
  }

  IconData _journeyNavigationBadgeIcon(TripState tripState) {
    final status = tripState.request.status;
    return switch (status) {
      'requested' || 'searching' => Icons.search_rounded,
      'accepted' || 'arriving' || 'at_pickup' => Icons.near_me_rounded,
      'in_progress' => Icons.outlined_flag_rounded,
      'completed' => Icons.check_circle_rounded,
      'cancelled' => Icons.close_rounded,
      _ =>
        _rideMode == RideMode.destino
            ? Icons.outlined_flag_rounded
            : Icons.near_me_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(passengerLocationProvider);
    final tripState = ref.watch(tripProvider);
    final uiStateSignature = <String>[
      _rideMode.name,
      _flowState.name,
      _destinationMoveMode ? '1' : '0',
      _destinationController.text.trim(),
      _customDestinationPoint?.latitude.toStringAsFixed(6) ?? '',
      _customDestinationPoint?.longitude.toStringAsFixed(6) ?? '',
      _selectedDriverId ?? '',
      _selectedServiceType,
      _journeyDetailsExpanded ? '1' : '0',
    ].join('|');
    if (_lastUiStateSignature != uiStateSignature) {
      _lastUiStateSignature = uiStateSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_persistRideUiState());
        }
      });
    }
    final activeTripId = tripState.request.activeTripId;
    if (activeTripId != null &&
        activeTripId.isNotEmpty &&
        _socket?.connected == true) {
      _joinTripRoom(activeTripId);
    }
    final userLocation =
        locationState.position ??
        _lastKnownLocation ??
        const LatLng(-19.5836, -65.7531);
    final hasActiveTrip = activeTripId != null && activeTripId.isNotEmpty;
    final rideLocked =
        hasActiveTrip &&
        const {
          'accepted',
          'arriving',
          'at_pickup',
          'in_progress',
        }.contains(tripState.request.status);
    final activeDriverPoint =
        tripState.request.driverLat != null &&
            tripState.request.driverLng != null
        ? LatLng(tripState.request.driverLat!, tripState.request.driverLng!)
        : null;
    final selectedDestinationPoint = _resolveDestinationPoint();
    final activeDestinationPoint =
        tripState.request.destinationLat != null &&
            tripState.request.destinationLng != null
        ? LatLng(
            tripState.request.destinationLat!,
            tripState.request.destinationLng!,
          )
        : selectedDestinationPoint;
    final activeStatus = tripState.request.status;
    final canChooseActiveTripDestination = _canChooseDestinationForActiveTrip(
      tripState.request,
    );
    final activeTripNeedsDestination = _activeTripNeedsDestination(
      tripState.request,
    );
    final canEditDestinationOnMap =
        ((!rideLocked && _rideMode == RideMode.destino) ||
            canChooseActiveTripDestination) &&
        (_resolveDestinationPoint() == null || _destinationMoveMode);
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
    final mapRouteStart = hasActiveTrip && isRideInProgress
        ? activeDriverPoint
        : null;
    final mapRouteTarget = hasActiveTrip
        ? (isRideInProgress ? activeDestinationPoint : activeDriverPoint)
        : selectedDestinationPoint;
    final editingDestination = _destinationMoveMode;
    final shouldDrawPreviewRoute = hasActiveTrip
        ? (isRideInProgress
              ? (mapRouteStart != null && mapRouteTarget != null)
              : (activeStatus == 'at_pickup'
                    ? activeDestinationPoint != null &&
                          activeDriverPoint != null
                    : activeDriverPoint != null))
        : _rideMode == RideMode.destino && selectedDestinationPoint != null;
    final displayNearbyDrivers = _requestableDrivers(tripState.nearbyDrivers);
    final activeDriverKey = activeDriverPoint == null
        ? null
        : '${activeDriverPoint.latitude.toStringAsFixed(6)}:${activeDriverPoint.longitude.toStringAsFixed(6)}';
    final highlightedNearbyDriverId = hasActiveTrip
        ? null
        : (_selectedDriverId ??
              (displayNearbyDrivers.isNotEmpty
                  ? displayNearbyDrivers.first.driverId
                  : null));
    final allDriverPoints = tripState.nearbyDrivers
        .map(
          (driver) => PotosiMapDriverMarker(
            point: LatLng(driver.lat, driver.lng),
            driverId: driver.driverId,
            vehicleType: driver.vehicleType,
            isHighlighted: driver.driverId == highlightedNearbyDriverId,
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
            isHighlighted: true,
          ),
        );
      }
    }
    final driverPoints = allDriverPoints;
    final routePreview = _routePreviewData(
      userLocation,
      selectedDestinationPoint,
    );
    final routeSummaryLabel = routePreview == null
        ? null
        : '${routePreview.durationLabel} · ${routePreview.distanceLabel}';
    final useInlineHomeFlow = widget.onBackToLauncher == null;
    final isIdleScene =
        useInlineHomeFlow &&
        _rideMode == RideMode.destino &&
        _flowState == RideFlowState.reposo &&
        !rideLocked &&
        !hasActiveTrip;
    final isSearchScene =
        useInlineHomeFlow &&
        _rideMode == RideMode.destino &&
        _flowState == RideFlowState.busquedaTexto &&
        !rideLocked &&
        !hasActiveTrip;
    final showLandingOverlay = isIdleScene;
    final showRouteReviewView =
        _rideMode == RideMode.destino &&
        !showLandingOverlay &&
        !_destinationMoveMode &&
        !isSearchScene &&
        !activeTripNeedsDestination &&
        !hasActiveTrip &&
        routePreview != null;
    final showActiveTripJourneyView =
        _rideMode == RideMode.destino &&
        !showLandingOverlay &&
        !_destinationMoveMode &&
        !isSearchScene &&
        !activeTripNeedsDestination &&
        hasActiveTrip;
    final showTakeTaxiView =
        _rideMode == RideMode.cercano &&
        !_destinationMoveMode &&
        !_suspendTakeTaxiAutoOpen &&
        !showLandingOverlay &&
        !isSearchScene;
    final showMainMapDrawer =
        _rideMode == RideMode.destino &&
        !showLandingOverlay &&
        !_destinationMoveMode &&
        !isSearchScene &&
        !showRouteReviewView &&
        !showActiveTripJourneyView &&
        !hasActiveTrip;
    final showPremiumDestinationEntry =
        showMainMapDrawer && widget.onBackToLauncher != null;

    if (showRouteReviewView && !_isRoutePreviewPageOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _openRoutePreviewPage(
            userLocation: userLocation,
            driverPoints: driverPoints,
            routePreview: routePreview,
            destinationLabel: _destinationController.text.trim().isEmpty
                ? _currentAddressText
                : _destinationController.text.trim(),
          ),
        );
      });
    }
    if (showTakeTaxiView && !_isTakeTaxiPageOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _openTakeTaxiPage(
            userLocation: userLocation,
            driverPoints: driverPoints,
          ),
        );
      });
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: PotosiMapSurface(
              viewportCacheKey: _mainMapViewportKey(hasActiveTrip: hasActiveTrip),
              drivers: driverPoints,
              userLocation: userLocation,
              userAccuracyMeters: locationState.accuracyMeters,
              userHeadingDegrees: locationState.headingDegrees,
              routeStart: mapRouteStart,
              routeTarget: mapRouteTarget,
              secondaryMarker: hasActiveTrip && !isRideInProgress
                  ? activeDestinationPoint
                  : null,
              showRoute: shouldDrawPreviewRoute,
              showTargetMarker: mapRouteTarget != null && !_destinationMoveMode,
              routeColor: mapRouteColor,
              focusBounds: focusBounds,
              focusPadding: isRideInProgress
                  ? const EdgeInsets.fromLTRB(38, 92, 38, 180)
                  : const EdgeInsets.fromLTRB(56, 120, 56, 220),
              focusSignal: _mapFocusSignal,
              cameraCenterTarget: _destinationMoveMode
                  ? _movingDestinationCenter
                  : null,
              cameraCenterSignal: _mapCenterSignal,
              showTargetEditBadge: editingDestination,
              showUtilityControls: false,
              showLiveNavigationMode: isRideInProgress,
              onRouteUpdated: () {
                if (!mounted) {
                  return;
                }
                _showFloatingNotification(
                  'Ruta actualizada. Seguimos el mejor camino hacia tu destino.',
                  tone: NoticeTone.info,
                );
              },
              onMapCenterChanged: _destinationMoveMode
                  ? _handleDestinationMapCenterChanged
                  : null,
              onMapTap: canEditDestinationOnMap && !_destinationMoveMode
                  ? _selectDestinationFromMap
                  : null,
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
                    const Color(0xFF9FC5F2).withValues(alpha: 0.34),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF0B2C4D).withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.18, 0.72, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Stack(
                children: [
                  if (_floatingNotification != null)
                    Positioned(
                      top: 88,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _floatingNotificationTone == NoticeTone.success
                              ? const Color(0xFFE8FFF1)
                              : _floatingNotificationTone == NoticeTone.error
                              ? const Color(0xFFFFEFF1)
                              : _floatingNotificationTone ==
                                    NoticeTone.warning
                              ? const Color(0xFFFFF3E6)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color:
                                _floatingNotificationTone ==
                                    NoticeTone.success
                                ? const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.24)
                                : _floatingNotificationTone ==
                                      NoticeTone.error
                                ? const Color(
                                    0xFFF87171,
                                  ).withValues(alpha: 0.26)
                                : _floatingNotificationTone ==
                                      NoticeTone.warning
                                ? const Color(
                                    0xFFF97316,
                                  ).withValues(alpha: 0.24)
                                : const Color(
                                    0xFF60A5FA,
                                  ).withValues(alpha: 0.24),
                          ),
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
                            Icon(
                              _floatingNotificationTone == NoticeTone.success
                                  ? Icons.check_circle_outline_rounded
                                  : _floatingNotificationTone ==
                                        NoticeTone.error
                                  ? Icons.error_outline_rounded
                                  : _floatingNotificationTone ==
                                        NoticeTone.warning
                                  ? Icons.notifications_active_rounded
                                  : Icons.info_outline_rounded,
                              color:
                                  _floatingNotificationTone ==
                                      NoticeTone.success
                                  ? const Color(0xFF86EFAC)
                                  : _floatingNotificationTone ==
                                        NoticeTone.error
                                  ? const Color(0xFFFCA5A5)
                                  : _floatingNotificationTone ==
                                        NoticeTone.warning
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFF93C5FD),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _floatingNotification!,
                                style: TextStyle(
                                  color:
                                      _floatingNotificationTone ==
                                          NoticeTone.success
                                      ? const Color(0xFF14532D)
                                      : _floatingNotificationTone ==
                                            NoticeTone.error
                                      ? const Color(0xFF991B1B)
                                      : _floatingNotificationTone ==
                                            NoticeTone.warning
                                      ? const Color(0xFF9A3412)
                                      : const Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (showLandingOverlay)
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: LargeNavigatorHeader(
                        locationLabel: 'Potosí',
                        trailing: _GlassIconButton(
                          icon: Icons.person_rounded,
                          onTap: widget.onMenuTap,
                          backgroundColor: Colors.white.withValues(alpha: 0.98),
                          iconColor: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  if (showLandingOverlay)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 208,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _LandingIntroCard(),
                          const SizedBox(height: 14),
                          _LandingModeCard(
                            title: 'Pedir Taxi',
                            subtitle:
                                'Elige tu destino y solicita un conductor disponible.',
                            icon: Icons.local_taxi_rounded,
                            accent: AppBrand.primaryBlue,
                            onTap: _activateDestinationMode,
                          ),
                          const SizedBox(height: 12),
                          _LandingModeCard(
                            title: 'Tomar Taxi',
                            subtitle:
                                'Busca autos cercanos y toma el más conveniente para ti.',
                            icon: Icons.navigation_rounded,
                            accent: AppBrand.accentYellow,
                            onTap: _activateNearbyMode,
                          ),
                        ],
                      ),
                    ),
                  if (showLandingOverlay)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MapHomeDrawer(
                        query: _destinationController.text.trim(),
                        onTapSearch: _openDestinationSearchSheetFromMap,
                        expanded: _homeDrawerExpanded,
                        onToggleExpanded: () {
                          setState(() {
                            _homeDrawerExpanded = !_homeDrawerExpanded;
                          });
                        },
                        onTapSettings: _showUpcomingOptionsSheet,
                      ),
                    ),
                  if (showMainMapDrawer)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MapHomeDrawer(
                        query: _destinationController.text.trim(),
                        onTapSearch: _openDestinationSearchSheetFromMap,
                        expanded: _homeDrawerExpanded,
                        onToggleExpanded: () {
                          setState(() {
                            _homeDrawerExpanded = !_homeDrawerExpanded;
                          });
                        },
                        onTapSettings: _showUpcomingOptionsSheet,
                        premiumStyle: showPremiumDestinationEntry,
                        forceExpanded: showPremiumDestinationEntry,
                        showMoreButton: !showPremiumDestinationEntry,
                        primaryActionLabel: 'ir',
                        onPrimaryAction: _openDestinationSearchSheetFromMap,
                      ),
                    ),
                  if (showPremiumDestinationEntry)
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: _PremiumRequestTaxiTopBar(
                        onBack: _reopenServiceLauncher,
                        expanded: _topActionsExpanded,
                        hasActiveTrip: hasActiveTrip,
                        onToggleExpanded: () {
                          setState(() {
                            _topActionsExpanded = !_topActionsExpanded;
                          });
                        },
                        onOffline: () async {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          await showOfflineMapSheet(context);
                        },
                        onDetails: () {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          showMapNavigationSheet(
                            context,
                            currentLabel: 'Potosí',
                            currentDetail: 'Ubicación actual',
                            targetLabel: mapRouteTarget != null
                                ? (_destinationController.text.trim().isEmpty
                                      ? _currentAddressText
                                      : _destinationController.text.trim())
                                : null,
                            targetDetail: mapRouteTarget != null
                                ? 'Destino del viaje'
                                : null,
                            remainingDistanceLabel: routePreview?.distanceLabel,
                            remainingDurationLabel: routePreview?.durationLabel,
                            onOpenOfflineInfo: () =>
                                showOfflineMapSheet(context),
                          );
                        },
                        onRequest: !hasActiveTrip
                            ? () async {
                                setState(() {
                                  _topActionsExpanded = false;
                                });
                                await _requestRide();
                              }
                            : null,
                        onDashboard: !hasActiveTrip
                            ? () async {
                                setState(() {
                                  _topActionsExpanded = false;
                                });
                                await _reopenServiceLauncher();
                              }
                            : null,
                        onRadar: hasActiveTrip
                            ? () {
                                setState(() {
                                  _topActionsExpanded = false;
                                });
                                _showTripRequestSheet(tripState);
                              }
                            : null,
                        onRecenter: () async {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          await ref
                              .read(passengerLocationProvider.notifier)
                              .loadCurrentLocation();
                          await _syncDashboard();
                          if (mounted) {
                            setState(() => _mapFocusSignal++);
                          }
                        },
                        onSearch: _openDestinationSearchSheetFromMap,
                      ),
                    ),
                  if (showLandingOverlay)
                    Positioned(
                      left: 0,
                      top: MediaQuery.of(context).size.height * 0.42,
                      child: _GlassIconButton(
                        icon: Icons.warning_amber_rounded,
                        onTap: () {
                          _showFloatingNotification(
                            'Comparte tu ubicación solo cuando estés listo para solicitar el viaje.',
                            tone: NoticeTone.warning,
                          );
                        },
                        backgroundColor: Colors.white.withValues(alpha: 0.98),
                        iconColor: const Color(0xFFB45309),
                      ),
                    ),
                  if (isSearchScene)
                    Positioned.fill(
                      child: _RideSearchOverlay(
                        controller: _destinationController,
                        focusNode: _destinationFocusNode,
                        userLocation: userLocation,
                        suggestions: _destinationSuggestions(),
                        onBack: _reopenServiceLauncher,
                        onChanged: _handleDestinationChanged,
                        onMapTap: _toggleDestinationMoveMode,
                        onSuggestionTap: _selectDestinationPlace,
                      ),
                    ),
                  if (_destinationMoveMode)
                    Positioned(
                      top: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x160F172A),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Deslizar para mover el mapa',
                            style: TextStyle(
                              color: AppBrand.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_destinationMoveMode)
                    Align(
                      alignment: Alignment.center,
                      child: IgnorePointer(
                        child: _MapCenterDestinationPin(
                          lifted: _isDraggingDestinationMap,
                        ),
                      ),
                    ),
                  if (_destinationMoveMode)
                    Positioned(
                      left: 0,
                      bottom: 132,
                      child: _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: _toggleDestinationMoveMode,
                      ),
                    ),
                  if (_destinationMoveMode)
                    Positioned(
                      right: 0,
                      bottom: 132,
                      child: _GlassIconButton(
                        icon: Icons.near_me_rounded,
                        iconWidget: Transform.rotate(
                          angle: -0.35,
                          child: Image.asset(
                            'assets/images/flecha.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        onTap: () async {
                          await ref
                              .read(passengerLocationProvider.notifier)
                              .loadCurrentLocation();
                          final liveLocation =
                              ref.read(passengerLocationProvider).position ??
                              _lastKnownLocation;
                          if (liveLocation == null || !mounted) {
                            return;
                          }
                          setState(() {
                            _movingDestinationCenter = liveLocation;
                            _mapCenterSignal++;
                          });
                          unawaited(
                            _resolveMovingDestinationAddress(liveLocation),
                          );
                        },
                      ),
                    ),
                  if (_destinationMoveMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: _MovingDestinationSheet(
                        lifted: _isDraggingDestinationMap,
                        addressText: _currentAddressText,
                        onCancel: _toggleDestinationMoveMode,
                        onConfirm: _confirmMovingDestination,
                        onSaveFavorite: () {
                          _showFloatingNotification(
                            'Guardado de favoritos pronto disponible.',
                            tone: NoticeTone.info,
                          );
                        },
                      ),
                    ),
                  if (showActiveTripJourneyView)
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: RouteReviewView(
                        title: hasActiveTrip ? 'Tu viaje' : 'Tu recorrido',
                        originLabel: 'Potosí · ubicación actual',
                        destinationLabel:
                            _destinationController.text.trim().isEmpty
                            ? _currentAddressText
                            : _destinationController.text.trim(),
                        summaryLabel:
                            routeSummaryLabel ?? _compactStatusText(tripState),
                        fareLabel: routePreview?.fareLabel ?? 'Bs --',
                        durationLabel:
                            routePreview?.durationLabel ??
                            (tripState.request.etaMinutes == null
                                ? '-- min'
                                : '${tripState.request.etaMinutes} min'),
                        distanceLabel:
                            routePreview?.distanceLabel ??
                            _compactStatusText(tripState),
                        serviceType: _selectedServiceType,
                        onBack: _reopenServiceLauncher,
                        onSelectTaxi: () => _selectServiceType('taxi'),
                        onSelectMoto: () => _selectServiceType('moto'),
                        onEdit: _editDestinationFromStatus,
                        onClear: _clearDestinationSelection,
                        primaryActionLabel: _primaryActionLabel(tripState),
                        primaryActionIcon: _primaryActionIcon(tripState),
                        onPrimaryAction: _primaryActionHandler(tripState),
                        primaryActionColor: hasActiveTrip
                            ? _compactStatusColor(tripState)
                            : const Color(0xFFFF4B38),
                        detailsExpanded: _journeyDetailsExpanded,
                        onToggleDetails: () {
                          setState(() {
                            _journeyDetailsExpanded = !_journeyDetailsExpanded;
                          });
                        },
                        statusText: _compactStatusText(tripState),
                        statusAccent: _compactStatusColor(tripState),
                        statusDetails: _compactStatusDetails(
                          tripState,
                          userLocation,
                        ),
                        secondaryActions: _compactStatusActions(tripState)
                            .where((action) => !action.primary)
                            .map(
                              (action) => RouteReviewActionData(
                                label: action.label,
                                onTap: action.onTap,
                              ),
                            )
                            .toList(growable: false),
                        navigationBadgeLabel: _journeyNavigationBadgeLabel(
                          tripState,
                          routeSummaryLabel ?? _compactStatusText(tripState),
                        ),
                        navigationBadgeCaption: _journeyNavigationBadgeCaption(
                          tripState,
                        ),
                        navigationBadgeIcon: _journeyNavigationBadgeIcon(
                          tripState,
                        ),
                        driverName:
                            (tripState.request.driverName ?? '').trim().isEmpty
                            ? null
                            : tripState.request.driverName!.trim(),
                        vehicleLabel: tripState.request.vehicleLabel,
                        vehiclePlate:
                            (tripState.request.vehiclePlate ?? '')
                                .trim()
                                .isEmpty
                            ? null
                            : tripState.request.vehiclePlate!.trim(),
                        vehicleDetail:
                            (tripState.request.vehicleColor ?? '')
                                .trim()
                                .isEmpty
                            ? null
                            : tripState.request.vehicleColor!.trim(),
                        etaLabel: tripState.request.etaMinutes == null
                            ? null
                            : '${tripState.request.etaMinutes} min',
                        compactMode: const {
                          'accepted',
                          'arriving',
                          'at_pickup',
                          'in_progress',
                        }.contains(tripState.request.status),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!showLandingOverlay &&
            !showActiveTripJourneyView &&
            !_destinationMoveMode &&
            !isSearchScene &&
            !showRouteReviewView &&
            _rideMode != RideMode.cercano &&
            !showPremiumDestinationEntry)
          Positioned(
            left: 20,
            top: 28,
            child: _GlassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => unawaited(_reopenServiceLauncher()),
            ),
          ),
        if (!showLandingOverlay &&
            !showActiveTripJourneyView &&
            !_destinationMoveMode &&
            !isSearchScene &&
            !showRouteReviewView &&
            _rideMode != RideMode.cercano &&
            !showPremiumDestinationEntry)
          Positioned(
            right: 20,
            top: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_topActionsExpanded) ...[
                      _GlassIconButton(
                        icon: Icons.offline_bolt_rounded,
                        onTap: () async {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          await showOfflineMapSheet(context);
                        },
                      ),
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.explore_rounded,
                        onTap: () {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          showMapNavigationSheet(
                            context,
                            currentLabel: 'Potosí',
                            currentDetail: 'Ubicación actual',
                            targetLabel: mapRouteTarget != null
                                ? (_destinationController.text.trim().isEmpty
                                      ? _currentAddressText
                                      : _destinationController.text.trim())
                                : null,
                            targetDetail: mapRouteTarget != null
                                ? 'Destino del viaje'
                                : null,
                            remainingDistanceLabel: routePreview?.distanceLabel,
                            remainingDurationLabel: routePreview?.durationLabel,
                            onOpenOfflineInfo: () =>
                                showOfflineMapSheet(context),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      if (!hasActiveTrip)
                        _GlassIconButton(
                          icon: Icons.local_taxi_rounded,
                          onTap: () async {
                            setState(() {
                              _topActionsExpanded = false;
                            });
                            if (_rideMode == RideMode.destino) {
                              await _requestRide();
                            } else {
                              await (_selectedDriverId == null
                                  ? _selectNearestTaxi()
                                  : _requestRide());
                            }
                          },
                        ),
                      if (!hasActiveTrip) const SizedBox(width: 10),
                      if (!hasActiveTrip)
                        _GlassIconButton(
                          icon: Icons.dashboard_customize_rounded,
                          onTap: () async {
                            setState(() {
                              _topActionsExpanded = false;
                            });
                            await _reopenServiceLauncher();
                          },
                        ),
                      if (!hasActiveTrip) const SizedBox(width: 10),
                      if (hasActiveTrip)
                        _GlassIconButton(
                          icon: Icons.radar_rounded,
                          onTap: () {
                            setState(() {
                              _topActionsExpanded = false;
                            });
                            _showTripRequestSheet(tripState);
                          },
                        ),
                      if (hasActiveTrip) const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.near_me_rounded,
                        iconWidget: Transform.rotate(
                          angle: -0.35,
                          child: Image.asset(
                            'assets/images/flecha.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        onTap: () async {
                          setState(() {
                            _topActionsExpanded = false;
                          });
                          await ref
                              .read(passengerLocationProvider.notifier)
                              .loadCurrentLocation();
                          await _syncDashboard();
                          if (mounted) {
                            setState(() => _mapFocusSignal++);
                          }
                        },
                      ),
                    ],
                    if (_topActionsExpanded) const SizedBox(width: 10),
                    _MapActionButton(
                      icon: _topActionsExpanded
                          ? Icons.close_rounded
                          : Icons.add_rounded,
                      onTap: () {
                        setState(() {
                          _topActionsExpanded = !_topActionsExpanded;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _GlassIconButton(
                  icon: Icons.search_rounded,
                  onTap: () {
                    setState(() {
                      _topActionsExpanded = false;
                    });
                    _activateDestinationMode();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildVehicleCards(List<NearbyDriver> drivers) {
    if (drivers.isEmpty) {
      return const [_EmptyRideCard()];
    }
    const names = ['Taxi Eco', 'Taxi Plus', 'Taxi Ejecutivo', 'Taxi Max'];

    return List<Widget>.generate(drivers.length, (index) {
      final driver = drivers[index];
      final isSelected =
          driver.driverId == (_selectedDriverId ?? drivers.first.driverId);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _VehicleOptionCard(
          title: driver.vehicleLabel.isEmpty
              ? names[index % names.length]
              : driver.vehicleLabel,
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

enum RideMode { destino, cercano }

class _MapCenterDestinationPin extends StatefulWidget {
  const _MapCenterDestinationPin({required this.lifted});

  final bool lifted;

  @override
  State<_MapCenterDestinationPin> createState() => _MapCenterDestinationPinState();
}

class _MapCenterDestinationPinState extends State<_MapCenterDestinationPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifted = widget.lifted;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = 1 + (_pulseController.value * 0.12);
        final pulseOpacity = 0.14 + (_pulseController.value * 0.18);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, lifted ? -12 : 0, 0),
          width: 92,
          height: 116,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 14,
                child: Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2F80FF).withValues(
                        alpha: pulseOpacity,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                child: _ManualDestinationPinVisual(
                  lifted: lifted,
                ),
              ),
              Positioned(
                bottom: 4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x552F80FF),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManualDestinationPinVisual extends StatelessWidget {
  const _ManualDestinationPinVisual({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 92,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 40,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: lifted
                        ? const Color(0xFF2F80FF)
                        : const Color(0xFFB8D7FF),
                    width: lifted ? 2.2 : 1.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332F80FF),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: lifted
                    ? const Color(0xFF2F80FF)
                    : const Color(0xFFBCD7FF),
                width: lifted ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: lifted
                      ? const Color(0x452F80FF)
                      : const Color(0x220B3A75),
                  blurRadius: lifted ? 24 : 16,
                  offset: Offset(0, lifted ? 15 : 9),
                ),
              ],
            ),
            child: Center(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF60A5FA),
                      AppBrand.primaryBlue,
                      Color(0xFF1D4ED8),
                    ],
                  ),
                ),
                child: const SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(
                    Icons.place_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreviewData {
  const _RoutePreviewData({
    required this.distanceMeters,
    required this.distanceLabel,
    required this.durationLabel,
    required this.fareLabel,
    required this.serviceLabel,
  });

  final double distanceMeters;
  final String distanceLabel;
  final String durationLabel;
  final String fareLabel;
  final String serviceLabel;
}

class _RideSearchOverlay extends StatelessWidget {
  const _RideSearchOverlay({
    required this.controller,
    required this.focusNode,
    required this.userLocation,
    required this.suggestions,
    required this.onBack,
    required this.onChanged,
    required this.onMapTap,
    required this.onSuggestionTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LatLng userLocation;
  final List<PotosiPlace> suggestions;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback onMapTap;
  final ValueChanged<PotosiPlace> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Agregar parada',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: AppBrand.primaryBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        decoration: const InputDecoration(
                          hintText: '¿A dónde vas?',
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: onMapTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppBrand.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Mapa'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (controller.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Ingresa una ubicación o dirección, por ejemplo, 228 Oxford St.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppBrand.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: suggestions.isEmpty
                    ? Center(
                        child: Text(
                          'No encontramos coincidencias todavía.',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppBrand.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 28),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final place = suggestions[index];
                          return _DestinationSuggestionCard(
                            place: place,
                            userLocation: userLocation,
                            onTap: () => onSuggestionTap(place),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovingDestinationSheet extends StatelessWidget {
  const _MovingDestinationSheet({
    required this.lifted,
    required this.addressText,
    required this.onCancel,
    required this.onConfirm,
    required this.onSaveFavorite,
  });

  final bool lifted;
  final String addressText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onSaveFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECCIONA LA UBICACIÓN EN EL MAPA',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppBrand.textPrimary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: AppBrand.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_rounded,
                  color: AppBrand.primaryBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    addressText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppBrand.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CircularMapEditorButton(
                icon: Icons.arrow_back_rounded,
                onTap: onCancel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CircularMapEditorButton(
                icon: Icons.bookmark_border_rounded,
                onTap: onSaveFavorite,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteConfirmationCard extends StatelessWidget {
  const _RouteConfirmationCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.summaryLabel,
    required this.onAddStop,
    required this.onClearDestination,
    required this.onPrimary,
    this.fareLabel,
    this.durationLabel,
    this.distanceLabel,
    this.serviceType = 'taxi',
    this.onSelectTaxi,
    this.onSelectMoto,
    this.onOptions,
    this.primaryLabel = 'Vamos',
  });

  final String originLabel;
  final String destinationLabel;
  final String summaryLabel;
  final VoidCallback onAddStop;
  final VoidCallback onClearDestination;
  final VoidCallback? onPrimary;
  final String? fareLabel;
  final String? durationLabel;
  final String? distanceLabel;
  final String serviceType;
  final VoidCallback? onSelectTaxi;
  final VoidCallback? onSelectMoto;
  final VoidCallback? onOptions;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ServiceTypeChip(
                  label: 'Taxi',
                  icon: Icons.local_taxi_rounded,
                  selected: serviceType == 'taxi',
                  onTap: onSelectTaxi,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceTypeChip(
                  label: 'Moto',
                  icon: Icons.two_wheeler_rounded,
                  selected: serviceType == 'moto',
                  onTap: onSelectMoto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TripStopRow(
                  icon: Icons.radio_button_checked_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'Origen',
                  value: originLabel,
                ),
              ),
              IconButton(
                onPressed: onAddStop,
                icon: const Icon(
                  Icons.add_rounded,
                  color: AppBrand.textSecondary,
                ),
              ),
              IconButton(
                onPressed: onClearDestination,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppBrand.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TripStopRow(
            icon: Icons.flag_rounded,
            iconColor: AppBrand.primaryBlue,
            title: 'Destino',
            value: destinationLabel,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppBrand.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                summaryLabel,
                style: const TextStyle(
                  color: AppBrand.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (fareLabel != null ||
              durationLabel != null ||
              distanceLabel != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (durationLabel != null)
                  _MiniPill(
                    icon: Icons.schedule_rounded,
                    label: durationLabel!,
                    active: true,
                  ),
                if (distanceLabel != null)
                  _MiniPill(
                    icon: Icons.route_rounded,
                    label: distanceLabel!,
                    active: false,
                  ),
                if (fareLabel != null)
                  _MiniPill(
                    icon: Icons.payments_rounded,
                    label: fareLabel!,
                    active: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (onOptions != null) ...[
                const SizedBox(width: 12),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onOptions,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyMapScreenCard extends StatelessWidget {
  const _JourneyMapScreenCard({
    required this.destinationLabel,
    required this.summaryLabel,
    required this.onPrimary,
    required this.stateText,
    required this.stateAccent,
    required this.stateDetails,
    required this.stateActions,
    required this.primaryLabel,
    required this.hasActiveTrip,
    this.driverName,
    this.vehicleLabel,
    this.vehicleDetail,
    this.etaMinutes,
    this.fareLabel,
    this.durationLabel,
    this.distanceLabel,
  });

  final String destinationLabel;
  final String summaryLabel;
  final String? fareLabel;
  final String? durationLabel;
  final String? distanceLabel;
  final VoidCallback? onPrimary;
  final String stateText;
  final Color stateAccent;
  final List<String> stateDetails;
  final List<_CompactStatusActionData> stateActions;
  final String primaryLabel;
  final bool hasActiveTrip;
  final String? driverName;
  final String? vehicleLabel;
  final String? vehicleDetail;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final driverCaption = [
      if ((vehicleLabel ?? '').isNotEmpty) vehicleLabel!,
      if ((vehicleDetail ?? '').isNotEmpty) vehicleDetail!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stateText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: stateAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summaryLabel,
                  style: TextStyle(
                    color: stateAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if ((driverName ?? '').isNotEmpty || driverCaption.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: stateAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.person_rounded, color: stateAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (driverName ?? '').isNotEmpty
                              ? driverName!
                              : 'Conductor asignado',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.textPrimary,
                          ),
                        ),
                        if (driverCaption.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            driverCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppBrand.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (etaMinutes != null)
                    _MiniPill(
                      icon: Icons.schedule_rounded,
                      label: '$etaMinutes min',
                      active: true,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destino',
                  style: TextStyle(
                    color: AppBrand.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destinationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (stateDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stateDetails
                  .take(3)
                  .map(
                    (detail) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          color: AppBrand.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: stateAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: Text(primaryLabel),
            ),
          ),
          if (stateActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: stateActions
                  .where((action) => !action.primary)
                  .map(
                    (action) => GestureDetector(
                      onTap: action.onTap,
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          color: AppBrand.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceTypeChip extends StatelessWidget {
  const _ServiceTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F1FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppBrand.primaryBlue : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppBrand.primaryBlue : AppBrand.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppBrand.primaryBlue : AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripStopRow extends StatelessWidget {
  const _TripStopRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppBrand.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircularMapEditorButton extends StatelessWidget {
  const _CircularMapEditorButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE7F5)),
          ),
          child: Icon(icon, color: AppBrand.textPrimary),
        ),
      ),
    );
  }
}

class _CompactStateCard extends StatelessWidget {
  const _CompactStateCard({
    required this.text,
    required this.accent,
    this.details = const <String>[],
    this.actions = const <_CompactStatusActionData>[],
  });

  final String text;
  final Color accent;
  final List<String> details;
  final List<_CompactStatusActionData> actions;

  @override
  Widget build(BuildContext context) {
    final primaryAction = actions
        .where((action) => action.primary)
        .cast<_CompactStatusActionData?>()
        .firstWhere(
          (action) => action != null,
          orElse: () => actions.isNotEmpty ? actions.first : null,
        );
    final secondaryActions = actions
        .where((action) => action != primaryAction)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 148),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: AppBrand.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: details
                  .map(
                    (detail) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppBrand.surfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          color: AppBrand.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: primaryAction.onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  primaryAction.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
          if (secondaryActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: secondaryActions
                  .map(
                    (action) => TextButton(
                      onPressed: action.onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppBrand.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        action.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactStatusActionData {
  const _CompactStatusActionData({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconWidget,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget? iconWidget;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.98),
      shape: const CircleBorder(),
      shadowColor: const Color(0x220F172A),
      elevation: 12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child:
                iconWidget ??
                Icon(icon, color: iconColor ?? AppBrand.textPrimary, size: 26),
          ),
        ),
      ),
    );
  }
}

class _PremiumRequestTaxiTopBar extends StatelessWidget {
  const _PremiumRequestTaxiTopBar({
    required this.onBack,
    required this.expanded,
    required this.hasActiveTrip,
    required this.onToggleExpanded,
    required this.onOffline,
    required this.onDetails,
    this.onRequest,
    this.onDashboard,
    this.onRadar,
    required this.onRecenter,
    required this.onSearch,
  });

  final VoidCallback onBack;
  final bool expanded;
  final bool hasActiveTrip;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOffline;
  final VoidCallback onDetails;
  final VoidCallback? onRequest;
  final VoidCallback? onDashboard;
  final VoidCallback? onRadar;
  final VoidCallback onRecenter;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PremiumBlueSquareButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expanded) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: _PremiumMiniActionRow(
                hasActiveTrip: hasActiveTrip,
                onOffline: onOffline,
                onDetails: onDetails,
                onRequest: onRequest,
                onDashboard: onDashboard,
                onRadar: onRadar,
                onRecenter: onRecenter,
              ),
              ),
              const SizedBox(height: 8),
            ],
            _PremiumVerticalActionCard(
              expanded: expanded,
              onToggleExpanded: onToggleExpanded,
              onSearch: onSearch,
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumBlueSquareButton extends StatelessWidget {
  const _PremiumBlueSquareButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1D4ED8),
      borderRadius: BorderRadius.circular(20),
      elevation: 16,
      shadowColor: const Color(0x331D4ED8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _PremiumVerticalActionCard extends StatelessWidget {
  const _PremiumVerticalActionCard({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSearch,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            onTap: onToggleExpanded,
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Icon(
                expanded ? Icons.close_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 2,
            color: Colors.white.withValues(alpha: 0.24),
          ),
          InkWell(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            onTap: onSearch,
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMiniActionRow extends StatelessWidget {
  const _PremiumMiniActionRow({
    required this.hasActiveTrip,
    required this.onOffline,
    required this.onDetails,
    this.onRequest,
    this.onDashboard,
    this.onRadar,
    required this.onRecenter,
  });

  final bool hasActiveTrip;
  final VoidCallback onOffline;
  final VoidCallback onDetails;
  final VoidCallback? onRequest;
  final VoidCallback? onDashboard;
  final VoidCallback? onRadar;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _PremiumSmallBlueIconButton(
        icon: Icons.offline_bolt_rounded,
        onTap: onOffline,
      ),
      _PremiumSmallBlueIconButton(
        icon: Icons.explore_rounded,
        onTap: onDetails,
      ),
      if (!hasActiveTrip && onRequest != null)
        _PremiumSmallBlueIconButton(
          icon: Icons.local_taxi_rounded,
          onTap: onRequest!,
        ),
      if (!hasActiveTrip && onDashboard != null)
        _PremiumSmallBlueIconButton(
          icon: Icons.dashboard_customize_rounded,
          onTap: onDashboard!,
        ),
      if (hasActiveTrip && onRadar != null)
        _PremiumSmallBlueIconButton(
          icon: Icons.radar_rounded,
          onTap: onRadar!,
        ),
      _PremiumSmallBlueIconButton(
        icon: Icons.near_me_rounded,
        onTap: onRecenter,
        iconWidget: Transform.rotate(
          angle: -0.35,
          child: Image.asset(
            'assets/images/flecha.png',
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    ];

    return Wrap(
      direction: Axis.vertical,
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}

class _PremiumSmallBlueIconButton extends StatelessWidget {
  const _PremiumSmallBlueIconButton({
    required this.icon,
    required this.onTap,
    this.iconWidget,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1D4ED8),
      borderRadius: BorderRadius.circular(16),
      elevation: 10,
      shadowColor: const Color(0x331D4ED8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: iconWidget ??
                Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(22),
      elevation: 8,
      shadowColor: const Color(0x180F172A),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppBrand.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8FFF1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFBBE7CD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? const Color(0xFF16A34A) : AppBrand.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF14532D) : AppBrand.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppBrand.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SheetFieldRow extends StatelessWidget {
  const _SheetFieldRow({
    required this.dotColor,
    required this.title,
    required this.value,
    this.trailing,
  });

  final Color dotColor;
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailingWidgets = trailing == null
        ? const <Widget>[]
        : <Widget>[trailing!];
    final isOrigin = title == 'Origen';

    return Row(
      children: [
        if (isOrigin)
          const _OriginNavigationBadge()
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppBrand.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ...trailingWidgets,
      ],
    );
  }
}

class _OriginNavigationBadge extends StatelessWidget {
  const _OriginNavigationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE27A), width: 1.1),
      ),
      child: const Icon(
        Icons.navigation_rounded,
        color: AppBrand.primaryBlue,
        size: 13,
      ),
    );
  }
}

class _LandingIntroCard extends StatelessWidget {
  const _LandingIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comienza tu viaje',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppBrand.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Primero elige la opción que quieres usar. Después te mostraremos solo el flujo correspondiente en el mapa.',
            style: TextStyle(
              color: AppBrand.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingModeCard extends StatelessWidget {
  const _LandingModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppBrand.textPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationSuggestionCard extends StatelessWidget {
  const _DestinationSuggestionCard({
    required this.place,
    required this.userLocation,
    required this.onTap,
  });

  final PotosiPlace place;
  final LatLng userLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final km = const Distance().as(
      LengthUnit.Kilometer,
      userLocation,
      place.point,
    );
    final distanceLabel = km < 1
        ? '${(km * 1000).round()} m'
        : '${km.toStringAsFixed(1)} km';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: AppBrand.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.aliases.isNotEmpty
                          ? place.aliases.first
                          : 'Destino sugerido en Potosi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                distanceLabel,
                style: const TextStyle(
                  color: AppBrand.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: highlighted
                  ? AppBrand.primaryBlue
                  : const Color(0xFFE2E8F0),
              width: highlighted ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: highlighted
                      ? AppBrand.surfaceMuted
                      : AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: highlighted
                      ? AppBrand.primaryBlue
                      : AppBrand.textSecondary,
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
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Llega en $eta · $distance',
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
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
                    const Icon(
                      Icons.check_circle,
                      color: AppBrand.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFBBF24),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted
                          ? AppBrand.primaryBlue
                          : AppBrand.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: highlighted
                            ? AppBrand.primaryBlue
                            : const Color(0xFFDCE7F5),
                      ),
                    ),
                    child: Text(
                      selectedLabel,
                      style: TextStyle(
                        color: highlighted
                            ? Colors.white
                            : AppBrand.primaryBlue,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'Todavia no vemos taxis activos. Usa "mi ubicacion" y espera unos segundos para cargar autos cercanos.',
        style: TextStyle(
          color: AppBrand.textSecondary,
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
    'requested' =>
      'Estamos enviando tu solicitud a los conductores disponibles.',
    'searching' => 'Muy pronto veras quien acepta tu viaje.',
    'accepted' =>
      etaMinutes == null
          ? 'Tu conductor ya confirmo el viaje.'
          : 'Tu conductor ya confirmo el viaje y llega en $etaMinutes min.',
    'arriving' =>
      etaMinutes == null
          ? 'Sigue el recorrido del conductor hacia tu punto.'
          : 'Tu conductor va en camino y llega en $etaMinutes min.',
    'at_pickup' => 'Verifica el auto y sube cuando estes listo.',
    'in_progress' => 'Viaje en progreso.',
    'completed' => 'Gracias por viajar con RAPIGO.',
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
          if ((vehicleLabel ?? '').isNotEmpty ||
              (vehiclePlate ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (etaMinutes != null &&
                    const {'accepted', 'arriving'}.contains(status))
                  _TripBadge(
                    icon: Icons.schedule,
                    label: 'Llega en $etaMinutes min',
                  ),
                if ((vehicleLabel ?? '').isNotEmpty)
                  _TripBadge(
                    icon: (vehicleLabel ?? '').toLowerCase().contains('moto')
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_filled_rounded,
                    label: vehicleLabel!,
                  ),
                if ((vehiclePlate ?? '').isNotEmpty)
                  _TripBadge(
                    icon: Icons.badge_outlined,
                    label: 'Placa $vehiclePlate',
                  ),
                if ((vehicleColor ?? '').isNotEmpty)
                  _TripBadge(
                    icon: Icons.palette_outlined,
                    label: 'Color ${vehicleColor!}',
                  ),
                if ((vehicleType ?? '').isNotEmpty)
                  _TripBadge(
                    icon: (vehicleType ?? '').toLowerCase() == 'moto'
                        ? Icons.two_wheeler_rounded
                        : Icons.local_taxi_rounded,
                    label: 'Tipo ${vehicleType!}',
                  ),
                if ((driverName ?? '').isNotEmpty)
                  _TripBadge(
                    icon: Icons.person_outline_rounded,
                    label: driverName!,
                  ),
                if ((driverPhone ?? '').isNotEmpty)
                  _TripBadge(icon: Icons.phone_outlined, label: driverPhone!),
              ],
            ),
          ],
          if ((driverName ?? '').isNotEmpty ||
              (driverPhone ?? '').isNotEmpty) ...[
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
                    if ((driverName ?? '').isNotEmpty)
                      const SizedBox(height: 10),
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
  const _TripProgressBar({required this.status});

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
                    color: isActive
                        ? const Color(0xFFF97316)
                        : Colors.white.withValues(alpha: 0.18),
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
                    : Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReached
                      ? const Color(0xFFF97316)
                      : Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                isReached ? Icons.check : Icons.circle,
                size: isReached ? 14 : 8,
                color: isReached
                    ? const Color(0xFF0F0F10)
                    : Colors.white.withValues(alpha: 0.45),
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
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.58),
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
  const _TripBadge({required this.icon, required this.label});

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
  const _TripInfoRow({required this.label, required this.value});

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
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
