import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final navigationServiceProvider = Provider<NavigationService>((ref) {
  return const NavigationService();
});

enum NavigationProvider { rapigo, waze, googleMaps }

enum NavigationPreference { askAlways, rapigo, waze, googleMaps }

class NavigationTarget {
  const NavigationTarget({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class NavigationLaunchResult {
  const NavigationLaunchResult({
    required this.provider,
    required this.openedExternalApp,
    this.usedFallback = false,
  });

  final NavigationProvider provider;
  final bool openedExternalApp;
  final bool usedFallback;
}

class NavigationService {
  const NavigationService();

  static const String _preferenceKey = 'rapigo_driver_navigation_preference_v1';

  Future<NavigationPreference> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferenceKey);
    return NavigationPreference.values.firstWhere(
      (preference) => preference.name == raw,
      orElse: () => NavigationPreference.askAlways,
    );
  }

  Future<void> savePreference(NavigationPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, preference.name);
  }

  NavigationProvider? providerForPreference(NavigationPreference preference) {
    return switch (preference) {
      NavigationPreference.askAlways => null,
      NavigationPreference.rapigo => NavigationProvider.rapigo,
      NavigationPreference.waze => NavigationProvider.waze,
      NavigationPreference.googleMaps => NavigationProvider.googleMaps,
    };
  }

  Future<bool> isProviderAvailable(NavigationProvider provider) async {
    return switch (provider) {
      NavigationProvider.rapigo => true,
      NavigationProvider.waze => canLaunchUrl(Uri.parse('waze://')),
      NavigationProvider.googleMaps => canLaunchUrl(
        Uri.parse('google.navigation:q=0,0&mode=d'),
      ),
    };
  }

  Future<List<NavigationProvider>> availableProviders() async {
    final providers = <NavigationProvider>[NavigationProvider.rapigo];
    if (await isProviderAvailable(NavigationProvider.waze)) {
      providers.add(NavigationProvider.waze);
    }
    if (await isProviderAvailable(NavigationProvider.googleMaps)) {
      providers.add(NavigationProvider.googleMaps);
    }
    return providers;
  }

  Future<NavigationLaunchResult> launch(
    NavigationProvider provider,
    NavigationTarget target,
  ) async {
    if (provider == NavigationProvider.rapigo) {
      return const NavigationLaunchResult(
        provider: NavigationProvider.rapigo,
        openedExternalApp: false,
      );
    }

    if (!await isProviderAvailable(provider)) {
      return const NavigationLaunchResult(
        provider: NavigationProvider.rapigo,
        openedExternalApp: false,
        usedFallback: true,
      );
    }

    final uri = switch (provider) {
      NavigationProvider.rapigo => null,
      NavigationProvider.waze => Uri.parse(
        'waze://?ll=${target.latitude},${target.longitude}&navigate=yes',
      ),
      NavigationProvider.googleMaps => Uri.parse(
        'google.navigation:q=${target.latitude},${target.longitude}&mode=d',
      ),
    };

    final opened = uri != null
        ? await launchUrl(uri, mode: LaunchMode.externalApplication)
        : false;
    if (opened) {
      return NavigationLaunchResult(
        provider: provider,
        openedExternalApp: true,
      );
    }
    return const NavigationLaunchResult(
      provider: NavigationProvider.rapigo,
      openedExternalApp: false,
      usedFallback: true,
    );
  }
}

extension NavigationProviderLabels on NavigationProvider {
  String get label {
    return switch (this) {
      NavigationProvider.rapigo => 'RAPIGO',
      NavigationProvider.waze => 'Waze',
      NavigationProvider.googleMaps => 'Google Maps',
    };
  }

  String get description {
    return switch (this) {
      NavigationProvider.rapigo => 'Mapa interno con MapLibre y OSRM',
      NavigationProvider.waze => 'Abrir solo la ruta en Waze',
      NavigationProvider.googleMaps => 'Abrir solo la ruta en Google Maps',
    };
  }
}

extension NavigationPreferenceLabels on NavigationPreference {
  String get label {
    return switch (this) {
      NavigationPreference.askAlways => 'Preguntar siempre',
      NavigationPreference.rapigo => 'RAPIGO',
      NavigationPreference.waze => 'Waze',
      NavigationPreference.googleMaps => 'Google Maps',
    };
  }
}
