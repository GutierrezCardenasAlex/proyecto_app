import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_brand.dart';

class MapNavigationBanner extends StatelessWidget {
  const MapNavigationBanner({
    super.key,
    required this.currentLabel,
    required this.currentDetail,
    this.targetLabel,
    this.targetDetail,
    this.remainingDistanceLabel,
    this.remainingDurationLabel,
    this.accentColor = AppBrand.primaryBlue,
    this.targetCaption = 'Destino',
  });

  final String currentLabel;
  final String currentDetail;
  final String? targetLabel;
  final String? targetDetail;
  final String? remainingDistanceLabel;
  final String? remainingDurationLabel;
  final Color accentColor;
  final String targetCaption;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppBrand.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppBrand.surfaceMuted),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapLine(
            icon: Icons.near_me_rounded,
            iconColor: accentColor,
            title: 'Vas por',
            label: currentLabel,
            detail: currentDetail,
          ),
          if ((targetLabel ?? '').trim().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppBrand.surfaceMuted),
            ),
            _MapLine(
              icon: Icons.flag_rounded,
              iconColor: AppBrand.accentYellow,
              title: targetCaption,
              label: targetLabel!,
              detail: targetDetail ?? 'Punto del viaje',
            ),
          ],
          if ((remainingDistanceLabel ?? '').trim().isNotEmpty ||
              (remainingDurationLabel ?? '').trim().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppBrand.surfaceMuted),
            ),
            Row(
              children: [
                if ((remainingDistanceLabel ?? '').trim().isNotEmpty)
                  Expanded(
                    child: _MetricChip(
                      icon: Icons.route_rounded,
                      label: 'Distancia',
                      value: remainingDistanceLabel!,
                      color: accentColor,
                    ),
                  ),
                if ((remainingDistanceLabel ?? '').trim().isNotEmpty &&
                    (remainingDurationLabel ?? '').trim().isNotEmpty)
                  const SizedBox(width: 8),
                if ((remainingDurationLabel ?? '').trim().isNotEmpty)
                  Expanded(
                    child: _MetricChip(
                      icon: Icons.schedule_rounded,
                      label: 'Tiempo',
                      value: remainingDurationLabel!,
                      color: AppBrand.accentYellow,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MapNavigationTriggerButton extends StatelessWidget {
  const MapNavigationTriggerButton({
    super.key,
    required this.currentLabel,
    required this.currentDetail,
    this.targetLabel,
    this.targetDetail,
    this.remainingDistanceLabel,
    this.remainingDurationLabel,
    this.accentColor = AppBrand.primaryBlue,
    this.targetCaption = 'Destino',
    this.iconOnly = false,
    this.onOpenOfflineInfo,
  });

  final String currentLabel;
  final String currentDetail;
  final String? targetLabel;
  final String? targetDetail;
  final String? remainingDistanceLabel;
  final String? remainingDurationLabel;
  final Color accentColor;
  final String targetCaption;
  final bool iconOnly;
  final VoidCallback? onOpenOfflineInfo;

  @override
  Widget build(BuildContext context) {
    void handleTap() {
      showMapNavigationSheet(
        context,
        currentLabel: currentLabel,
        currentDetail: currentDetail,
        targetLabel: targetLabel,
        targetDetail: targetDetail,
        remainingDistanceLabel: remainingDistanceLabel,
        remainingDurationLabel: remainingDurationLabel,
        accentColor: accentColor,
        targetCaption: targetCaption,
        onOpenOfflineInfo: onOpenOfflineInfo,
      );
    }

    if (iconOnly) {
      return IconButton(
        onPressed: handleTap,
        style: IconButton.styleFrom(
          backgroundColor: AppBrand.surface.withValues(alpha: 0.96),
          foregroundColor: accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppBrand.surfaceMuted),
          ),
          padding: const EdgeInsets.all(14),
        ),
        icon: const Icon(Icons.explore_rounded, size: 20),
        tooltip: 'Detalles del mapa',
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: handleTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppBrand.surface.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppBrand.surfaceMuted),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 8),
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
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.explore_rounded,
                  size: 18,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detalles del mapa',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textPrimary,
                    ),
                  ),
                  Text(
                    'Ver calle, destino y distancia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppBrand.textSecondary,
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

Future<void> showMapNavigationSheet(
  BuildContext context, {
  required String currentLabel,
  required String currentDetail,
  String? targetLabel,
  String? targetDetail,
  String? remainingDistanceLabel,
  String? remainingDurationLabel,
  Color accentColor = AppBrand.primaryBlue,
  String targetCaption = 'Destino',
  VoidCallback? onOpenOfflineInfo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppBrand.surface,
                  foregroundColor: AppBrand.textPrimary,
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppBrand.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppBrand.surfaceMuted),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detalles del mapa',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  MapNavigationBanner(
                    currentLabel: currentLabel,
                    currentDetail: currentDetail,
                    targetLabel: targetLabel,
                    targetDetail: targetDetail,
                    remainingDistanceLabel: remainingDistanceLabel,
                    remainingDurationLabel: remainingDurationLabel,
                    accentColor: accentColor,
                    targetCaption: targetCaption,
                  ),
                  if (onOpenOfflineInfo != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onOpenOfflineInfo();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppBrand.primaryBlue,
                          side: const BorderSide(color: AppBrand.surfaceMuted),
                          backgroundColor: AppBrand.surfaceMuted.withValues(alpha: 0.65),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.offline_bolt_rounded, size: 18),
                        label: Text(
                          'Ver modo offline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MapLine extends StatelessWidget {
  const _MapLine({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppBrand.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppBrand.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
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
