import 'package:flutter/services.dart';

class MapStyleCache {
  MapStyleCache._();

  static final Map<String, String> _memory = <String, String>{};

  static Future<String> preload(String assetPath) async {
    final cached = _memory[assetPath];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final raw = await rootBundle.loadString(assetPath);
    _memory[assetPath] = raw;
    return raw;
  }

  static String? get(String assetPath) => _memory[assetPath];
}
