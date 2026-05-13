import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MapNavigationBanner extends StatelessWidget {
  const MapNavigationBanner({
    super.key,
    required this.currentLabel,
    required this.currentDetail,
    this.targetLabel,
    this.targetDetail,
    this.remainingDistanceLabel,
    this.remainingDurationLabel,
    this.accentColor = const Color(0xFFF97316),
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
        color: const Color(0xEE121214),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33FFFFFF)),
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
              child: Divider(height: 1, color: Color(0x22FFFFFF)),
            ),
            _MapLine(
              icon: Icons.flag_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: targetCaption,
              label: targetLabel!,
              detail: targetDetail ?? 'Punto del viaje',
            ),
          ],
          if ((remainingDistanceLabel ?? '').trim().isNotEmpty ||
              (remainingDurationLabel ?? '').trim().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0x22FFFFFF)),
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
                      color: const Color(0xFF22C55E),
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
    this.accentColor = const Color(0xFFF97316),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet<void>(
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
                        backgroundColor: const Color(0xE6121214),
                        foregroundColor: const Color(0xFFFFF4EC),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
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
                ],
              ),
            ),
          ),
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xEE121214),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x33FFFFFF)),
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
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  Text(
                    'Ver calle, destino y distancia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFD8BF),
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
                  color: const Color(0xFFFFD8BF),
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
                  color: const Color(0xFFFFF4EC),
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
                  color: const Color(0xFFBFC6D1),
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
                    color: const Color(0xFFFFD8BF),
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
                    color: const Color(0xFFFFF4EC),
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
