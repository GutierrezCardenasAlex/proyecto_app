import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_brand.dart';

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
  double topOffset = 14,
  double horizontalInset = 24,
  bool compact = false,
  bool centered = false,
  VoidCallback? onTap,
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNotice?.remove();

  final overlay = Overlay.of(context, rootOverlay: true);

  _activeTopNotice = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      final child = _TopNoticeCard(
        message: message,
        backgroundColor: backgroundColor ?? _backgroundForTone(tone),
        foregroundColor: foregroundColor ?? _foregroundForTone(tone),
        icon: icon,
        tone: tone,
        compact: compact,
        onTap: onTap == null
            ? null
            : () {
                _activeTopNoticeTimer?.cancel();
                _activeTopNotice?.remove();
                _activeTopNotice = null;
                _activeTopNoticeTimer = null;
                onTap();
              },
      );

      if (centered) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: onTap == null,
            child: Align(
              alignment: const Alignment(0, -0.06),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                child: child,
              ),
            ),
          ),
        );
      }

      return Positioned(
        top: topPadding + topOffset,
        left: horizontalInset,
        right: horizontalInset,
        child: IgnorePointer(
          ignoring: onTap == null,
          child: child,
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
      return AppBrand.success;
    case NoticeTone.warning:
      return AppBrand.accentYellow;
    case NoticeTone.error:
      return AppBrand.danger;
    case NoticeTone.info:
      return AppBrand.primaryBlue;
  }
}

Color _foregroundForTone(NoticeTone tone) {
  switch (tone) {
    case NoticeTone.success:
    case NoticeTone.error:
    case NoticeTone.info:
      return Colors.white;
    case NoticeTone.warning:
      return AppBrand.textPrimary;
  }
}

class _TopNoticeCard extends StatefulWidget {
  const _TopNoticeCard({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.tone,
    required this.compact,
    required this.onTap,
    this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final NoticeTone tone;
  final IconData? icon;
  final bool compact;
  final VoidCallback? onTap;

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
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(widget.compact ? 16 : 18),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 14 : 18,
                    vertical: widget.compact ? 11 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(widget.compact ? 16 : 18),
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
                        size: widget.compact ? 18 : 20,
                      ),
                      SizedBox(width: widget.compact ? 8 : 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.foregroundColor,
                            fontWeight: FontWeight.w700,
                            fontSize: widget.compact ? 13 : 14,
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
