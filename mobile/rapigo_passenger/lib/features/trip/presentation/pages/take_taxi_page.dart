// ignore_for_file: unused_element

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

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
  bool _takeTaxiDrawerExpanded = true;
  String? _ratingPromptedTripId;
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
      if ((widget.selectedDriverId == null ||
              widget.selectedDriverId!.isEmpty) &&
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
    if (status == 'completed') {
      final tripId = ref.read(tripProvider).request.activeTripId;
      if (tripId == null || tripId.isEmpty) {
        _didScheduleClose = true;
        _closeFinishedTrip();
        return;
      }
      if (_ratingPromptedTripId == tripId) {
        return;
      }
      _didScheduleClose = true;
      _ratingPromptedTripId = tripId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_showPassengerRatingDialogAndClose(tripId));
      });
      return;
    }
    if (status != 'cancelled') {
      return;
    }
    _didScheduleClose = true;
    _closeFinishedTrip();
  }

  void _closeFinishedTrip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(TakeTaxiPageAction.back);
    });
  }

  Future<void> _showPassengerRatingDialogAndClose(String tripId) async {
    int selectedScore = 5;
    final commentController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Califica al conductor'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 4,
                        children: List<Widget>.generate(5, (index) {
                          final value = index + 1;
                          return IconButton(
                            onPressed: () =>
                                setDialogState(() => selectedScore = value),
                            icon: Icon(
                              value <= selectedScore
                                  ? Icons.star
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFACC15),
                            ),
                          );
                        }),
                      ),
                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Comentario opcional',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Luego'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Enviar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true) {
        if (mounted) {
          Navigator.of(context).pop(TakeTaxiPageAction.back);
        }
        return;
      }

      final session = ref.read(sessionProvider);
      await ref
          .read(tripProvider.notifier)
          .submitRating(
            token: session.token,
            tripId: tripId,
            score: selectedScore,
            comment: commentController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por calificar al conductor.')),
      );
      Navigator.of(context).pop(TakeTaxiPageAction.back);
    } catch (error) {
      _didScheduleClose = false;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo concluir la calificacion: $error')),
      );
    } finally {
      commentController.dispose();
    }
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
              widget.onSelectDriver(drivers[index].driverId);
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
              widget.onSelectDriver(driver.driverId);
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
    final nearbyCount = _filteredDrivers.length;
    final screenSize = MediaQuery.sizeOf(context);
    final screenPadding = MediaQuery.paddingOf(context);
    final isTinyHeight = screenSize.height < 430;
    final isCompactHeight = screenSize.height < 560;
    final isNarrowWidth = screenSize.width < 380;
    final topControlsOffset = isTinyHeight
        ? 10.0
        : (isCompactHeight ? 20.0 : 38.0);
    final topBannerOffset = isTinyHeight
        ? 14.0
        : (isCompactHeight ? 24.0 : 42.0);
    final horizontalInset = isNarrowWidth ? 12.0 : (isTinyHeight ? 16.0 : 30.0);
    final bottomInset = isTinyHeight ? 10.0 : (isCompactHeight ? 16.0 : 28.0);
    final floatingSize = (isNarrowWidth || isTinyHeight) ? 42.0 : 50.0;
    final bannerHorizontalInset = isNarrowWidth
        ? 104.0
        : (isTinyHeight ? 88.0 : 110.0);

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
          Positioned(
            left: isNarrowWidth ? 14 : (isTinyHeight ? 18 : 26),
            top: screenPadding.top + topControlsOffset,
            child: _FloatingCircleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => _handleBack(status),
              backgroundColor: Colors.white.withValues(alpha: 0.98),
              iconColor: const Color(0xFF0F172A),
              borderColor: Colors.transparent,
              iconSize: (isNarrowWidth || isTinyHeight) ? 21 : 24,
              size: floatingSize,
            ),
          ),
          Positioned(
            right: isNarrowWidth ? 14 : (isTinyHeight ? 18 : 26),
            top: screenPadding.top + topControlsOffset,
            child: _FloatingCircleButton(
              icon: Icons.explore_rounded,
              onTap: () => setState(() => _mapCenterSignal++),
              backgroundColor: const Color(0xFF2257E8),
              iconColor: Colors.white,
              borderColor: const Color(0xFFE8F0FF),
              iconSize: (isNarrowWidth || isTinyHeight) ? 19 : 21,
              size: floatingSize,
            ),
          ),
          if (!isTinyHeight)
            Positioned(
              left: bannerHorizontalInset,
              right: bannerHorizontalInset,
              top: screenPadding.top + topBannerOffset,
              child: _NearbyTaxiHeroBanner(
                nearbyCount: nearbyCount,
                onTap: _openNearestTaxiPicker,
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
                      onShowNearby: () => setState(() => _mapCenterSignal++),
                      onRefresh: _refreshNearbyDrivers,
                      onToggleExpanded: () {
                        setState(() {
                          _takeTaxiDrawerExpanded = !_takeTaxiDrawerExpanded;
                        });
                      },
                      onSelectDriver: (driver) {
                        widget.onSelectDriver(driver.driverId);
                      },
                    ),
            ),
          ),
        ],
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
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 1.4,
                    ),
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
    required this.isRequesting,
    required this.primaryActionLabel,
    required this.onPrimary,
    required this.onChooseDestination,
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
  final bool isRequesting;
  final String primaryActionLabel;
  final Future<void> Function()? onPrimary;
  final VoidCallback onChooseDestination;
  final VoidCallback onShowNearby;
  final VoidCallback onRefresh;
  final VoidCallback onToggleExpanded;
  final ValueChanged<NearbyDriver> onSelectDriver;

  @override
  Widget build(BuildContext context) {
    final destinationText = destinationReady
        ? destinationLabel
        : 'Busca la dirección o selecciona en el mapa.';
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTinyHeight = screenHeight < 430;
    final isNarrowWidth = screenWidth < 380;
    final maxSheetHeight = (screenHeight * (isTinyHeight ? 0.42 : 0.48)).clamp(
      isTinyHeight ? 148.0 : 230.0,
      isTinyHeight ? 190.0 : 430.0,
    );
    final driverListHeight = (screenHeight * 0.14).clamp(
      isTinyHeight ? 0.0 : 84.0,
      isTinyHeight ? 0.0 : 144.0,
    );
    final showDriverList =
        !isTinyHeight && !isNarrowWidth && nearbyDrivers.isNotEmpty;
    final showDestinationTile = !isTinyHeight || !destinationReady;
    final showNearbyTile = !isTinyHeight && !isNarrowWidth;
    return Material(
      color: const Color(0xFF041E38).withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(26),
      elevation: 24,
      shadowColor: const Color(0x66020B18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: expanded ? maxSheetHeight : (isTinyHeight ? 104 : 132),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isTinyHeight || isNarrowWidth ? 12 : 22,
            isTinyHeight ? 8 : 12,
            isTinyHeight || isNarrowWidth ? 12 : 22,
            expanded ? (isTinyHeight ? 12 : 22) : (isTinyHeight ? 10 : 16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: onToggleExpanded,
                child: Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: isTinyHeight ? 8 : 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tomar taxi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          destinationReady
                              ? 'Destino elegido'
                              : 'Destino pendiente',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC7D7EA),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TakeTaxiSheetCircleButton(
                    icon: Icons.tune_rounded,
                    onTap: onRefresh,
                  ),
                  SizedBox(width: isTinyHeight || isNarrowWidth ? 6 : 10),
                  _TakeTaxiSheetCircleButton(
                    icon: Icons.my_location_rounded,
                    onTap: onShowNearby,
                  ),
                  SizedBox(width: isTinyHeight || isNarrowWidth ? 6 : 10),
                  _TakeTaxiSheetCircleButton(
                    icon: expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    onTap: onToggleExpanded,
                  ),
                ],
              ),
              if (expanded) ...[
                SizedBox(height: isTinyHeight ? 10 : 18),
                if (showNearbyTile)
                  _TakeTaxiInfoTile(
                    icon: Icons.local_taxi_rounded,
                    iconColor: const Color(0xFFDCFCE7),
                    iconBackground: const Color(0xFF0F6848),
                    borderColor: const Color(0xFF22C55E),
                    title: 'Taxis cerca de ti',
                    subtitle: '$nearbyCount disponibles',
                    trailing: 'Ver mapa',
                    onTap: onShowNearby,
                    filledTrailing: true,
                  ),
                if (showDriverList) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: driverListHeight),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: nearbyDrivers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final driver = nearbyDrivers[index];
                        return _TakeTaxiDriverChoiceTile(
                          driver: driver,
                          selected: driver.driverId == selectedDriverId,
                          compact: true,
                          onTap: () => onSelectDriver(driver),
                        );
                      },
                    ),
                  ),
                ],
                if (showDestinationTile) ...[
                  SizedBox(height: isTinyHeight ? 8 : 12),
                  _TakeTaxiInfoTile(
                    icon: Icons.my_location_rounded,
                    iconColor: Colors.white,
                    iconBackground: const Color(0xFF1D4ED8),
                    borderColor: const Color(0xFF2563EB),
                    title: destinationReady
                        ? 'Destino elegido'
                        : 'Paso 2 · Elige tu destino',
                    subtitle: destinationText,
                    trailing: null,
                    onTap: onChooseDestination,
                  ),
                ],
                SizedBox(height: isTinyHeight ? 10 : 16),
                FilledButton.icon(
                  onPressed: isRequesting || onPrimary == null
                      ? null
                      : () => onPrimary!(),
                  icon: const Icon(Icons.location_on_outlined, size: 19),
                  label: Text(
                    isRequesting ? 'Enviando...' : primaryActionLabel,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2557FF),
                    disabledBackgroundColor: const Color(0xFF31528F),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isTinyHeight ? 11 : 15,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    side: const BorderSide(
                      color: Color(0xFFFACC15),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeTaxiInfoTile extends StatelessWidget {
  const _TakeTaxiInfoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.filledTrailing = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color borderColor;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback onTap;
  final bool filledTrailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD7E4F3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: filledTrailing
                        ? const Color(0xFF0F6F50)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailing!,
                    style: const TextStyle(
                      color: Color(0xFFDCFCE7),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ] else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 28,
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
      color: selected
          ? const Color(0xFF123D36).withValues(alpha: 0.96)
          : const Color(0xFF082A4D).withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: compact ? 72 : 104,
            maxHeight: compact ? 78 : 124,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF1E4A78),
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
                          ? 'Taxi cercano'
                          : driver.vehicleLabel.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
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
                    ? const Color(0xFF22C55E)
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
    this.size = 60,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final double? iconSize;
  final double size;

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
            width: size,
            height: size,
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
