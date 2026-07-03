import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

final networkStatusProvider =
    NotifierProvider<NetworkStatusController, NetworkStatusState>(
      NetworkStatusController.new,
    );

class NetworkStatusState {
  const NetworkStatusState({
    this.isOnline = true,
    this.isChecking = false,
    this.lastCheckedAt,
    this.errorMessage,
  });

  final bool isOnline;
  final bool isChecking;
  final DateTime? lastCheckedAt;
  final String? errorMessage;

  NetworkStatusState copyWith({
    bool? isOnline,
    bool? isChecking,
    DateTime? lastCheckedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NetworkStatusState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NetworkStatusController extends Notifier<NetworkStatusState> {
  Timer? _pollTimer;
  bool _started = false;

  @override
  NetworkStatusState build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
    });
    return const NetworkStatusState();
  }

  Future<void> startMonitoring() async {
    if (_started) {
      return;
    }
    _started = true;
    await refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 18), (_) {
      unawaited(refresh(silent: true));
    });
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isChecking: true, clearError: true);
    }
    final isOnline = await _probeConnection();
    state = state.copyWith(
      isOnline: isOnline,
      isChecking: false,
      lastCheckedAt: DateTime.now(),
      errorMessage: isOnline ? null : 'Sin internet',
      clearError: isOnline,
    );
  }

  Future<bool> _probeConnection() async {
    try {
      final lookup = await InternetAddress.lookup(
        AppConfig.serverHost,
      ).timeout(const Duration(seconds: 3));
      if (lookup.isEmpty || lookup.first.rawAddress.isEmpty) {
        return false;
      }
    } catch (_) {
      return false;
    }

    final candidates = <Uri>[
      Uri.parse('${AppConfig.serverScheme}://${AppConfig.serverHost}'),
      Uri.parse('https://tiles.openfreemap.org/'),
    ];

    for (final uri in candidates) {
      try {
        final response = await http
            .get(uri, headers: const {'Accept': 'text/plain'})
            .timeout(const Duration(seconds: 4));
        if (response.statusCode > 0 && response.statusCode < 500) {
          if (kDebugMode) {
            debugPrint(
              '[RAPIGO_PRO][network] online via ${uri.host} (${response.statusCode})',
            );
          }
          return true;
        }
      } catch (_) {
        continue;
      }
    }

    return false;
  }
}
