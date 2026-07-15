// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import '../widgets/route_review_view.dart';

enum RoutePreviewAction { back, edit, clear, journey }

class RoutePreviewPage extends ConsumerStatefulWidget {
  const RoutePreviewPage({
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
  ConsumerState<RoutePreviewPage> createState() => _RoutePreviewPageState();
}

class _RoutePreviewPageState extends ConsumerState<RoutePreviewPage> {
  late final String _serviceType = widget.serviceType;
  bool _detailsExpanded = false;
  bool _didScheduleClose = false;
  bool _didScheduleJourney = false;

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

  String get _fareLabel {
    return '';
  }

  String _navigationBadgeCaption(String status) {
    return switch (status) {
      'requested' || 'searching' => 'Solicitud',
      'accepted' || 'arriving' || 'at_pickup' => 'Recogida',
      'in_progress' => 'Destino',
      _ => 'Destino',
    };
  }

  IconData _navigationBadgeIcon(String status) {
    return switch (status) {
      'requested' || 'searching' => Icons.search_rounded,
      'accepted' || 'arriving' || 'at_pickup' => Icons.near_me_rounded,
      'in_progress' => Icons.outlined_flag_rounded,
      _ => Icons.outlined_flag_rounded,
    };
  }

  IconData _primaryActionIcon(String status, {required bool isRequesting}) {
    if (isRequesting) {
      return Icons.hourglass_top_rounded;
    }
    return switch (status) {
      'requested' || 'searching' => Icons.search_rounded,
      'accepted' || 'arriving' => Icons.close_rounded,
      'at_pickup' => Icons.location_on_rounded,
      'in_progress' => Icons.navigation_rounded,
      _ => Icons.arrow_forward_rounded,
    };
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
    Navigator.of(context).pop(RoutePreviewAction.back);
  }

  Future<void> _handleCancel() async {
    await widget.onCancel();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(RoutePreviewAction.back);
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
      Navigator.of(context).pop(RoutePreviewAction.back);
    });
  }

