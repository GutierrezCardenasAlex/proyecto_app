// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../auth/data/auth_repository.dart';
import '../../../../core/ui/top_notice.dart';
import '../../../map/data/location_controller.dart';
import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import '../widgets/route_review_view.dart';
import '../widgets/trip_status_banner.dart';

enum TakeTaxiPageAction { back, edit, clear, journey }

class TakeTaxiPage extends ConsumerStatefulWidget {
  const TakeTaxiPage({
    super.key,
    required this.drivers,
    required this.nearbyDrivers,
    required this.userLocation,
    required this.userAccuracyMeters,
    required this.userHeadingDegrees,
    required this.routeTarget,
    required this.routeColor,
    required this.focusSignal,
    required this.serviceType,
    required this.originLabel,
    required this.destinationLabel,
    required this.distanceMeters,
    required this.proposedFareAmount,
    required this.paymentMethod,
    required this.selectedDriverId,
    required this.onSelectDriver,
    required this.onFareChanged,
    required this.onPaymentMethodChanged,
    required this.onClearDestination,
    required this.onSelectTaxi,
    required this.onSelectMoto,
    required this.onRequest,
    required this.onRetry,
    required this.onCancel,
  });

  final List<PotosiMapDriverMarker> drivers;
  final List<NearbyDriver> nearbyDrivers;
  final LatLng userLocation;
  final double? userAccuracyMeters;
  final double? userHeadingDegrees;
  final LatLng? routeTarget;
  final Color routeColor;
  final int focusSignal;
  final String serviceType;
  final String originLabel;
  final String destinationLabel;
  final double distanceMeters;
  final double proposedFareAmount;
  final String paymentMethod;
  final String? selectedDriverId;
  final ValueChanged<String> onSelectDriver;
  final ValueChanged<double> onFareChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final Future<bool> Function() onClearDestination;
  final VoidCallback onSelectTaxi;
  final VoidCallback onSelectMoto;
  final Future<void> Function() onRequest;
  final Future<void> Function() onRetry;
  final Future<bool> Function() onCancel;

  @override
  ConsumerState<TakeTaxiPage> createState() => _TakeTaxiPageState();
}

class _TakeTaxiPageState extends ConsumerState<TakeTaxiPage> {
  late String _serviceType = widget.serviceType;
  late String? _chosenDriverId = widget.selectedDriverId;

  void _chooseDriver(String id) {
    if (!mounted) return;
    setState(() => _chosenDriverId = id);
    widget.onSelectDriver(id);
  }

  late double _proposedFareAmount = widget.proposedFareAmount;
  late String _paymentMethod = widget.paymentMethod == 'qr' ? 'qr' : 'cash';
  bool _detailsExpanded = false;
  bool _takeTaxiDrawerExpanded = true;
  Timer? _nearbyRefreshTimer;
  int _mapCenterSignal = 0;

