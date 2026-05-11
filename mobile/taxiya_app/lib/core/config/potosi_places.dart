import 'package:latlong2/latlong.dart';

class PotosiPlace {
  const PotosiPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.aliases = const [],
  });

  final String name;
  final double latitude;
  final double longitude;
  final List<String> aliases;

  LatLng get point => LatLng(latitude, longitude);

  bool matches(String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final haystacks = <String>[name, ...aliases].map(_normalize);
    return haystacks.any((candidate) => candidate.contains(normalizedQuery));
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }
}

class PotosiPlaces {
  static const List<PotosiPlace> all = [
    PotosiPlace(
      name: 'Cementerio General',
      latitude: -19.5694,
      longitude: -65.7442,
      aliases: ['cementerio', 'cementerio general potosi'],
    ),
    PotosiPlace(
      name: 'Nueva Terminal',
      latitude: -19.5568,
      longitude: -65.7426,
      aliases: ['terminal nueva', 'terminal de buses', 'nueva terminal de buses'],
    ),
    PotosiPlace(
      name: 'Villa Banzer',
      latitude: -19.5759,
      longitude: -65.7708,
      aliases: ['banzer', 'villa banzer potosi'],
    ),
    PotosiPlace(
      name: 'Mercado Uyuni',
      latitude: -19.5857,
      longitude: -65.7555,
      aliases: ['mercado uyuni potosi'],
    ),
    PotosiPlace(
      name: 'Plaza 10 de Noviembre',
      latitude: -19.5838,
      longitude: -65.7533,
      aliases: ['plaza principal', '10 de noviembre'],
    ),
    PotosiPlace(
      name: 'Hospital Daniel Bracamonte',
      latitude: -19.5752,
      longitude: -65.7566,
      aliases: ['hospital bracamonte', 'daniel bracamonte'],
    ),
    PotosiPlace(
      name: 'Universidad Tomas Frias',
      latitude: -19.5778,
      longitude: -65.7494,
      aliases: ['universidad tomas frias', 'uatf', 'tomas frias'],
    ),
    PotosiPlace(
      name: 'Casa de la Moneda',
      latitude: -19.5862,
      longitude: -65.7517,
      aliases: ['casa de moneda', 'museo casa de la moneda'],
    ),
    PotosiPlace(
      name: 'Mercado Chuquimia',
      latitude: -19.5799,
      longitude: -65.7584,
      aliases: ['chuquimia'],
    ),
    PotosiPlace(
      name: 'Villa Santiago',
      latitude: -19.5952,
      longitude: -65.7672,
      aliases: ['santiago'],
    ),
    PotosiPlace(
      name: 'Zona San Roque',
      latitude: -19.5913,
      longitude: -65.7489,
      aliases: ['san roque'],
    ),
    PotosiPlace(
      name: 'Zona Las Delicias',
      latitude: -19.5637,
      longitude: -65.7605,
      aliases: ['las delicias'],
    ),
  ];

  static List<PotosiPlace> search(String query, {int limit = 6}) {
    final results = all.where((place) => place.matches(query)).toList(growable: false);
    if (results.length <= limit) {
      return results;
    }
    return results.take(limit).toList(growable: false);
  }

  static PotosiPlace? findExact(String query) {
    final normalized = PotosiPlace._normalize(query);
    if (normalized.isEmpty) {
      return null;
    }
    for (final place in all) {
      final candidates = [place.name, ...place.aliases].map(PotosiPlace._normalize);
      if (candidates.contains(normalized)) {
        return place;
      }
    }
    return null;
  }
}
