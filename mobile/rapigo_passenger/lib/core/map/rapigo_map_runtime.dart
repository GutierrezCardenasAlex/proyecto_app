import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

enum RapigoMapEngine {
  flutterMapRaster,
  mapLibreVector,
}

enum RapigoMapThemeMode {
  lightProfessional,
}

@immutable
class RapigoMapStyleManifest {
  const RapigoMapStyleManifest({
    required this.id,
    required this.assetPath,
    this.vectorStyleUrl,
    required this.background,
    required this.water,
    required this.roads,
    required this.mainRoads,
    required this.labels,
    required this.parks,
    required this.route,
  });

  final String id;
  final String assetPath;
  final String? vectorStyleUrl;
  final Color background;
  final Color water;
  final Color roads;
  final Color mainRoads;
  final Color labels;
  final Color parks;
  final Color route;
}

@immutable
class RapigoOfflineCityPack {
  const RapigoOfflineCityPack({
    required this.id,
    required this.name,
    required this.bounds,
    required this.viewBounds,
    required this.styleAssetPath,
    this.mbtilesAssetPath,
  });

  final String id;
  final String name;
  final LatLngBounds bounds;
  final LatLngBounds viewBounds;
  final String styleAssetPath;
  final String? mbtilesAssetPath;
}

@immutable
class RapigoMapRuntimeConfig {
  const RapigoMapRuntimeConfig({
    required this.engine,
    required this.themeMode,
    required this.style,
    required this.cityPack,
    required this.enableRotationSmoothing,
    required this.enableGlowMarkers,
    required this.enableFutureVectorBridge,
  });

  final RapigoMapEngine engine;
  final RapigoMapThemeMode themeMode;
  final RapigoMapStyleManifest style;
  final RapigoOfflineCityPack cityPack;
  final bool enableRotationSmoothing;
  final bool enableGlowMarkers;
  final bool enableFutureVectorBridge;

  bool get shouldUseMapLibre => engine == RapigoMapEngine.mapLibreVector;
}

const rapigoLightStyle = RapigoMapStyleManifest(
  id: 'rapigo_light',
  assetPath: 'assets/styles/rapigo_light.json',
  vectorStyleUrl: null,
  background: Color(0xFFAFC9E8),
  water: Color(0xFF82ABD8),
  roads: Color(0xFFFCFEFF),
  mainRoads: Color(0xFFF8C85E),
  labels: Color(0xFF0E3158),
  parks: Color(0xFFA9D19B),
  route: Color(0xFF2979FF),
);

final potosiCityPack = RapigoOfflineCityPack(
  id: 'potosi',
  name: AppConfig.offlineRegionName,
  bounds: AppConfig.potosiOfflineBounds,
  viewBounds: AppConfig.potosiViewBounds,
  styleAssetPath: rapigoLightStyle.assetPath,
  mbtilesAssetPath: 'assets/maps/potosi.mbtiles',
);

RapigoMapEngine _resolveEngine() {
  const raw = String.fromEnvironment('RAPIGO_MAP_ENGINE', defaultValue: 'maplibre');
  switch (raw.trim().toLowerCase()) {
    case 'maplibre':
    case 'maplibre_gl':
    case 'vector':
      return RapigoMapEngine.mapLibreVector;
    default:
      return RapigoMapEngine.flutterMapRaster;
  }
}

final rapigoMapRuntimeProvider = Provider<RapigoMapRuntimeConfig>((ref) {
  return RapigoMapRuntimeConfig(
    engine: _resolveEngine(),
    themeMode: RapigoMapThemeMode.lightProfessional,
    style: rapigoLightStyle,
    cityPack: potosiCityPack,
    enableRotationSmoothing: true,
    enableGlowMarkers: true,
    enableFutureVectorBridge: true,
  );
});
