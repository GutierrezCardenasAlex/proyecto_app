import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeTopNotice;
Timer? _activeTopNoticeTimer;

void showTopNotice(
  BuildContext context,
  String message, {
  Color backgroundColor = const Color(0xFFC2410C),
  Color foregroundColor = Colors.white,
  IconData? icon,
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNotice?.remove();

  final overlay = Overlay.of(context, rootOverlay: true);

  _activeTopNotice = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Positioned(
        top: topPadding + 14,
        left: 24,
        right: 24,
        child: IgnorePointer(
          ignoring: true,
          child: _TopNoticeCard(
            message: message,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            icon: icon,
          ),
        ),
      );
    },
  );

  overlay.insert(_activeTopNotice!);
  _activeTopNoticeTimer = Timer(const Duration(seconds: 4), () {
    _activeTopNotice?.remove();
    _activeTopNotice = null;
    _activeTopNoticeTimer = null;
  });
}

class _TopNoticeCard extends StatefulWidget {
  const _TopNoticeCard({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  State<_TopNoticeCard> createState() => _TopNoticeCardState();
}

class _TopNoticeCardState extends State<_TopNoticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.18),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon ?? _resolveIcon(widget.backgroundColor),
                      color: widget.foregroundColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.foregroundColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _resolveIcon(Color backgroundColor) {
    final argb = backgroundColor.toARGB32();
    if (argb == const Color(0xFF93000A).toARGB32()) {
      return Icons.error_outline_rounded;
    }
    if (argb == const Color(0xFFF97316).toARGB32() ||
        argb == const Color(0xFFC2410C).toARGB32()) {
      return Icons.notifications_active_rounded;
    }
    return Icons.info_outline_rounded;
  }
}
