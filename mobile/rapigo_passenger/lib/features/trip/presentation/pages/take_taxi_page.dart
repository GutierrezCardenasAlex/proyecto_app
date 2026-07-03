// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../map/data/location_controller.dart';
import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import '../widgets/route_review_view.dart';

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
    required this.selectedDriverId,
    required this.onSelectDriver,
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
  final String? selectedDriverId;
  final ValueChanged<String> onSelectDriver;
  final VoidCallback onSelectTaxi;
  final VoidCallback onSelectMoto;
  final Future<void> Function() onRequest;
  final Future<void> Function() onRetry;
  final Future<void> Function() onCancel;

  @override
  ConsumerState<TakeTaxiPage> createState() => _TakeTaxiPageState();
}

class _TakeTaxiPageState extends ConsumerState<TakeTaxiPage> {
  late String _serviceType = widget.serviceType;
  bool _detailsExpanded = false;
  bool _didScheduleClose = false;
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
      final firstDriver = _filteredDrivers.isEmpty ? null : _filteredDrivers.first;
      if ((widget.selectedDriverId == null || widget.selectedDriverId!.isEmpty) &&
          firstDriver != null) {
        widget.onSelectDriver(firstDriver.driverId);
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
    final selectedId = widget.selectedDriverId;
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }
    return _filteredDrivers.isEmpty ? null : _filteredDrivers.first.driverId;
  }

  NearbyDriver? get _selectedDriver {
    final selectedId = widget.selectedDriverId;
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
    final selectedId = widget.selectedDriverId;
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
    widget.onSelectDriver(_filteredDrivers[index].driverId);
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
    if (_requestIsActive(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancela la solicitud para volver al mapa principal.'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(TakeTaxiPageAction.back);
  }

  Future<void> _handleCancel() async {
    await widget.onCancel();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(TakeTaxiPageAction.back);
  }

  void _toggleDetails() {
    setState(() {
      _detailsExpanded = !_detailsExpanded;
    });
  }

  void _scheduleCloseIfFinished(String status) {
    if (_didScheduleClose || !mounted) {
      return;
    }
    if (!const {'completed', 'cancelled'}.contains(status)) {
      return;
    }
    _didScheduleClose = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TakeTaxiPageAction.back);
    });
  }

  void _showDriverDetails(NearbyDriver driver) {
    widget.onSelectDriver(driver.driverId);
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
                                icon: Icons.payments_outlined,
                                label: driver.priceLabel,
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

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    ref.watch(tripProvider.select((state) => state.nearbyDrivers));
    final request = tripState.request;
    final status = request.status;
    _scheduleCloseIfFinished(status);
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
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetMaxHeight = requestActive
        ? screenHeight * 0.40
        : screenHeight * 0.46;

    return Scaffold(
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
              routeTarget: widget.routeTarget,
              showRoute: widget.routeTarget != null,
              showTargetMarker: widget.routeTarget != null,
              routeColor: widget.routeColor,
              focusSignal: widget.focusSignal,
              cameraCenterTarget: liveUserLocation,
              cameraCenterSignal: _mapCenterSignal,
              showUtilityControls: false,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF8FBDF2).withValues(alpha: 0.18),
                      const Color(0xFF6EA7E8).withValues(alpha: 0.07),
                      Colors.transparent,
                      const Color(0xFF0D2B4B).withValues(alpha: 0.12),
                      const Color(0xFF08203A).withValues(alpha: 0.20),
                    ],
                    stops: const [0, 0.16, 0.48, 0.78, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  top: MediaQuery.of(context).padding.top + 6,
                  child: _FloatingCircleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _handleBack(status),
                    backgroundColor: Colors.white.withValues(alpha: 0.98),
                    iconColor: const Color(0xFF0F172A),
                    borderColor: const Color(0xFFFACC15),
                    iconSize: 24,
                  ),
                ),
                Positioned(
                  right: 16,
                  top: MediaQuery.of(context).padding.top + 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FloatingCircleButton(
                        icon: Icons.explore_rounded,
                        onTap: () {
                          setState(() {
                            _mapCenterSignal++;
                          });
                        },
                        backgroundColor: const Color(0xFF1D4ED8),
                        iconColor: Colors.white,
                        borderColor: const Color(0xFFFACC15),
                        iconSize: 22,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Material(
                      color: const Color(0xFF0A2340).withValues(alpha: 0.985),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(42),
                      ),
                      elevation: 22,
                      shadowColor: const Color(0x44040E1D),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: sheetMaxHeight.clamp(250.0, 400.0),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 52,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFACC15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tomar taxi',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          widget.destinationLabel.trim().isEmpty ||
                                                  widget.destinationLabel ==
                                                      TripRepository
                                                          .destinationPendingLabel
                                              ? 'Destino pendiente'
                                              : widget.destinationLabel,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFD7E4F3),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _TakeTaxiHeaderIconButton(
                                    icon: Icons.route_rounded,
                                    onTap: () =>
                                        Navigator.of(context).pop(
                                          TakeTaxiPageAction.edit,
                                        ),
                                  ),
                                  const SizedBox(width: 10),
                                  _TakeTaxiHeaderIconButton(
                                    icon: Icons.settings_rounded,
                                    onTap: _refreshNearbyDrivers,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (selectedDriver != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF102B4A),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        runSpacing: 6,
                                        spacing: 8,
                                        children: [
                                          if (_filteredDrivers.isNotEmpty &&
                                              selectedDriver.driverId ==
                                                  _filteredDrivers.first.driverId)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFACC15),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Recomendado',
                                                style: TextStyle(
                                                  color: Color(0xFF172554),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0E223A),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Tarifa ${selectedDriver.priceLabel}',
                                              style: const TextStyle(
                                                color: Color(0xFFFACC15),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        selectedDriver.vehicleLabel.isEmpty
                                            ? 'Vehículo cercano'
                                            : selectedDriver.vehicleLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${selectedDriver.priceLabel} · ${selectedDriver.etaMinutes} min',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFD7E4F3),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      OutlinedButton(
                                        onPressed: () =>
                                            _showDriverDetails(selectedDriver),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFACC15),
                                          backgroundColor: const Color(0xFF0E223A),
                                          side: const BorderSide(
                                            color: Color(0xFF1D4ED8),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          minimumSize: const Size(0, 40),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Ver datos del auto'),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const _EmptyNearbyDriversCard(),
                              if (!requestActive && _filteredDrivers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 88,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _filteredDrivers.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final driver = _filteredDrivers[index];
                                      final selected =
                                          driver.driverId ==
                                          selectedDriver?.driverId;
                                    return _CompactNearbyDriverCard(
                                      driver: driver,
                                      selected: selected,
                                      isNearest: index == 0,
                                      onTap: () {
                                        widget.onSelectDriver(driver.driverId);
                                        _showDriverDetails(driver);
                                      },
                                    );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              if (!requestActive)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF102B4A),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFF1D4ED8),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            destinationReady
                                                ? 'Paso 2 completo · destino elegido'
                                                : 'Paso 2 · elige tu destino',
                                            style: TextStyle(
                                              color: destinationReady
                                                  ? const Color(0xFFFACC15)
                                                  : const Color(0xFFFACC15),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            destinationReady
                                                ? (widget.destinationLabel
                                                          .trim()
                                                          .isEmpty
                                                      ? 'Destino confirmado'
                                                      : widget.destinationLabel)
                                                : 'Puedes buscar la dirección o usar el botón "Mapa" en la siguiente vista.',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFD7E4F3),
                                              fontWeight: FontWeight.w500,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: tripState.isRequestingTrip
                                            ? null
                                            : (destinationReady
                                                  ? primaryAction
                                                  : () => Navigator.of(
                                                      context,
                                                    ).pop(TakeTaxiPageAction.edit)),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1D4ED8),
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: Color(0xFFFACC15),
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: Text(
                                          tripState.isRequestingTrip
                                              ? 'Enviando...'
                                              : (destinationReady
                                                    ? primaryActionLabel
                                                    : 'Elegir destino'),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                _ActiveTripStatusCard(
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
                                    if ((request.vehicleColor ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      request.vehicleColor!.trim(),
                                    if ((request.vehiclePlate ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      request.vehiclePlate!.trim(),
                                  ].join(' · '),
                                  etaLabel: request.etaMinutes == null
                                      ? null
                                      : '${request.etaMinutes} min',
                                  primaryActionLabel:
                                      tripState.isRequestingTrip
                                      ? 'Procesando...'
                                      : primaryActionLabel,
                                  onPrimaryAction: tripState.isRequestingTrip
                                      ? null
                                      : primaryAction,
                                  secondaryActions: secondaryActions,
                                  detailsExpanded: _detailsExpanded,
                                  onToggleDetails: _toggleDetails,
                                ),
                            ],
                          ),
                        ),
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
                      driver.priceLabel,
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
                  icon: Icons.payments_outlined,
                  label: 'Tarifa',
                  value: driver.priceLabel,
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
    this.isNearest = false,
  });

  final NearbyDriver driver;
  final bool selected;
  final VoidCallback onTap;
  final bool isNearest;

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
                if (isNearest)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFACC15)
                            : const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selected ? 'Recomendado para ti' : 'Recomendado',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF172554)
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                      ),
                    ),
                  ),
                if (isNearest) const SizedBox(height: 10),
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
                  driver.vehicleLabel.isEmpty ? 'Vehículo' : driver.vehicleLabel,
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
                  driver.priceLabel,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF102B4A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1D4ED8)),
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
                    color: Colors.white,
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
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summaryLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFD7E4F3),
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
                          color: const Color(0xFF0E223A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          detail,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD7E4F3),
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
                side: const BorderSide(color: Color(0xFFFACC15), width: 1.5),
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
                          color: Color(0xFFFACC15),
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
        Icon(icon, size: 20, color: const Color(0xFFFACC15)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.borderColor,
    this.iconSize,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: const Color(0x220F172A),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(
              icon,
              color: iconColor ?? const Color(0xFF111827),
              size: iconSize ?? 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _TakeTaxiHeaderIconButton extends StatelessWidget {
  const _TakeTaxiHeaderIconButton({
    required this.icon,
    required this.onTap,
  });

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
            border: Border.all(
              color: const Color(0xFF1D4ED8),
              width: 1.4,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFACC15),
            size: 20,
          ),
        ),
      ),
    );
  }
}
