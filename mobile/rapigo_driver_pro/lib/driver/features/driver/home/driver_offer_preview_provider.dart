import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trip/data/trip_state_cache.dart';

final driverOfferPreviewTripIdProvider =
    NotifierProvider<DriverOfferPreviewTripIdController, String?>(
      DriverOfferPreviewTripIdController.new,
    );

final driverSuppressIncomingOfferOverlayProvider =
    NotifierProvider<DriverSuppressIncomingOfferOverlayController, bool>(
      DriverSuppressIncomingOfferOverlayController.new,
    );

final driverIgnoredIncomingTripIdProvider =
    NotifierProvider<DriverIgnoredIncomingTripIdController, String?>(
      DriverIgnoredIncomingTripIdController.new,
    );

final driverHomeResumeOverlayProvider =
    NotifierProvider<DriverHomeResumeOverlayController, bool>(
      DriverHomeResumeOverlayController.new,
    );

class DriverSuppressIncomingOfferOverlayController extends Notifier<bool> {
  @override
  bool build() => false;

  void suppressOnce() => state = true;

  void clear() => state = false;
}

class DriverIgnoredIncomingTripIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void ignore(String? tripId) => state = tripId;

  void clear() => state = null;
}

class DriverHomeResumeOverlayController extends Notifier<bool> {
  @override
  bool build() => false;

  void showOnce() => state = true;

  void clear() => state = false;
}

class DriverOfferPreviewTripIdController extends Notifier<String?> {
  final DriverTripStateCache _cache = DriverTripStateCache();
  bool _restoredPersistedPreviewTripId = false;

  @override
  String? build() {
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
