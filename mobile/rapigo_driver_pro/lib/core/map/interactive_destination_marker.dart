import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveDestinationMarker extends StatelessWidget {
  const InteractiveDestinationMarker({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.size = 32,
    this.showLabel = true,
    this.showEditBadge = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final bool showLabel;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xEE111214),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFFF4EC),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (showLabel) const SizedBox(height: 6),
        SizedBox(
          width: size + 28,
          height: size + 28,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size + 10,
                height: size + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141518),
                  border: Border.all(color: color.withValues(alpha: 0.42), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: size),
              ),
              if (showEditBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF111214), width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 11,
                      color: Color(0xFF0B1210),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
