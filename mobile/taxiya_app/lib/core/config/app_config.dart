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

  static String get apiBaseUrl => '$serverScheme://$serverHost:$gatewayPort/api';
  static String get websocketUrl => '$serverScheme://$serverHost:$websocketPort';

  static bool get canBulkDownloadTiles =>
      !mapTilesUrlTemplate.toLowerCase().contains('tile.openstreetmap.org');

  static LatLngBounds get potosiOfflineBounds => LatLngBounds(
        const LatLng(-19.4400, -65.9200),
        const LatLng(-19.7300, -65.5900),
      );
}
