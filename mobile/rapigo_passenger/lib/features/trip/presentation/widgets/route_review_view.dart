// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
import 'trip_status_banner.dart';

class RouteReviewActionData {
  const RouteReviewActionData({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class RouteReviewView extends StatelessWidget {
  const RouteReviewView({
    super.key,
    required this.title,
    required this.originLabel,
    required this.destinationLabel,
    required this.summaryLabel,
    required this.fareLabel,
    this.offerAmount,
    this.paymentMethod = 'cash',
    this.onDecreaseFare,
    this.onIncreaseFare,
    this.onSelectPaymentMethod,
    required this.durationLabel,
    required this.distanceLabel,
    required this.serviceType,
    required this.onBack,
    required this.onSelectTaxi,
    required this.onSelectMoto,
    required this.onEdit,
    required this.onClear,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.detailsExpanded,
    required this.onToggleDetails,
    this.primaryActionIcon = Icons.arrow_forward_rounded,
    this.primaryActionColor = const Color(0xFFFF4B38),
    this.statusText,
    this.statusAccent = AppBrand.primaryBlue,
    this.statusDetails = const <String>[],
    this.secondaryActions = const <RouteReviewActionData>[],
    this.navigationBadgeLabel,
    this.navigationBadgeCaption,
    this.navigationBadgeIcon = Icons.navigation_rounded,
    this.driverName,
    this.vehicleLabel,
    this.vehiclePlate,
    this.vehicleDetail,
    this.etaLabel,
    this.compactMode = false,
    this.tripStatus,
  });

  final String title;
  final String originLabel;
  final String destinationLabel;
  final String summaryLabel;
  final String fareLabel;
  final double? offerAmount;
  final String paymentMethod;
  final VoidCallback? onDecreaseFare;
  final VoidCallback? onIncreaseFare;
  final ValueChanged<String>? onSelectPaymentMethod;
  final String durationLabel;
  final String distanceLabel;
  final String serviceType;
  final VoidCallback onBack;
  final VoidCallback onSelectTaxi;
  final VoidCallback onSelectMoto;
  final VoidCallback onEdit;
  final VoidCallback onClear;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool detailsExpanded;
  final VoidCallback onToggleDetails;
  final IconData primaryActionIcon;
  final Color primaryActionColor;
  final String? statusText;
  final Color statusAccent;
  final List<String> statusDetails;
  final List<RouteReviewActionData> secondaryActions;
  final String? navigationBadgeLabel;
  final String? navigationBadgeCaption;
  final IconData navigationBadgeIcon;
  final String? driverName;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final String? vehicleDetail;
  final String? etaLabel;
  final bool compactMode;
  final String? tripStatus;

  @override
  Widget build(BuildContext context) {
    final active = statusText != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              active ? 'Tu viaje' : 'Revisa tu recorrido',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              active
                                  ? (navigationBadgeLabel ?? summaryLabel)
                                  : '$durationLabel · $distanceLabel · estimado',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppBrand.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height *
                        (detailsExpanded ? 0.58 : 0.38),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                active
                                    ? 'Seguimiento del viaje'
                                    : 'Destino y oferta',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: detailsExpanded
                                  ? 'Ver más mapa'
                                  : 'Mostrar detalles',
                              onPressed: onToggleDetails,
                              icon: Icon(
                                detailsExpanded
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (active)
                                TripStatusBanner(
                                  status: tripStatus ?? 'searching',
                                ),
                              if (detailsExpanded) ...[
                                const SizedBox(height: 10),
                                _ExpandedDetailsBlock(
                                  originLabel: originLabel,
                                  destinationLabel: destinationLabel,
                                  summaryLabel: summaryLabel,
                                  serviceType: serviceType,
                                  onSelectTaxi: onSelectTaxi,
                                  onSelectMoto: onSelectMoto,
                                  onEdit: onEdit,
                                  onClear: onClear,
                                  statusText: statusText,
                                  statusAccent: statusAccent,
                                  statusDetails: statusDetails,
                                  secondaryActions: secondaryActions,
                                  driverName: driverName,
                                  vehicleLabel: vehicleLabel,
                                  vehiclePlate: vehiclePlate,
                                  vehicleDetail: vehicleDetail,
                                  etaLabel: etaLabel,
                                ),
                              ] else if (!active) ...[
                                Text(
                                  destinationLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fareLabel,
                                  style: const TextStyle(
                                    color: AppBrand.textSecondary,
                                  ),
                                ),
                              ],
                              if (!active &&
                                  detailsExpanded &&
                                  offerAmount != null &&
                                  onDecreaseFare != null &&
                                  onIncreaseFare != null &&
                                  onSelectPaymentMethod != null) ...[
                                const SizedBox(height: 16),
                                _RouteOfferPanel(
                                  fareAmount: offerAmount!,
                                  paymentMethod: paymentMethod,
                                  onDecreaseFare: onDecreaseFare!,
                                  onIncreaseFare: onIncreaseFare!,
                                  onSelectPaymentMethod: onSelectPaymentMethod!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onPrimaryAction,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppBrand.secondaryBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: Icon(primaryActionIcon, size: 20),
                            label: Text(
                              primaryActionLabel,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _NavigationDistanceBadge extends StatelessWidget {
  const _NavigationDistanceBadge({
    required this.label,
    required this.caption,
    required this.icon,
  });

  final String label;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3478F6), Color(0xFF1457D9)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A1457D9),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                caption,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.84),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFACC15),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOfferPanel extends StatelessWidget {
  const _RouteOfferPanel({
    required this.fareAmount,
    required this.paymentMethod,
    required this.onDecreaseFare,
    required this.onIncreaseFare,
    required this.onSelectPaymentMethod,
  });

  final double fareAmount;
  final String paymentMethod;
  final VoidCallback onDecreaseFare;
  final VoidCallback onIncreaseFare;
  final ValueChanged<String> onSelectPaymentMethod;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _OfferStepButton(icon: Icons.remove_rounded, onTap: onDecreaseFare),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Bs ${fareAmount.round()}',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppBrand.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PaymentMiniButton(
                      icon: Icons.payments_rounded,
                      label: 'Efectivo',
                      selected: paymentMethod != 'qr',
                      onTap: () => onSelectPaymentMethod('cash'),
                    ),
                    const SizedBox(width: 8),
                    _PaymentMiniButton(
                      icon: Icons.qr_code_2_rounded,
                      label: 'QR',
                      selected: paymentMethod == 'qr',
                      onTap: () => onSelectPaymentMethod('qr'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _OfferStepButton(icon: Icons.add_rounded, onTap: onIncreaseFare),
        ],
      ),
    );
  }
}

class _OfferStepButton extends StatelessWidget {
  const _OfferStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.primaryBlue,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PaymentMiniButton extends StatelessWidget {
  const _PaymentMiniButton({
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
      color: selected ? const Color(0xFFFFF3C4) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFACC15)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppBrand.textPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppBrand.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FareSummaryPill extends StatelessWidget {
  const _FareSummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_rounded, color: AppBrand.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: AppBrand.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteProgressBar extends StatelessWidget {
  const _RouteProgressBar({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.navigation_rounded,
          size: 18,
          color: Color(0xFFFACC15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 86,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ExpandedDetailsBlock extends StatelessWidget {
  const _ExpandedDetailsBlock({
    required this.originLabel,
    required this.destinationLabel,
    required this.summaryLabel,
    required this.serviceType,
    required this.onSelectTaxi,
    required this.onSelectMoto,
    required this.onEdit,
    required this.onClear,
    required this.statusAccent,
    required this.statusDetails,
    required this.secondaryActions,
    this.statusText,
    this.driverName,
    this.vehicleLabel,
    this.vehiclePlate,
    this.vehicleDetail,
    this.etaLabel,
  });

  final String originLabel;
  final String destinationLabel;
  final String summaryLabel;
  final String serviceType;
  final VoidCallback onSelectTaxi;
  final VoidCallback onSelectMoto;
  final VoidCallback onEdit;
  final VoidCallback onClear;
  final String? statusText;
  final Color statusAccent;
  final List<String> statusDetails;
  final List<RouteReviewActionData> secondaryActions;
  final String? driverName;
  final String? vehicleLabel;
  final String? vehiclePlate;
  final String? vehicleDetail;
  final String? etaLabel;

  @override
  Widget build(BuildContext context) {
    final hasDriverInfo =
        (driverName ?? '').isNotEmpty ||
        (vehicleLabel ?? '').isNotEmpty ||
        (vehiclePlate ?? '').isNotEmpty ||
        (etaLabel ?? '').isNotEmpty;
    final hasPlate = (vehiclePlate ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StopRow(
                icon: Icons.radio_button_checked_rounded,
                iconColor: const Color(0xFF16A34A),
                title: 'Origen',
                value: originLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StopRow(
          icon: Icons.flag_rounded,
          iconColor: AppBrand.primaryBlue,
          title: 'Destino',
          value: destinationLabel,
        ),
        const SizedBox(height: 10),
        if (statusText == null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactActionPill(
                icon: serviceType == 'taxi'
                    ? Icons.local_taxi_rounded
                    : Icons.two_wheeler_rounded,
                label: serviceType == 'taxi' ? 'Taxi' : 'Moto',
                onTap: serviceType == 'taxi' ? onSelectMoto : onSelectTaxi,
              ),
              _CompactActionPill(
                icon: Icons.edit_location_alt_rounded,
                label: 'Editar',
                onTap: onEdit,
              ),
              _CompactActionPill(
                icon: Icons.close_rounded,
                label: 'Quitar',
                onTap: onClear,
              ),
            ],
          ),
        if (hasDriverInfo ||
            statusText != null ||
            statusDetails.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasPlate) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      vehiclePlate!.trim(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (statusText != null)
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusText!,
                          style: const TextStyle(
                            color: AppBrand.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (hasDriverInfo) ...[
                  if (statusText != null) const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusAccent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: statusAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((driverName ?? '').isNotEmpty)
                              Text(
                                driverName!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppBrand.textPrimary,
                                ),
                              ),
                            if ((vehicleLabel ?? '').isNotEmpty ||
                                (vehicleDetail ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if ((vehicleLabel ?? '').isNotEmpty)
                                    vehicleLabel!,
                                  if ((vehicleDetail ?? '').isNotEmpty)
                                    vehicleDetail!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppBrand.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if ((etaLabel ?? '').isNotEmpty)
                        _MetricPill(
                          icon: Icons.schedule_rounded,
                          label: etaLabel!,
                          active: true,
                        ),
                    ],
                  ),
                ],
                if (statusDetails.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: statusDetails
                        .take(2)
                        .map(
                          (detail) => _MetricPill(
                            icon: Icons.info_outline_rounded,
                            label: detail,
                            active: false,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (secondaryActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: secondaryActions
                .map(
                  (action) => TextButton(
                    onPressed: action.onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppBrand.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      action.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppBrand.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textPrimary,
                    ),
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

class _CompactActionPill extends StatelessWidget {
  const _CompactActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppBrand.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      elevation: 6,
      shadowColor: const Color(0x120F172A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: AppBrand.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F1FF) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppBrand.primaryBlue : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppBrand.primaryBlue : AppBrand.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppBrand.primaryBlue : AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
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
      children: [
        if (isOrigin)
          const _OriginNavigationBadge()
        else
          Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppBrand.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginNavigationBadge extends StatelessWidget {
  const _OriginNavigationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8D9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFE27A), width: 1.2),
      ),
      child: const Icon(
        Icons.navigation_rounded,
        color: AppBrand.primaryBlue,
        size: 14,
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8FFF1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFFBBE7CD) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? const Color(0xFF16A34A) : AppBrand.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF14532D) : AppBrand.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
