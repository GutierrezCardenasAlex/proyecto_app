part of 'driver_home_page.dart';

class DriverActiveTripListener extends ConsumerStatefulWidget {
  const DriverActiveTripListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DriverActiveTripListener> createState() =>
      _DriverActiveTripListenerState();
}

class _DriverActiveTripListenerState
    extends ConsumerState<DriverActiveTripListener> {
  bool _tripFlowRouteOpen = false;
  String? _lastOpenedTripId;
  bool _initialCheckDone = false;
  bool _metadataRestored = false;

  bool _shouldOpenTripFlow(DriverTrip? trip) {
    return trip != null &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}
            .contains(trip.status);
  }

  void _handleTrip(DriverTrip? trip) {
    final previewTripId = ref.read(driverOfferPreviewTripIdProvider);
    if (previewTripId != null && trip?.id == previewTripId) {
      return;
    }
    if (!_shouldOpenTripFlow(trip)) {
      if (!_tripFlowRouteOpen) {
        _lastOpenedTripId = null;
      }
      return;
    }
    if (_tripFlowRouteOpen || !mounted || _lastOpenedTripId == trip!.id) {
      return;
    }

    _tripFlowRouteOpen = true;
    _lastOpenedTripId = trip.id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _tripFlowRouteOpen = false;
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => DriverProgressPage(
            onClosed: () {
              _tripFlowRouteOpen = false;
            },
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _tripFlowRouteOpen = false;
        });
      } else {
        _tripFlowRouteOpen = false;
      }
    });
  }

  Future<void> _restoreTripFlowFromMetadata() async {
    if (_metadataRestored) {
      return;
    }
    _metadataRestored = true;
    final cache = DriverTripStateCache();
    final metadata = await cache.readFlowMetadata();
    if (!mounted || metadata == null || !metadata.restoreProgressPage) {
      return;
    }
    final trip = ref.read(offeredTripProvider).value;
    if (trip == null || trip.id != metadata.tripId) {
      return;
    }
    _handleTrip(trip);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DriverTrip?>>(
      offeredTripProvider,
      (previous, next) => _handleTrip(next.value),
    );

    if (!_initialCheckDone) {
      _initialCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleTrip(ref.read(offeredTripProvider).value);
          unawaited(_restoreTripFlowFromMetadata());
        }
      });
    }

    return widget.child;
  }
}
