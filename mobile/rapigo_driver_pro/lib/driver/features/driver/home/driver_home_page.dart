import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/driver_login_card.dart';
import '../../auth/presentation/driver_profile_completion_page.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/data/trip_state_cache.dart';
import '../../trip/domain/driver_trip.dart';
import '../../../../core/config/app_config.dart' as shared_config;
import '../../../core/notifications/local_notifications.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/map/geocoding_service.dart';
import '../../../../core/ui/top_notice.dart';
import '../presentation/driver_progress_page.dart';
import '../presentation/pages/driver_detail_pages.dart';
import '../presentation/route_persistence_keys.dart';
import '../presentation/widgets/driver_ui_kit.dart';
import '../../map/presentation/driver_map_surface.dart';
import '../data/driver_repository.dart';
import 'driver_initial_bootstrap.dart';

part '../presentation/driver_home_page.dart';
part 'driver_session_gate.dart';
part 'driver_shell.dart';
part 'driver_bottom_nav.dart';
part 'driver_active_trip_listener.dart';
part 'driver_socket_listener.dart';
part 'driver_dashboard.dart';
part '../presentation/pages/driver_offer_route_preview_page.dart';
part 'tabs/driver_trips_tab.dart';
part 'tabs/driver_orders_tab.dart';
part 'tabs/driver_account_tab.dart';
part 'widgets/driver_loading_splash.dart';
part 'widgets/device_blocked_view.dart';
part 'widgets/pending_authorization_view.dart';

final driverOfferPreviewTripIdProvider =
    NotifierProvider<DriverOfferPreviewTripIdController, String?>(
      DriverOfferPreviewTripIdController.new,
    );

class DriverOfferPreviewTripIdController extends Notifier<String?> {
  late final DriverTripStateCache _cache;
  bool _restoredPersistedPreviewTripId = false;

  @override
  String? build() {
    _cache = DriverTripStateCache();
    if (!_restoredPersistedPreviewTripId) {
      _restoredPersistedPreviewTripId = true;
      Future<void>.microtask(_restorePersistedPreviewTripId);
    }
    return null;
  }

  Future<void> _restorePersistedPreviewTripId() async {
    final cached = await _cache.readPreviewTripId();
    if (cached == null) {
      return;
    }
    state = cached;
  }

  void setTrip(String? tripId) {
    state = tripId;
    unawaited(_cache.writePreviewTripId(tripId));
  }
}

class DriverHomePage extends StatelessWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverSessionGate();
  }
}
