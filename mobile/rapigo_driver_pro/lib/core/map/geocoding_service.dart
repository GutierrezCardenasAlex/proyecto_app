import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService(http.Client());
});

class MapLocationDetails {
  const MapLocationDetails({
    required this.primary,
    required this.secondary,
    required this.fullAddress,
  });

  final String primary;
  final String secondary;
  final String fullAddress;
}

class GeocodingService {
  GeocodingService(this._client);

  final http.Client _client;
  final Map<String, MapLocationDetails> _cache = <String, MapLocationDetails>{};

  Future<MapLocationDetails> reverseLookup(LatLng point) async {
    final cacheKey =
        '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.parse(AppConfig.mapGeocodingUrlBase).replace(
      queryParameters: <String, String>{
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      },
    );

    final response = await _client.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'FlashGo/1.0 (taxiya_app)',
        'Accept-Language': 'es',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Geocoding failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Geocoding payload invalido');
    }

    final address = decoded['address'] is Map<String, dynamic>
        ? decoded['address'] as Map<String, dynamic>
        : <String, dynamic>{};
    final road = _firstNonEmpty(address, const <String>[
      'road',
      'pedestrian',
      'footway',
      'path',
      'street',
      'residential',
      'cycleway',
      'service',
    ]);
    final area = _firstNonEmpty(address, const <String>[
      'suburb',
      'neighbourhood',
      'quarter',
      'city_district',
      'town',
      'city',
      'municipality',
      'village',
    ]);
    final houseNumber = address['house_number']?.toString().trim() ?? '';
    final displayName = decoded['display_name']?.toString().trim() ?? 'Potosi';

    final primary = road.isNotEmpty
        ? (houseNumber.isNotEmpty ? '$road $houseNumber' : road)
        : displayName.split(',').first.trim();
    final secondary = area.isNotEmpty ? area : _secondaryFromDisplayName(displayName, primary);

    final details = MapLocationDetails(
      primary: primary.isNotEmpty ? primary : 'Ubicacion actual',
      secondary: secondary.isNotEmpty ? secondary : 'Potosi',
      fullAddress: displayName,
    );
    _cache[cacheKey] = details;
    return details;
  }

  String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _secondaryFromDisplayName(String displayName, String primary) {
    final parts = displayName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part != primary)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first} · ${parts[1]}';
    }
    if (parts.isNotEmpty) {
      return parts.first;
    }
    return '';
  }
}
