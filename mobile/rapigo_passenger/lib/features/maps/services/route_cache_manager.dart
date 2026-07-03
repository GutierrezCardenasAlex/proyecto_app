import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RouteCacheManager {
  RouteCacheManager({
    this.prefix = 'rapigo_route_cache_v1',
    this.defaultTtl = const Duration(days: 7),
  });

  final String prefix;
  final Duration defaultTtl;

  String buildKey(String rawKey) => '$prefix:$rawKey';

  Future<Map<String, dynamic>?> read(String rawKey) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(buildKey(rawKey));
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      final payload = jsonDecode(jsonString) as Map<String, dynamic>;
      final expiresAt = DateTime.tryParse(payload['expiresAt']?.toString() ?? '');
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        await prefs.remove(buildKey(rawKey));
        return null;
      }
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      await prefs.remove(buildKey(rawKey));
    }
    return null;
  }

  Future<void> write(
    String rawKey,
    Map<String, dynamic> data, {
    Duration? ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = DateTime.now().add(ttl ?? defaultTtl).toIso8601String();
    final payload = jsonEncode({
      'expiresAt': expiresAt,
      'data': data,
    });
    await prefs.setString(buildKey(rawKey), payload);
  }
}
