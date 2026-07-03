// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

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
  });

  final String title;
  final String originLabel;
  final String destinationLabel;
  final String summaryLabel;
  final String fareLabel;
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final panelMaxHeight = compactMode
        ? screenHeight * 0.34
        : screenHeight * 0.46;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, compactMode ? 8 : 12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: _NavigationDistanceBadge(
                label: navigationBadgeLabel ?? distanceLabel,
                caption: navigationBadgeCaption ?? 'Llegada',
                icon: navigationBadgeIcon,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _RoundButton(
                icon: detailsExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                onTap: onToggleDetails,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.992),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 34,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: panelMaxHeight.clamp(220.0, 420.0),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compactMode ? 10 : 13,
                      16,
                      compactMode ? 11 : 15,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _RoundButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: onBack,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    durationLabel,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppBrand.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$distanceLabel · $fareLabel',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppBrand.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _RoundButton(
                              icon: Icons.tune_rounded,
                              onTap: onToggleDetails,
                            ),
                          ],
                        ),
                        SizedBox(height: compactMode ? 6 : 8),
                        _RouteProgressBar(accent: statusAccent),
                        SizedBox(height: compactMode ? 6 : 8),
                        if (detailsExpanded) ...[
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
                          SizedBox(height: compactMode ? 8 : 10),
                        ] else ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: compactMode ? 14 : 15,
                                fontWeight: FontWeight.w800,
                                color: AppBrand.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: compactMode ? 6 : 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: onPrimaryAction,
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryActionColor,
                              foregroundColor: Colors.white,
                              minimumSize: Size.fromHeight(
                                compactMode ? 48 : 54,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(primaryActionIcon, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  primaryActionLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