  void _scheduleTransitionToJourney(String status) {
    if (_didScheduleJourney || !mounted) {
      return;
    }
    if (!const {
      'accepted',
      'arriving',
      'at_pickup',
      'in_progress',
    }.contains(status)) {
      return;
    }
    _didScheduleJourney = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(RoutePreviewAction.journey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripState = ref.watch(tripProvider);
    final request = tripState.request;
    final status = request.status;
    _scheduleCloseIfFinished(status);
    _scheduleTransitionToJourney(status);

    final title = switch (status) {
      'requested' || 'searching' => 'Solicitud enviada',
      'accepted' || 'arriving' || 'at_pickup' || 'in_progress' => 'Tu viaje',
      _ => 'Pedir taxi',
    };

    final statusText = switch (status) {
      'requested' || 'searching' => 'Esperando taxi para empezar el viaje',
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
          label: 'Editar lugar',
          onTap: () => Navigator.of(context).pop(RoutePreviewAction.edit),
        ),
    ];

    final primaryActionLabel = switch (status) {
      'requested' => 'Buscando conductor...',
      'searching' => 'Enviando a taxis cercanos...',
      'accepted' => 'Taxi asignado · Cancelar',
      'arriving' => 'Taxi en camino · Cancelar',
      'at_pickup' => 'Taxi llegó · Cancelar',
      'in_progress' => 'Viaje en curso',
      _ => 'Solicitar taxi',
    };

    final primaryAction = switch (status) {
      'requested' || 'searching' => null,
      'accepted' || 'arriving' || 'at_pickup' => _handleCancel,
      'in_progress' => null,
      _ => widget.onRequest,
    };

    final requestActive = _requestIsActive(status);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PotosiMapSurface(
              viewportCacheKey: 'passenger_route_preview',
              drivers: widget.drivers,
              userLocation: widget.userLocation,
              userAccuracyMeters: widget.userAccuracyMeters,
              userHeadingDegrees: widget.userHeadingDegrees,
              routeTarget: widget.routeTarget,
              showRoute: widget.routeTarget != null,
              showTargetMarker: widget.routeTarget != null,
              routeColor: widget.routeColor,
              focusSignal: widget.focusSignal,
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
                      const Color(0xFF91BDF0).withValues(alpha: 0.24),
                      const Color(0xFF6CA3E4).withValues(alpha: 0.08),
                      Colors.transparent,
                      const Color(0xFF285486).withValues(alpha: 0.12),
                      const Color(0xFF0A2744).withValues(alpha: 0.24),
                    ],
                    stops: const [0, 0.16, 0.52, 0.78, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RouteReviewView(
              title: title,
              originLabel: widget.originLabel,
              destinationLabel: widget.destinationLabel,
              summaryLabel: _summaryLabel,
              fareLabel: _fareLabel,
              durationLabel: request.etaMinutes == null
                  ? _durationLabel
                  : '${request.etaMinutes} min',
              distanceLabel: _distanceLabel,
              serviceType: widget.serviceType,
              onBack: () => _handleBack(status),
              onSelectTaxi: widget.onSelectTaxi,
              onSelectMoto: widget.onSelectMoto,
              onEdit: () => Navigator.of(context).pop(RoutePreviewAction.edit),
              onClear: () =>
                  Navigator.of(context).pop(RoutePreviewAction.clear),
              primaryActionLabel: tripState.isRequestingTrip
                  ? (requestActive ? 'Procesando...' : 'Enviando...')
                  : primaryActionLabel,
              primaryActionIcon: _primaryActionIcon(
                status,
                isRequesting: tripState.isRequestingTrip,
              ),
              onPrimaryAction: tripState.isRequestingTrip
                  ? null
                  : primaryAction,
              primaryActionColor: requestActive
                  ? statusAccent
                  : const Color(0xFFFF4B38),
              detailsExpanded: _detailsExpanded,
              onToggleDetails: _toggleDetails,
              statusText: statusText,
              statusAccent: statusAccent,
              statusDetails: details,
              secondaryActions: secondaryActions,
              navigationBadgeLabel: request.etaMinutes != null && requestActive
                  ? '${request.etaMinutes} min'
                  : _distanceLabel,
              navigationBadgeCaption: _navigationBadgeCaption(status),
              navigationBadgeIcon: _navigationBadgeIcon(status),
              driverName: (request.driverName ?? '').trim().isEmpty
                  ? null
                  : request.driverName!.trim(),
              vehicleLabel: (request.vehicleLabel ?? '').trim().isEmpty
                  ? null
                  : request.vehicleLabel!.trim(),
              vehiclePlate: (request.vehiclePlate ?? '').trim().isEmpty
                  ? null
                  : request.vehiclePlate!.trim(),
              vehicleDetail: (request.vehicleColor ?? '').trim().isEmpty
                  ? null
                  : request.vehicleColor!.trim(),
              etaLabel: request.etaMinutes == null
                  ? null
                  : '${request.etaMinutes} min',
              compactMode: const {
                'accepted',
                'arriving',
                'at_pickup',
                'in_progress',
              }.contains(status),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLocationRow extends StatelessWidget {
  const _PreviewLocationRow({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isOrigin = trailing == null;

    return Row(
      children: [
        if (isOrigin)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8D9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFE27A), width: 1.2),
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Color(0xFF1D4ED8),
              size: 16,
            ),
          )
        else
          Icon(icon, color: const Color(0xFF111827), size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _StopsPill extends StatelessWidget {
  const _StopsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Paradas',
        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827)),
      ),
    );
  }
}

class _CompactRouteReviewCard extends StatelessWidget {
  const _CompactRouteReviewCard({
    required this.originLabel,
    required this.destinationLabel,
    required this.summaryLabel,
    required this.buttonLabel,
    required this.onPressed,
    required this.onEdit,
    required this.onClear,
  });

  final String originLabel;
  final String destinationLabel;
  final String summaryLabel;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revisa tu recorrido',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          _PreviewLocationRow(
            icon: Icons.near_me_rounded,
            title: originLabel,
            trailing: null,
          ),
          const Divider(height: 26, color: Color(0xFFE8ECF2)),
          _PreviewLocationRow(
            icon: Icons.outlined_flag_rounded,
            title: destinationLabel,
            trailing: const _StopsPill(),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFF6B7280)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summaryLabel,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('Editar')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Quitar destino'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
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
    required this.destinationLabel,
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
  final String destinationLabel;
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
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
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summaryLabel,
                  style: TextStyle(
                    color: statusAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          if (driverName.trim().isNotEmpty || vehicleLabel.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.person_rounded, color: statusAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (driverName.trim().isNotEmpty)
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        if (vehicleLabel.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            vehicleDetail.trim().isEmpty
                                ? vehicleLabel
                                : '$vehicleLabel · $vehicleDetail',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (etaLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        etaLabel!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: _DriverDetailRow(
              icon: Icons.outlined_flag_rounded,
              label: 'Destino',
              value: destinationLabel,
            ),
          ),
          if (detailsExpanded && details.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimaryAction,
              style: FilledButton.styleFrom(
                backgroundColor: statusAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(primaryActionLabel),
            ),
          ),
          if (secondaryActions.isNotEmpty || details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onToggleDetails,
                  icon: Icon(
                    detailsExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                  ),
                  label: Text(
                    detailsExpanded ? 'Ocultar detalles' : 'Ver detalles',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4B5563),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
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
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ],
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
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 10,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(icon, color: const Color(0xFF111827), size: 28),
        ),
      ),
    );
  }
}
