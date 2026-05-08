import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AppConfig {
  static const serverScheme = String.fromEnvironment('SERVER_SCHEME', defaultValue: 'http');
  static const serverHost = String.fromEnvironment('SERVER_HOST', defaultValue: '62.171.186.246');
  static const gatewayPort = String.fromEnvironment('GATEWAY_PORT', defaultValue: '3000');
  static const websocketPort = String.fromEnvironment('WEBSOCKET_PORT', defaultValue: '3008');
  static const mapTilesUrlTemplate = String.fromEnvironment(
    'MAP_TILES_URL_TEMPLATE',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const mapTilesAttribution = String.fromEnvironment(
    'MAP_TILES_ATTRIBUTION',
    defaultValue: '',
  );
  static const mapOfflineTilesUrlTemplate = String.fromEnvironment(
    'MAP_OFFLINE_TILES_URL_TEMPLATE',
    defaultValue: '',
  );
  static const mapOfflineTilesAttribution = String.fromEnvironment(
    'MAP_OFFLINE_TILES_ATTRIBUTION',
    defaultValue: '',
  );

  static String get apiBaseUrl => '$serverScheme://$serverHost:$gatewayPort/api';
  static String get websocketUrl => '$serverScheme://$serverHost:$websocketPort';

  static bool get hasDedicatedOfflineTileSource => mapOfflineTilesUrlTemplate.trim().isNotEmpty;

  static const offlineRegionName = 'Potosi ciudad';

  static LatLngBounds get potosiOfflineBounds => LatLngBounds(
        const LatLng(-19.6350, -65.8050),
        const LatLng(-19.5450, -65.7050),
      );

  static LatLngBounds get potosiViewBounds => LatLngBounds(
        const LatLng(-19.6450, -65.8150),
        const LatLng(-19.5350, -65.6950),
      );

  static const mapMinZoom = 13.2;
  static const mapInitialZoom = 14.4;
  static const mapMaxZoom = 15.8;
}
