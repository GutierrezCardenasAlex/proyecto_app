class AppConfig {
  static const serverScheme = String.fromEnvironment('SERVER_SCHEME', defaultValue: 'http');
  static const serverHost = String.fromEnvironment(
    'SERVER_HOST',
    defaultValue: '62.171.186.246',
  );
  static const gatewayPort = String.fromEnvironment('GATEWAY_PORT', defaultValue: '3000');
  static const websocketPort = String.fromEnvironment('WEBSOCKET_PORT', defaultValue: '3008');
  static const websocketScheme = String.fromEnvironment('WEBSOCKET_SCHEME', defaultValue: '');

  static String get apiBaseUrl =>
      '$serverScheme://$serverHost${_formatPort(serverScheme, gatewayPort)}/api';
  static String get websocketUrl {
    final resolvedScheme = websocketScheme.trim().isNotEmpty
        ? websocketScheme.trim()
        : (serverScheme == 'https' ? 'wss' : 'ws');
    return '$resolvedScheme://$serverHost${_formatPort(resolvedScheme, websocketPort)}';
  }

  static String _formatPort(String scheme, String port) {
    final normalized = port.trim();
    if (normalized.isEmpty) return '';
    if ((scheme == 'http' || scheme == 'ws') && normalized == '80') {
      return '';
    }
    if ((scheme == 'https' || scheme == 'wss') && normalized == '443') {
      return '';
    }
    return ':$normalized';
  }
}
