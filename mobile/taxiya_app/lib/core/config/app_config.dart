import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AppConfig {
  static const serverScheme = String.fromEnvironment('SERVER_SCHEME', defaultValue: 'http');
  static const serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: 'api-flashgo.cybernovatech.space',
  );
  static const gatewayPort = String.fromEnvironment('GATEWAY_PORT', defaultValue: '80');
  static const websocketPort = String.fromEnvironment('WEBSOCKET_PORT', defaultValue: '80');
  static const mapTilesUrlTemplate = String.fromEnvironment(
    'MAP_TILES_URL_TEMPLATE',
    defaultValue: 'http://tiles-flashgo.cybernovatech.space/styles/basic-preview/512/{z}/{x}/{y}.png',
  );
  static const mapTilesAttribution = String.fromEnvironment(
    'MAP_TILES_ATTRIBUTION',
    defaultValue: 'Flash Go Tiles',
  );
  static const mapOfflineTilesUrlTemplate = String.fromEnvironment(
    'MAP_OFFLINE_TILES_URL_TEMPLATE',
    defaultValue: 'http://tiles-flashgo.cybernovatech.space/styles/basic-preview/512/{z}/{x}/{y}.png',
  );
  static const mapOfflineTilesAttribution = String.fromEnvironment(
    'MAP_OFFLINE_TILES_ATTRIBUTION',
    defaultValue: 'Flash Go Tiles',
  );
  static const _mapRoutingUrlBase = String.fromEnvironment(
    'MAP_ROUTING_URL_BASE',
    defaultValue: '',
  );
  static const routingScheme = String.fromEnvironment('ROUTING_SCHEME', defaultValue: serverScheme);
  static const routingHost = String.fromEnvironment('ROUTING_HOST', defaultValue: serverHost);
  static const routingPort = String.fromEnvironment('ROUTING_PORT', defaultValue: '5005');
  static const routingPath = String.fromEnvironment(
    'ROUTING_PATH',
    defaultValue: '/route/v1/driving',
  );

  static String get apiBaseUrl => '$serverScheme://$serverHost:$gatewayPort/api';
  static String get websocketUrl => '$serverScheme://$serverHost:$websocketPort';

  static String get effectiveMapTilesUrlTemplate {
    final offlineCompatible = effectiveOfflineTilesUrlTemplate.trim();
    if (offlineCompatible.isNotEmpty) {
      return offlineCompatible;
    }
    return mapTilesUrlTemplate;
  }

  static bool get usesDefaultOpenStreetMapTiles =>
      mapTilesUrlTemplate.contains('tile.openstreetmap.org');

  static String get effectiveOfflineTilesUrlTemplate {
    final dedicated = mapOfflineTilesUrlTemplate.trim();
    if (dedicated.isNotEmpty) {
      return dedicated;
    }
    if (!usesDefaultOpenStreetMapTiles) {
      return mapTilesUrlTemplate;
    }
    return '';
  }

  static String get effectiveOfflineTilesAttribution {
    final dedicated = mapOfflineTilesAttribution.trim();
    if (dedicated.isNotEmpty) {
      return dedicated;
    }
    return mapTilesAttribution.trim();
  }

  static bool get hasDedicatedOfflineTileSource => effectiveOfflineTilesUrlTemplate.isNotEmpty;
  static bool get shouldUseOpenStreetMapFallbackLayer =>
      effectiveOfflineTilesUrlTemplate.isNotEmpty && usesDefaultOpenStreetMapTiles;
  static String get mapRoutingUrlBase {
    final explicit = _mapRoutingUrlBase.trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    const defaultPublicRouting = 'https://router.project-osrm.org/route/v1/driving';
    final usesCustomRoutingHost =
        routingHost.trim().isNotEmpty && routingHost.trim() != serverHost.trim();
    if (usesCustomRoutingHost) {
      return '$routingScheme://$routingHost:$routingPort$routingPath';
    }
    return defaultPublicRouting;
  }

  static bool get hasRoutingSource => mapRoutingUrlBase.trim().isNotEmpty;

  static const offlineRegionName = 'Potosi ciudad';

  static LatLngBounds get potosiOfflineBounds => LatLngBounds(
        const LatLng(-19.6350, -65.8050),
        const LatLng(-19.5450, -65.7050),
      );

  static LatLngBounds get potosiViewBounds => LatLngBounds(
        const LatLng(-19.6450, -65.8150),
        const LatLng(-19.5350, -65.6950),
      );

  static const mapMinZoom = 13.4;
  static const mapInitialZoom = 14.8;
  static const mapMaxZoom = 16.0;
}
