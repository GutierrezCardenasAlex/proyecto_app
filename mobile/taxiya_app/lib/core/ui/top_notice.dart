import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeTopNotice;
Timer? _activeTopNoticeTimer;

enum NoticeTone { info, success, warning, error }

void showTopNotice(
  BuildContext context,
  String message, {
  NoticeTone tone = NoticeTone.info,
  Color? backgroundColor,
  Color? foregroundColor,
  IconData? icon,
  Duration duration = const Duration(seconds: 4),
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
            backgroundColor: backgroundColor ?? _backgroundForTone(tone),
            foregroundColor: foregroundColor ?? _foregroundForTone(tone),
            icon: icon,
            tone: tone,
          ),
        ),
      );
    },
  );

  overlay.insert(_activeTopNotice!);
  _activeTopNoticeTimer = Timer(duration, () {
    _activeTopNotice?.remove();
    _activeTopNotice = null;
    _activeTopNoticeTimer = null;
  });
}

Color _backgroundForTone(NoticeTone tone) {
  switch (tone) {
    case NoticeTone.success:
      return const Color(0xFF15803D);
    case NoticeTone.warning:
      return const Color(0xFFC2410C);
    case NoticeTone.error:
      return const Color(0xFFB91C1C);
    case NoticeTone.info:
      return const Color(0xFF1D4ED8);
  }
}

Color _foregroundForTone(NoticeTone tone) {
  switch (tone) {
    case NoticeTone.success:
    case NoticeTone.warning:
    case NoticeTone.error:
    case NoticeTone.info:
      return Colors.white;
  }
}

class _TopNoticeCard extends StatefulWidget {
  const _TopNoticeCard({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.tone,
    this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final NoticeTone tone;
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
                  border: Border.all(
                    color: widget.foregroundColor.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.28),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon ?? _resolveIcon(widget.tone),
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

  IconData _resolveIcon(NoticeTone tone) {
    switch (tone) {
      case NoticeTone.success:
        return Icons.check_circle_outline_rounded;
      case NoticeTone.warning:
        return Icons.notifications_active_rounded;
      case NoticeTone.error:
        return Icons.error_outline_rounded;
      case NoticeTone.info:
        return Icons.info_outline_rounded;
    }
  }
}
