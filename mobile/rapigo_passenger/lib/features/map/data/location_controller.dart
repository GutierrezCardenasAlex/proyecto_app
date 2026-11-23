import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/potosi_geo.dart';
import '../../auth/data/auth_repository.dart';

final passengerLocationProvider =
    NotifierProvider<PassengerLocationController, PassengerLocationState>(
      PassengerLocationController.new,
    );

class PassengerLocationState {
  const PassengerLocationState({
    required this.isLoading,
    required this.position,
    required this.accuracyMeters,
    required this.headingDegrees,
    required this.errorMessage,
  });

  final bool isLoading;
  final LatLng? position;
  final double? accuracyMeters;
  final double? headingDegrees;
  final String? errorMessage;

  PassengerLocationState copyWith({
    bool? isLoading,
    LatLng? position,
    double? accuracyMeters,
    double? headingDegrees,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PassengerLocationState(
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class PassengerLocationController extends Notifier<PassengerLocationState>
    with WidgetsBindingObserver {
  bool _foreground = true;
  static const _cacheLatKey = 'passenger_location_cache_lat';
  static const _cacheLngKey = 'passenger_location_cache_lng';
  static const _cacheAccuracyKey = 'passenger_location_cache_accuracy';
  static const _cacheHeadingKey = 'passenger_location_cache_heading';

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _smoothedCompassHeading;

  @override
  PassengerLocationState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _positionSubscription?.cancel();
      _compassSubscription?.cancel();
    });
    ref.listen(sessionProvider, (previous, next) {
      if (!next.isAuthenticated) {
        unawaited(_positionSubscription?.cancel());
        _positionSubscription = null;
      }
    });
    Future<void>.microtask(_bootstrapLocation);
    return const PassengerLocationState(
      isLoading: true,
      position: null,
      accuracyMeters: null,
      headingDegrees: null,
      errorMessage: null,
    );
  }

  Future<void> _bootstrapLocation() async {
    await _restoreCachedLocation();
    await _startCompassTracking();
    await loadCurrentLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(loadCurrentLocation());
    } else {
      unawaited(_positionSubscription?.cancel());
      _positionSubscription = null;
    }
  }

  Future<void> loadCurrentLocation() async {
    if (!_foreground || !ref.read(sessionProvider).isAuthenticated) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _ensureLocationReady();
      Position? resolvedPosition;
      try {
        resolvedPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {
        resolvedPosition = await Geolocator.getLastKnownPosition();
      }

      if (resolvedPosition != null) {
        _applyPosition(resolvedPosition);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: state.position == null
              ? 'No se pudo obtener tu ubicacion.'
              : null,
        );
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo obtener tu ubicacion.',
      );
    } finally {
      try {
        await _startTracking();
      } catch (_) {
        if (state.position == null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'No se pudo actualizar tu ubicación.',
          );
        }
      }
    }
  }

  Future<void> _restoreCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_cacheLatKey);
    final lng = prefs.getDouble(_cacheLngKey);
    if (lat == null || lng == null) {
      return;
    }
    state = state.copyWith(
      isLoading: false,
      position: LatLng(lat, lng),
      accuracyMeters: prefs.getDouble(_cacheAccuracyKey),
      headingDegrees: prefs.getDouble(_cacheHeadingKey),
      clearError: true,
    );
  }

  Future<void> _cacheLocation(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cacheLatKey, position.latitude);
    await prefs.setDouble(_cacheLngKey, position.longitude);
    await prefs.setDouble(_cacheAccuracyKey, position.accuracy);
    if (position.heading.isFinite) {
      await prefs.setDouble(_cacheHeadingKey, position.heading);
    } else {
      await prefs.remove(_cacheHeadingKey);
    }
  }

  Future<void> _ensureLocationReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Activa el GPS para mostrar autos cercanos.');
    }

    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicacion denegado.');
    }
  }

  Future<void> _startTracking() async {
    await _ensureLocationReady();
    if (!_foreground || !ref.read(sessionProvider).isAuthenticated) return;
    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings(),
        ).listen(
          _applyPosition,
          onError: (_) {
            state = state.copyWith(
              isLoading: false,
              errorMessage: 'No se pudo actualizar tu ubicación.',
            );
          },
        );
  }

  Future<void> _startCompassTracking() async {
    await _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final rawHeading = event.heading;
      if (rawHeading == null || !rawHeading.isFinite) {
        return;
      }
      final heading = _filterHeading(rawHeading);
      state = state.copyWith(headingDegrees: heading, clearError: true);
    });
  }

  double _filterHeading(double rawHeading) {
    final normalized = (rawHeading % 360 + 360) % 360;
    final previous = _smoothedCompassHeading;
    if (previous == null) {
      _smoothedCompassHeading = normalized;
      return normalized;
    }

    var delta = normalized - previous;
    if (delta > 180) {
      delta -= 360;
    } else if (delta < -180) {
      delta += 360;
    }

    if (delta.abs() < 1.4) {
      return previous;
    }

    final smoothing = delta.abs() > 18 ? 0.62 : 0.34;
    final next = previous + (delta * smoothing);
    _smoothedCompassHeading = (next % 360 + 360) % 360;
    return _smoothedCompassHeading!;
  }

  LatLng _smoothedPosition(Position position) {
    final previous = state.position;
    final next = LatLng(position.latitude, position.longitude);
    if (previous == null) {
      return next;
    }

    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      previous,
      next,
    );
    if (distanceMeters >= 28) {
      return next;
    }

    final factor = distanceMeters <= 2
        ? 0.18
        : distanceMeters <= 6
        ? 0.30
        : distanceMeters <= 12
        ? 0.44
        : 0.62;

    return LatLng(
      previous.latitude + ((next.latitude - previous.latitude) * factor),
      previous.longitude + ((next.longitude - previous.longitude) * factor),
    );
  }

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 2),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
        allowBackgroundLocationUpdates: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  void _applyPosition(Position position) {
    if (!_foreground || !ref.read(sessionProvider).isAuthenticated) return;
    unawaited(_cacheLocation(position));
    final smoothedPoint = _smoothedPosition(position);

    if (!PotosiGeo.isInside(position.latitude, position.longitude)) {
      state = state.copyWith(
        isLoading: false,
        position: smoothedPoint,
        accuracyMeters: position.accuracy,
        headingDegrees: position.heading.isFinite ? position.heading : null,
        errorMessage: 'La app solo opera dentro de Potosi.',
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      position: smoothedPoint,
      accuracyMeters: position.accuracy,
      headingDegrees: position.heading.isFinite ? position.heading : null,
      clearError: true,
    );
  }
}
