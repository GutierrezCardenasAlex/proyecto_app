class AppConfig {
  static const serverScheme = String.fromEnvironment('SERVER_SCHEME', defaultValue: 'http');
  static const serverHost = String.fromEnvironment('SERVER_HOST', defaultValue: '62.171.186.246');
  static const gatewayPort = String.fromEnvironment('GATEWAY_PORT', defaultValue: '3000');
  static const websocketPort = String.fromEnvironment('WEBSOCKET_PORT', defaultValue: '3008');

  static String get apiBaseUrl => '$serverScheme://$serverHost:$gatewayPort/api';
  static String get websocketUrl => '$serverScheme://$serverHost:$websocketPort';
}
