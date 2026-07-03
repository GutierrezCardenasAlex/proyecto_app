import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InteractiveDestinationMarker extends StatefulWidget {
  const InteractiveDestinationMarker({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.size = 32,
    this.showLabel = true,
    this.showEditBadge = false,
    this.showShell = true,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final bool showLabel;
  final bool showEditBadge;
  final bool showShell;

  @override
  State<InteractiveDestinationMarker> createState() =>
      _InteractiveDestinationMarkerState();
}

class _InteractiveDestinationMarkerState
    extends State<InteractiveDestinationMarker> {
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _animateIn = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _animateIn ? 1 : 0.82,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _animateIn ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showLabel)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEE111214),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFFFFF4EC),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (widget.showLabel) const SizedBox(height: 6),
            SizedBox(
              width: widget.size + 34,
              height: widget.size + 42,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  _PremiumDestinationPin(
                    color: widget.color,
                    size: widget.size,
                    showShell: widget.showShell,
                    icon: widget.icon,
                  ),
                  if (widget.showEditBadge)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF111214),
                            width: 2,
                          ),
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
        ),
      ),
    );
  }
}

class _PremiumDestinationPin extends StatelessWidget {
  const _PremiumDestinationPin({
    required this.color,
    required this.size,
    required this.showShell,
    required this.icon,
  });

  final Color color;
  final double size;
  final bool showShell;
  final IconData icon;

  IconData get _resolvedIcon {
    if (icon == Icons.flag_rounded || icon == Icons.outlined_flag_rounded) {
      return Icons.location_on_rounded;
    }
    if (icon == Icons.place_rounded) {
      return Icons.adjust_rounded;
    }
    return Icons.location_on_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final headSize = size + (showShell ? 8 : 2);
    final tailSize = size * 0.34;

    return SizedBox(
      width: headSize + 18,
      height: headSize + 18,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 4,
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: tailSize,
                height: tailSize,
                decoration: BoxDecoration(
                  color: showShell ? const Color(0xFF111214) : color,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: headSize,
            height: headSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showShell ? const Color(0xFF111214) : Colors.white,
              border: Border.all(
                color: showShell ? color.withValues(alpha: 0.45) : color,
                width: showShell ? 2.2 : 2.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: showShell ? 0.18 : 0.28),
                  blurRadius: showShell ? 14 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: headSize * 0.5,
                height: headSize * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                child: Center(
                  child: Icon(
                    _resolvedIcon,
                    color: Colors.white,
                    size: headSize * 0.24,
                  ),
                ),
              ),
            ),
          ),
          if (!showShell)
            Positioned(
              bottom: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFACC15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22FACC15),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