  @override
  void initState() {
    super.initState();
    _startNearbyRefreshLoop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final firstDriver = _filteredDrivers.isEmpty
          ? null
          : _filteredDrivers.first;
      if ((_chosenDriverId == null || _chosenDriverId!.isEmpty) &&
          firstDriver != null) {
        _chooseDriver(firstDriver.driverId);
      }
    });
  }

  @override
  void dispose() {
    _nearbyRefreshTimer?.cancel();
    super.dispose();
  }

  void _selectTaxi() {
    if (!mounted) {
      return;
    }
    widget.onSelectTaxi();
    setState(() {
      _serviceType = 'taxi';
    });
  }

  void _selectMoto() {
    if (!mounted) {
      return;
    }
    widget.onSelectMoto();
    setState(() {
      _serviceType = 'moto';
    });
  }

  String get _durationLabel {
    final metersPerSecond = _serviceType == 'moto' ? 6.5 : 5.5;
    final durationMinutes = ((widget.distanceMeters / metersPerSecond) / 60)
        .round()
        .clamp(3, 90);
    return '$durationMinutes min';
  }

  String get _distanceLabel {
    final distanceKm = widget.distanceMeters / 1000;
    return distanceKm < 1
        ? '${widget.distanceMeters.round()} m'
        : '${distanceKm.toStringAsFixed(1)} km';
  }

  String get _summaryLabel => '$_durationLabel · $_distanceLabel';

  String get _paymentMethodLabel => _paymentMethod == 'qr' ? 'QR' : 'Efectivo';

  void _changeFare(double delta) {
    final nextFare = (_proposedFareAmount + delta).clamp(1, 999).toDouble();
    setState(() {
      _proposedFareAmount = nextFare;
    });
    widget.onFareChanged(nextFare);
  }

  void _selectPaymentMethod(String method) {
    final normalized = method == 'qr' ? 'qr' : 'cash';
    setState(() {
      _paymentMethod = normalized;
    });
    widget.onPaymentMethodChanged(normalized);
  }

  List<NearbyDriver> get _liveNearbyDrivers {
    final liveNearbyDrivers = ref.read(tripProvider).nearbyDrivers;
    if (liveNearbyDrivers.isNotEmpty) {
      return liveNearbyDrivers;
    }
    return widget.nearbyDrivers;
  }

  List<NearbyDriver> get _filteredDrivers {
    final selectedType = _serviceType == 'moto' ? 'moto' : 'taxi';
    final matching = _liveNearbyDrivers.where((driver) {
      final vehicleType = driver.vehicleType.trim().toLowerCase();
      if (selectedType == 'moto') {
        return vehicleType == 'moto';
      }
      return vehicleType != 'moto';
    }).toList();
    if (matching.isNotEmpty) {
      matching.sort((a, b) {
        final etaCompare = a.etaMinutes.compareTo(b.etaMinutes);
        if (etaCompare != 0) {
          return etaCompare;
        }
        return a.distanceMeters.compareTo(b.distanceMeters);
      });
      return matching;
    }
    final fallback = [..._liveNearbyDrivers];
    fallback.sort((a, b) {
      final etaCompare = a.etaMinutes.compareTo(b.etaMinutes);
      if (etaCompare != 0) {
        return etaCompare;
      }
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return fallback;
  }

  String? get _highlightedDriverId {
    final selectedId = _chosenDriverId;
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }
    return _filteredDrivers.isEmpty ? null : _filteredDrivers.first.driverId;
  }

  NearbyDriver? get _selectedDriver {
    final selectedId = _chosenDriverId;
    if (selectedId == null || selectedId.isEmpty) {
      return _filteredDrivers.isEmpty ? null : _filteredDrivers.first;
    }
    for (final driver in _filteredDrivers) {
      if (driver.driverId == selectedId) {
        return driver;
      }
    }
    return _filteredDrivers.isEmpty ? null : _filteredDrivers.first;
  }

  int get _selectedDriverIndex {
    final selectedId = _chosenDriverId;
    if (selectedId == null || selectedId.isEmpty) {
      return 0;
    }
    final index = _filteredDrivers.indexWhere(
      (driver) => driver.driverId == selectedId,
    );
    return index < 0 ? 0 : index;
  }

  void _selectDriverAt(int index) {
    if (index < 0 || index >= _filteredDrivers.length) {
      return;
    }
    _chooseDriver(_filteredDrivers[index].driverId);
  }

  void _startNearbyRefreshLoop() {
    _refreshNearbyDrivers();
    _nearbyRefreshTimer?.cancel();
    _nearbyRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _refreshNearbyDrivers();
    });
  }

  Future<void> _refreshNearbyDrivers() async {
    final session = ref.read(sessionProvider);
    if (session.token.isEmpty || session.userId.isEmpty) {
      return;
    }
    final liveLocation =
        ref.read(passengerLocationProvider).position ?? widget.userLocation;
    await ref
        .read(tripProvider.notifier)
        .loadDashboard(
          token: session.token,
          passengerId: session.userId,
          userLocation: liveLocation,
        );
  }

  ({String color, String plate}) _vehicleMeta(NearbyDriver driver) {
    final parts = driver.vehicleDetail
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return (
      color: parts.isNotEmpty ? parts.first : 'Color por confirmar',
      plate: parts.length > 1 ? parts[1] : 'Sin placa',
    );
  }

  bool _requestIsActive(String status) {
    return const {
      'requested',
      'searching',
      'accepted',
      'arriving',
      'at_pickup',
      'in_progress',
    }.contains(status);
  }

  Future<void> _handleRequestAndContinue() async {
    await widget.onRequest();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleBack(String status) async {
    if (ref.read(tripProvider).isRequestingTrip) {
      showTopNotice(
        context,
        'Espera mientras se envía tu solicitud.',
        title: 'Enviando solicitud',
      );
      return;
    }
    if (_requestIsActive(status)) {
      showTopNotice(
        context,
        'Tu viaje sigue activo. Revisa los detalles o cancela la solicitud para salir.',
        title: 'Viaje activo',
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(TakeTaxiPageAction.back);
  }

  Future<void> _handleCancel() async {
    final cancelled = await widget.onCancel();
    if (!mounted) {
      return;
    }
    if (cancelled) {
      Navigator.of(context).pop(TakeTaxiPageAction.back);
    }
  }

  Future<void> _handleClearDestination() async {
    final cleared = await widget.onClearDestination();
    if (!mounted) {
      return;
    }
    if (cleared) {
      Navigator.of(context).pop(TakeTaxiPageAction.clear);
    }
  }

  void _toggleDetails() {
    setState(() {
      _detailsExpanded = !_detailsExpanded;
    });
  }

  void _showDriverDetails(NearbyDriver driver) {
    _chooseDriver(driver.driverId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final vehicleIcon = driver.vehicleType.trim().toLowerCase() == 'moto'
            ? Icons.two_wheeler_rounded
            : Icons.directions_car_filled_rounded;
        final meta = _vehicleMeta(driver);
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: const BoxDecoration(
              color: Color(0xFF0A2340),
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF102B4A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1D4ED8)),
                      ),
                      child: Icon(
                        vehicleIcon,
                        color: const Color(0xFFFACC15),
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.vehicleLabel.isEmpty
                                ? 'Vehículo cercano'
                                : driver.vehicleLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Unidad disponible cerca de ti',
                            style: TextStyle(
                              color: Color(0xFFD7E4F3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DetailPill(
                                icon: Icons.schedule_rounded,
                                label: '${driver.etaMinutes} min',
                              ),
                              _DetailPill(
                                icon: Icons.star_rounded,
                                label: driver.rating.toStringAsFixed(1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SpotlightMetricChip(
                        icon: Icons.badge_outlined,
                        label: 'Placa',
                        value: meta.plate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SpotlightMetricChip(
                        icon: Icons.palette_outlined,
                        label: 'Color',
                        value: meta.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SpotlightMetricChip(
                        icon: Icons.route_rounded,
                        label: 'Distancia',
                        value:
                            '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SpotlightMetricChip(
                        icon: Icons.schedule_rounded,
                        label: 'Llegada',
                        value: '${driver.etaMinutes} min',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFFACC15),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Usar este vehículo'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _nearbyTaxiBadges(List<NearbyDriver> drivers) {
    const placements = <({double? left, double? right, double top})>[
      (left: 84, right: null, top: 430),
      (left: null, right: 138, top: 300),
      (left: null, right: 54, top: 448),
    ];

    return <Widget>[
      for (
        var index = 0;
        index < drivers.length && index < placements.length;
        index++
      )
        Positioned(
          left: placements[index].left,
          right: placements[index].right,
          top: placements[index].top,
          child: _NearbyTaxiMapBadge(
            driver: drivers[index],
            selected: drivers[index].driverId == _highlightedDriverId,
            onTap: () {
              _chooseDriver(drivers[index].driverId);
              _showDriverDetails(drivers[index]);
            },
          ),
        ),
    ];
  }

  void _openNearestTaxiPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final drivers = _filteredDrivers;
        return SafeArea(
          top: false,
          child: _NearestTaxiPickerSheet(
            drivers: drivers,
            selectedDriverId: _highlightedDriverId,
            onSelectDriver: (driver) {
              _chooseDriver(driver.driverId);
              Navigator.of(context).pop();
            },
            onShowMap: () {
              Navigator.of(context).pop();
              setState(() => _mapCenterSignal++);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    ref.watch(tripProvider.select((state) => state.nearbyDrivers));
    final request = tripState.request;
    final status = request.status;
    // The owning RideTab presents a single completion summary and resets the trip.
    final activeMapDrivers = _liveNearbyDrivers.isNotEmpty
        ? _liveNearbyDrivers
              .map(
                (driver) => PotosiMapDriverMarker(
                  point: LatLng(driver.lat, driver.lng),
                  driverId: driver.driverId,
                  vehicleType: driver.vehicleType,
                  isHighlighted: driver.driverId == _highlightedDriverId,
                ),
              )
              .toList(growable: false)
        : widget.drivers;

    final title = switch (status) {
      'requested' || 'searching' => 'Solicitud enviada',
      'accepted' || 'arriving' || 'at_pickup' || 'in_progress' => 'Tu viaje',
      _ => 'Tomar taxi',
    };

    final statusText = switch (status) {
      'requested' || 'searching' => 'Esperando respuesta del conductor',
      'accepted' => 'Conductor asignado',
      'arriving' => 'Conductor en camino',
      'at_pickup' => 'Conductor llegó a recogerte',
      'in_progress' => 'Viaje en curso',
      _ => null,
    };

    final statusAccent = switch (status) {
      'requested' || 'searching' => const Color(0xFF1D4ED8),
      'accepted' || 'arriving' => const Color(0xFFF97316),
      'at_pickup' => const Color(0xFF0EA5E9),
      'in_progress' => const Color(0xFF16A34A),
      _ => const Color(0xFF1D4ED8),
    };

    final details = <String>[
      if (_requestIsActive(status)) _summaryLabel,
      if (_requestIsActive(status))
        'Bs ${(request.fareAmount ?? _proposedFareAmount).toStringAsFixed(2)} · ${request.paymentMethod == 'qr' ? 'QR' : 'Efectivo'}',
      if ((request.driverName ?? '').trim().isNotEmpty)
        request.driverName!.trim(),
      if (request.etaMinutes != null) '${request.etaMinutes} min',
    ];

    final secondaryActions = <RouteReviewActionData>[
      if (status == 'requested' || status == 'searching')
        RouteReviewActionData(label: 'Cancelar', onTap: _handleCancel),
      if (status == 'requested' ||
          status == 'searching' ||
          status == 'accepted' ||
          status == 'arriving' ||
          status == 'at_pickup')
        RouteReviewActionData(
          label: 'Editar destino',
          onTap: () => Navigator.of(context).pop(TakeTaxiPageAction.edit),
        ),
    ];

    final primaryActionLabel = switch (status) {
      'requested' || 'searching' => 'Volver a solicitar',
      'accepted' || 'arriving' || 'at_pickup' => 'Cancelar viaje',
      'in_progress' => 'Viaje en curso',
      _ => 'Solicitar taxi',
    };

    final primaryAction = switch (status) {
      'requested' || 'searching' => widget.onRetry,
      'accepted' || 'arriving' || 'at_pickup' => _handleCancel,
      'in_progress' => null,
      _ => _handleRequestAndContinue,
    };

    final selectedDriver = _selectedDriver;
    final requestActive = _requestIsActive(status);
    final destinationReady =
        widget.destinationLabel.trim().isNotEmpty &&
        widget.destinationLabel != TripRepository.destinationPendingLabel;
    final liveUserLocation =
        ref.watch(passengerLocationProvider).position ?? widget.userLocation;
    final liveAccuracyMeters =
        ref.watch(passengerLocationProvider).accuracyMeters ??
        widget.userAccuracyMeters;
    final liveHeadingDegrees =
        ref.watch(passengerLocationProvider).headingDegrees ??
        widget.userHeadingDegrees;
    final driverPoint = request.driverLat != null && request.driverLng != null
        ? LatLng(request.driverLat!, request.driverLng!)
        : null;
    final pickupPoint = request.pickupLat != null && request.pickupLng != null
        ? LatLng(request.pickupLat!, request.pickupLng!)
        : liveUserLocation;
    final destinationPoint =
        request.destinationLat != null && request.destinationLng != null
        ? LatLng(request.destinationLat!, request.destinationLng!)
        : widget.routeTarget;
    final visibleTarget = requestActive
        ? (status == 'in_progress' ? destinationPoint : pickupPoint)
        : widget.routeTarget;
    final nearbyCount = _filteredDrivers.length;
    final screenPadding = MediaQuery.paddingOf(context);
    const horizontalInset = 16.0;
    const bottomInset = 12.0;
    return PopScope<TakeTaxiPageAction>(
      canPop: !requestActive && !tripState.isRequestingTrip,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack(status);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: PotosiMapSurface(
                viewportCacheKey: 'passenger_take_taxi',
                drivers: activeMapDrivers,
                userLocation: liveUserLocation,
                userAccuracyMeters: liveAccuracyMeters,
                userHeadingDegrees: liveHeadingDegrees,
                userMarkerAccentColor: const Color(0xFFFACC15),
                userMarkerHaloColor: const Color(0xFFFACC15),
                userMarkerBorderColor: const Color(0xFFFFF2A8),
                routeStart: requestActive ? driverPoint : null,
                routeTarget: visibleTarget,
                showRoute:
                    visibleTarget != null &&
                    (!requestActive || driverPoint != null),
                showTargetMarker: visibleTarget != null,
                routeColor: widget.routeColor,
                focusSignal: widget.focusSignal,
                cameraCenterTarget: liveUserLocation,
                cameraCenterSignal: _mapCenterSignal,
                showUtilityControls: false,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: screenPadding.top + 12,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: const Color(0x180F172A),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: () => _handleBack(status),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              requestActive
                                  ? (statusText ?? 'Tu viaje')
                                  : '$nearbyCount vehículos cerca de ti',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Centrar mapa',
                        onPressed: () => setState(() => _mapCenterSignal++),
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: horizontalInset,
              right: horizontalInset,
              bottom: bottomInset,
              child: SafeArea(
                top: false,
                child: requestActive
                    ? _ActiveTripStatusCard(
                        tripStatus: status,
                        title: title,
                        statusText: statusText ?? 'Esperando taxi',
                        statusAccent: statusAccent,
                        summaryLabel: _summaryLabel,
                        details: details,
                        driverName: (request.driverName ?? '').trim(),
                        vehicleLabel:
                            request.vehicleLabel ??
                            selectedDriver?.vehicleLabel ??
                            '',
                        vehicleDetail: [
                          if ((request.vehicleColor ?? '').trim().isNotEmpty)
                            request.vehicleColor!.trim(),
                          if ((request.vehiclePlate ?? '').trim().isNotEmpty)
                            request.vehiclePlate!.trim(),
                        ].join(' · '),
                        etaLabel: request.etaMinutes == null
                            ? null
                            : '${request.etaMinutes} min',
                        primaryActionLabel: tripState.isRequestingTrip
                            ? 'Procesando...'
                            : primaryActionLabel,
                        onPrimaryAction: tripState.isRequestingTrip
                            ? null
                            : primaryAction,
                        secondaryActions: secondaryActions,
                        detailsExpanded: _detailsExpanded,
                        onToggleDetails: _toggleDetails,
                      )
                    : _TakeTaxiCleanSheet(
                        nearbyCount: nearbyCount,
                        nearbyDrivers: _filteredDrivers,
                        selectedDriverId: _highlightedDriverId,
                        expanded: _takeTaxiDrawerExpanded,
                        destinationReady: destinationReady,
                        destinationLabel: widget.destinationLabel,
                        fareAmount: _proposedFareAmount,
                        paymentMethodLabel: _paymentMethodLabel,
                        paymentMethod: _paymentMethod,
                        isRequesting: tripState.isRequestingTrip,
                        primaryActionLabel: destinationReady
                            ? primaryActionLabel
                            : 'Elegir destino',
                        onPrimary: tripState.isRequestingTrip
                            ? null
                            : (destinationReady
                                  ? primaryAction
                                  : () async => Navigator.of(
                                      context,
                                    ).pop(TakeTaxiPageAction.edit)),
                        onChooseDestination: () =>
                            Navigator.of(context).pop(TakeTaxiPageAction.edit),
                        onClearDestination: destinationReady
                            ? () => unawaited(_handleClearDestination())
                            : null,
                        onDecreaseFare: () => _changeFare(-1),
                        onIncreaseFare: () => _changeFare(1),
                        onSelectPaymentMethod: _selectPaymentMethod,
                        onShowNearby: () => setState(() => _mapCenterSignal++),
                        onRefresh: _refreshNearbyDrivers,
                        onToggleExpanded: () {
                          setState(() {
                            _takeTaxiDrawerExpanded = !_takeTaxiDrawerExpanded;
                          });
                        },
                        onSelectDriver: (driver) {
                          _chooseDriver(driver.driverId);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyTaxiHeroBanner extends StatelessWidget {
  const _NearbyTaxiHeroBanner({required this.nearbyCount, required this.onTap});

  final int nearbyCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B3B72).withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(999),
      elevation: 10,
      shadowColor: const Color(0x33020B18),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFACC15),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Color(0xFF0B1220),
                  size: 20,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(
                  child: Text(
                    nearbyCount.toString(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1D4ED8),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyTaxiMapBadge extends StatelessWidget {
  const _NearbyTaxiMapBadge({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  final NearbyDriver driver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meters = driver.distanceMeters.round();
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 14,
                  offset: Offset(0, 7),
                ),
              ],
              border: selected
                  ? Border.all(color: const Color(0xFF22C55E), width: 1.5)
                  : null,
            ),
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF0F172A)),
                    children: [
                      TextSpan(
                        text: driver.etaMinutes.toString(),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(
                        text: ' min',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$meters m',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ClipPath(
            clipper: _MapBadgePointerClipper(),
            child: Container(
              width: 18,
              height: 10,
              color: Colors.white.withValues(alpha: 0.97),
            ),
          ),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFBBF7D0).withValues(alpha: 0.62),
              boxShadow: const [
                BoxShadow(color: Color(0x5522C55E), blurRadius: 28),
              ],
            ),
            child: Center(
              child: Transform.rotate(
                angle: selected ? -0.72 : -0.55,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFF0F172A), width: 1.4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x330F172A),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: Color(0xFF101827),
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBadgePointerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TakeTaxiCleanSheet extends StatelessWidget {
  const _TakeTaxiCleanSheet({
    required this.nearbyCount,
    required this.nearbyDrivers,
    required this.selectedDriverId,
    required this.expanded,
    required this.destinationReady,
    required this.destinationLabel,
    required this.fareAmount,
    required this.paymentMethodLabel,
    required this.paymentMethod,
    required this.isRequesting,
    required this.primaryActionLabel,
    required this.onPrimary,
    required this.onChooseDestination,
    required this.onClearDestination,
    required this.onDecreaseFare,
    required this.onIncreaseFare,
    required this.onSelectPaymentMethod,
    required this.onShowNearby,
    required this.onRefresh,
    required this.onToggleExpanded,
    required this.onSelectDriver,
  });

  final int nearbyCount;
  final List<NearbyDriver> nearbyDrivers;
  final String? selectedDriverId;
  final bool expanded;
  final bool destinationReady;
  final String destinationLabel;
  final double fareAmount;
  final String paymentMethodLabel;
  final String paymentMethod;
  final bool isRequesting;
  final String primaryActionLabel;
  final Future<void> Function()? onPrimary;
  final VoidCallback onChooseDestination;
  final VoidCallback? onClearDestination;
  final VoidCallback onDecreaseFare;
  final VoidCallback onIncreaseFare;
  final ValueChanged<String> onSelectPaymentMethod;
  final VoidCallback onShowNearby;
  final VoidCallback onRefresh;
  final VoidCallback onToggleExpanded;
  final ValueChanged<NearbyDriver> onSelectDriver;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final canRequest =
        !isRequesting &&
        onPrimary != null &&
        (!destinationReady || nearbyDrivers.isNotEmpty);
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x220F172A),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: height * (height < 500 ? 0.55 : 0.62),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Prepara tu viaje',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar vehículos',
                    onPressed: onRefresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  IconButton(
                    tooltip: expanded ? 'Ver más mapa' : 'Mostrar detalles',
                    onPressed: onToggleExpanded,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                    ),
                  ),
                ],
              ),
            ),
            if (expanded)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TakeTaxiStepLabel(
                        number: '1',
                        title: 'Elige tu vehículo',
                      ),
                      const SizedBox(height: 12),
                      if (nearbyDrivers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'No hay vehículos disponibles por ahora. Puedes actualizar la búsqueda.',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              height: 1.5,
                            ),
                          ),
                        )
                      else
                        ...nearbyDrivers.map(
                          (driver) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TakeTaxiDriverChoiceTile(
                              driver: driver,
                              selected: driver.driverId == selectedDriverId,
                              compact: true,
                              onTap: () => onSelectDriver(driver),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const _TakeTaxiStepLabel(
                        number: '2',
                        title: 'Indica tu destino',
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: onChooseDestination,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xFF1D4ED8),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    destinationReady
                                        ? destinationLabel
                                        : '¿A dónde quieres ir?',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF475569),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (onClearDestination != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onClearDestination,
                            child: const Text('Quitar destino'),
                          ),
                        ),
                      const SizedBox(height: 20),
                      const _TakeTaxiStepLabel(
                        number: '3',
                        title: 'Oferta y forma de pago',
                      ),
                      const SizedBox(height: 12),
                      _FareAndPaymentPanel(
                        fareAmount: fareAmount,
                        paymentMethod: paymentMethod,
                        paymentMethodLabel: paymentMethodLabel,
                        onDecreaseFare: onDecreaseFare,
                        onIncreaseFare: onIncreaseFare,
                        onSelectPaymentMethod: onSelectPaymentMethod,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canRequest ? () => onPrimary!() : null,
                  icon: Icon(
                    destinationReady
                        ? Icons.local_taxi_rounded
                        : Icons.search_rounded,
                  ),
                  label: Text(
                    isRequesting
                        ? 'Enviando solicitud…'
                        : destinationReady && nearbyDrivers.isEmpty
                        ? 'Sin vehículos disponibles'
                        : primaryActionLabel,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TakeTaxiStepLabel extends StatelessWidget {
  const _TakeTaxiStepLabel({required this.number, required this.title});
  final String number;
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: const Color(0xFFE8EEFF),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1D4ED8),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    ],
  );
}

class _FareAndPaymentPanel extends StatelessWidget {
  const _FareAndPaymentPanel({
    required this.fareAmount,
    required this.paymentMethod,
    required this.paymentMethodLabel,
    required this.onDecreaseFare,
    required this.onIncreaseFare,
    required this.onSelectPaymentMethod,
  });

  final double fareAmount;
  final String paymentMethod;
  final String paymentMethodLabel;
  final VoidCallback onDecreaseFare;
  final VoidCallback onIncreaseFare;
  final ValueChanged<String> onSelectPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu oferta',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FareStepperButton(
                icon: Icons.remove_rounded,
                onTap: onDecreaseFare,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Bs ${fareAmount.round()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      paymentMethodLabel,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _FareStepperButton(
                icon: Icons.add_rounded,
                onTap: onIncreaseFare,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaymentChoiceButton(
                  icon: Icons.payments_rounded,
                  label: 'Efectivo',
                  selected: paymentMethod != 'qr',
                  onTap: () => onSelectPaymentMethod('cash'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PaymentChoiceButton(
                  icon: Icons.qr_code_2_rounded,
                  label: 'QR',
                  selected: paymentMethod == 'qr',
                  onTap: () => onSelectPaymentMethod('qr'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FareStepperButton extends StatelessWidget {
  const _FareStepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFACC15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF08203A), size: 24),
        ),
      ),
    );
  }
}

class _PaymentChoiceButton extends StatelessWidget {
  const _PaymentChoiceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFACC15) : const Color(0xFFE8EEFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? const Color(0xFF08203A)
                    : const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF08203A)
                        : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeTaxiDriverChoiceTile extends StatelessWidget {
  const _TakeTaxiDriverChoiceTile({
    required this.driver,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final NearbyDriver driver;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isMoto = driver.vehicleType.trim().toLowerCase() == 'moto';
    final vehicleIcon = isMoto
        ? Icons.two_wheeler_rounded
        : Icons.local_taxi_rounded;
    final distance = driver.distanceMeters < 1000
        ? '${driver.distanceMeters.round()} m'
        : '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km';
    final timeLabel = '${driver.etaMinutes} min';
    return Material(
      color: selected ? const Color(0xFFE8EEFF) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 72 : 104),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFFE8EBF2),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (compact)
                _TakeTaxiCompactVehicleBadge(icon: vehicleIcon, isMoto: isMoto)
              else
                _TakeTaxiMarkerPreview(
                  icon: vehicleIcon,
                  isMoto: isMoto,
                  timeLabel: timeLabel,
                  distanceLabel: distance,
                ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.vehicleLabel.trim().isEmpty
                          ? (isMoto ? 'Moto cercana' : 'Taxi cercano')
                          : driver.vehicleLabel.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (compact) ...[
                          _TakeTaxiDriverChip(
                            label: timeLabel,
                            color: const Color(0xFFFACC15),
                            textColor: const Color(0xFF111827),
                          ),
                          _TakeTaxiDriverChip(
                            label: distance,
                            color: const Color(0xFFDCFCE7),
                            textColor: const Color(0xFF166534),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF8AA4C4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeTaxiCompactVehicleBadge extends StatelessWidget {
  const _TakeTaxiCompactVehicleBadge({
    required this.icon,
    required this.isMoto,
  });

  final IconData icon;
  final bool isMoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMoto ? const Color(0xFFFFF2B8) : const Color(0xFFFACC15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FACC15),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF101827), size: isMoto ? 23 : 24),
    );
  }
}

class _TakeTaxiMarkerPreview extends StatelessWidget {
  const _TakeTaxiMarkerPreview({
    required this.icon,
    required this.isMoto,
    required this.timeLabel,
    required this.distanceLabel,
  });

  final IconData icon;
  final bool isMoto;
  final String timeLabel;
  final String distanceLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26020B18),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  distanceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -1),
            child: CustomPaint(
              size: const Size(14, 7),
              painter: _TakeTaxiMarkerPointerPainter(),
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMoto ? const Color(0xFFFFF2B8) : const Color(0xFFFACC15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55FACC15),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFF101827),
              size: isMoto ? 24 : 25,
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeTaxiMarkerPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TakeTaxiDriverChip extends StatelessWidget {
  const _TakeTaxiDriverChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NearestTaxiPickerSheet extends StatelessWidget {
  const _NearestTaxiPickerSheet({
    required this.drivers,
    required this.selectedDriverId,
    required this.onSelectDriver,
    required this.onShowMap,
  });

  final List<NearbyDriver> drivers;
  final String? selectedDriverId;
  final ValueChanged<NearbyDriver> onSelectDriver;
  final VoidCallback onShowMap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Material(
        color: const Color(0xFF041E38).withValues(alpha: 0.99),
        borderRadius: BorderRadius.circular(28),
        elevation: 24,
        shadowColor: const Color(0x66020B18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elegir taxi cercano',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selecciona el auto que prefieras',
                          style: TextStyle(
                            color: Color(0xFFC7D7EA),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TakeTaxiSheetCircleButton(
                    icon: Icons.map_rounded,
                    onTap: onShowMap,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (drivers.isEmpty)
                const _EmptyNearbyDriversCard()
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 330),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: drivers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      return _TakeTaxiDriverChoiceTile(
                        driver: driver,
                        selected: driver.driverId == selectedDriverId,
                        onTap: () => onSelectDriver(driver),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeTaxiSheetCircleButton extends StatelessWidget {
  const _TakeTaxiSheetCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 430 || size.width < 380;
    return Material(
      color: const Color(0xFF082A4D),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0xFF2563EB), width: 1.3),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: isCompact ? 36 : 46,
          height: isCompact ? 36 : 46,
          child: Icon(icon, color: Colors.white, size: isCompact ? 19 : 23),
        ),
      ),
    );
  }
}

class _TakeTaxiDestinationEditorialCard extends StatelessWidget {
  const _TakeTaxiDestinationEditorialCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.onChange,
  });

  final String originLabel;
  final String destinationLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DestinationInfoRow(
            icon: Icons.near_me_rounded,
            iconColor: const Color(0xFF16A34A),
            title: 'Origen',
            value: originLabel,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: const [
                SizedBox(width: 10),
                SizedBox(
                  height: 22,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFD8DEE8),
                  ),
                ),
              ],
            ),
          ),
          _DestinationInfoRow(
            icon: Icons.outlined_flag_rounded,
            iconColor: const Color(0xFFF97316),
            title: 'Destino',
            value: destinationLabel,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, color: Color(0xFF6B7280)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Buscar o mover punto',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 112),
                    child: FilledButton(
                      onPressed: onChange,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Cambiar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationInfoRow extends StatelessWidget {
  const _DestinationInfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isOrigin = title == 'Origen';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: isOrigin
              ? const Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 20,
                )
              : Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TakeTaxiModePill extends StatelessWidget {
  const _TakeTaxiModePill({
    required this.selectedType,
    required this.onTaxi,
    required this.onMoto,
  });

  final String selectedType;
  final VoidCallback onTaxi;
  final VoidCallback onMoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModePillButton(
            icon: Icons.local_taxi_rounded,
            active: selectedType != 'moto',
            onTap: onTaxi,
          ),
          const SizedBox(width: 6),
          _ModePillButton(
            icon: Icons.paid_rounded,
            active: false,
            onTap: onTaxi,
          ),
          const SizedBox(width: 6),
          _ModePillButton(
            icon: Icons.two_wheeler_rounded,
            active: selectedType == 'moto',
            onTap: onMoto,
          ),
        ],
      ),
    );
  }
}

class _ModePillButton extends StatelessWidget {
  const _ModePillButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFF1F3F6) : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, color: const Color(0xFF111827), size: 22),
        ),
      ),
    );
  }
}

class _NearbyVehicleCard extends StatelessWidget {
  const _NearbyVehicleCard({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  final NearbyDriver driver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distanceKm = (driver.distanceMeters / 1000).toStringAsFixed(1);
    final vehicleIcon = driver.vehicleType.trim().toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
    return Material(
      color: selected ? const Color(0xFFFFFCF8) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(24),
      elevation: selected ? 12 : 0,
      shadowColor: const Color(0x140F172A),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 206,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF97316)
                  : const Color(0xFFE5E7EB),
              width: selected ? 1.8 : 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFFFFFCF8), Color(0xFFFFF3E8)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFF1E8)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        vehicleIcon,
                        color: selected
                            ? const Color(0xFFF97316)
                            : const Color(0xFF6B7280),
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Elegido',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 25),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${driver.etaMinutes} min',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      driver.vehicleLabel.isEmpty
                          ? 'Vehículo'
                          : driver.vehicleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      distanceKm == '0.0' ? 'cerca' : '$distanceKm km',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                driver.vehicleDetail.isEmpty
                    ? 'Disponible ahora'
                    : driver.vehicleDetail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      '${driver.etaMinutes} min',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${driver.etaMinutes} min',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.touch_app_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: selected
                        ? const Color(0xFFF97316)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected ? 'Toca para ver datos' : 'Ver datos',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDriverSpotlight extends StatelessWidget {
  const _SelectedDriverSpotlight({
    required this.driver,
    required this.onViewDetails,
  });

  final NearbyDriver driver;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final vehicleIcon = driver.vehicleType.trim().toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
    final vehicleMeta = driver.vehicleDetail
        .split('·')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final vehicleColor = vehicleMeta.isNotEmpty
        ? vehicleMeta.first
        : 'Color pendiente';
    final vehiclePlate = vehicleMeta.length > 1
        ? vehicleMeta[1]
        : 'Placa pendiente';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(vehicleIcon, color: const Color(0xFFF97316)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driver.vehicleLabel.isEmpty
                                ? 'Vehículo cercano'
                                : driver.vehicleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${driver.etaMinutes} min',
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.vehicleDetail.isEmpty
                          ? 'Disponible ahora'
                          : driver.vehicleDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SpotlightMetricChip(
                  icon: Icons.badge_outlined,
                  label: 'Placa',
                  value: vehiclePlate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpotlightMetricChip(
                  icon: Icons.palette_outlined,
                  label: 'Color',
                  value: vehicleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SpotlightMetricChip(
                  icon: Icons.schedule_rounded,
                  label: 'Llegada',
                  value: '${driver.etaMinutes} min',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpotlightMetricChip(
                  icon: Icons.route_rounded,
                  label: 'Distancia',
                  value:
                      '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewDetails,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Ver datos del vehículo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactNearbyDriverCard extends StatelessWidget {
  const _CompactNearbyDriverCard({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  final NearbyDriver driver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicleIcon = driver.vehicleType.trim().toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.directions_car_filled_rounded;
    return SizedBox(
      width: 154,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        elevation: selected ? 6 : 0,
        shadowColor: const Color(0x33040E1D),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? const Color(0xFF14345B)
                  : const Color(0xFF102B4A),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFACC15)
                    : const Color(0xFF1D4ED8),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E223A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        vehicleIcon,
                        size: 20,
                        color: selected
                            ? const Color(0xFFFACC15)
                            : const Color(0xFFD7E4F3),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFACC15)
                            : const Color(0xFF0E223A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${driver.etaMinutes} min',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? const Color(0xFF172554)
                              : const Color(0xFFFACC15),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Spacer(),
                Text(
                  driver.vehicleLabel.isEmpty
                      ? 'Vehículo'
                      : driver.vehicleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${driver.etaMinutes} min',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD7E4F3),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca para ver',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xFFFACC15)
                        : const Color(0xFF8FB3D9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotlightMetricChip extends StatelessWidget {
  const _SpotlightMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF102B4A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1D4ED8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFACC15)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFD7E4F3),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNearbyDriversCard extends StatelessWidget {
  const _EmptyNearbyDriversCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF102B4A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1D4ED8)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_bottom_rounded, color: Color(0xFFFACC15)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No hay vehículos disponibles en este momento.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryRequestBar extends StatelessWidget {
  const _PrimaryRequestBar({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _ActiveTripStatusCard extends StatelessWidget {
  const _ActiveTripStatusCard({
    required this.tripStatus,
    required this.title,
    required this.statusText,
    required this.statusAccent,
    required this.summaryLabel,
    required this.details,
    required this.driverName,
    required this.vehicleLabel,
    required this.vehicleDetail,
    required this.etaLabel,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.secondaryActions,
    required this.detailsExpanded,
    required this.onToggleDetails,
  });

  final String tripStatus;
  final String title;
  final String statusText;
  final Color statusAccent;
  final String summaryLabel;
  final List<String> details;
  final String driverName;
  final String vehicleLabel;
  final String vehicleDetail;
  final String? etaLabel;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final List<RouteReviewActionData> secondaryActions;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8EBF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleDetails,
                    icon: Icon(
                      detailsExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                    ),
                  ),
                ],
              ),
              TripStatusBanner(status: tripStatus),
              const SizedBox(height: 12),
              Text(
                summaryLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              if (detailsExpanded) ...[
                const SizedBox(height: 12),
                if (driverName.trim().isNotEmpty)
                  _DriverDetailRow(
                    icon: Icons.person_rounded,
                    label: 'Conductor',
                    value: driverName,
                  ),
                if (vehicleLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DriverDetailRow(
                    icon: Icons.directions_car_filled_rounded,
                    label: 'Vehículo',
                    value: vehicleDetail.trim().isEmpty
                        ? vehicleLabel
                        : '$vehicleLabel · $vehicleDetail',
                  ),
                ],
                if (etaLabel != null) ...[
                  const SizedBox(height: 8),
                  _DriverDetailRow(
                    icon: Icons.schedule_rounded,
                    label: 'Llegada',
                    value: etaLabel!,
                  ),
                ],
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: details
                        .map(
                          (detail) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6FA),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              detail,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                      color: Color(0xFF1D4ED8),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(primaryActionLabel),
                ),
              ),
              if (secondaryActions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: secondaryActions
                      .map(
                        (action) => GestureDetector(
                          onTap: action.onTap,
                          child: Text(
                            action.label,
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF102B4A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1D4ED8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFFACC15)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverDetailRow extends StatelessWidget {
  const _DriverDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TakeTaxiHeaderIconButton extends StatelessWidget {
  const _TakeTaxiHeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102B4A),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1D4ED8), width: 1.4),
          ),
          child: Icon(icon, color: const Color(0xFFFACC15), size: 20),
        ),
      ),
    );
  }
}
