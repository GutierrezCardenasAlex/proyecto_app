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
  bool iconOnly = false,
  bool rightSide = false,
  VoidCallback? onTap,
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNotice?.remove();

  final overlay = Overlay.of(context, rootOverlay: true);
  final isConnectivityError = _looksLikeBackendConnectivityError(message);
  final effectiveIconOnly = iconOnly || isConnectivityError;
  final effectiveRightSide = rightSide || isConnectivityError;
  final effectiveTone = isConnectivityError ? NoticeTone.error : tone;
  final effectiveIcon = isConnectivityError ? Icons.wifi_off_rounded : icon;
  final effectiveMessage = effectiveIconOnly ? '' : message;

  _activeTopNotice = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      final child = _TopNoticeCard(
        message: effectiveMessage,
        backgroundColor: backgroundColor ?? _backgroundForTone(effectiveTone),
        foregroundColor: foregroundColor ?? _foregroundForTone(effectiveTone),
        icon: effectiveIcon,
        tone: effectiveTone,
        compact: compact,
        iconOnly: effectiveIconOnly,
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

      if (effectiveRightSide) {
        return Positioned(
          top: topPadding + 118,
          right: 16,
          child: IgnorePointer(ignoring: onTap == null, child: child),
        );
      }

      if (centered) {
        return Positioned(
          top: topPadding + 64,
          left: horizontalInset + 8,
          right: horizontalInset + 8,
          child: IgnorePointer(ignoring: onTap == null, child: child),
        );
      }

      return Positioned(
        top: topPadding + topOffset,
        left: horizontalInset,
        right: horizontalInset,
        child: IgnorePointer(ignoring: onTap == null, child: child),
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

bool _looksLikeBackendConnectivityError(String message) {
  final text = message.toLowerCase();
  return text.contains('backend') ||
      text.contains('servidor') ||
      text.contains('server') ||
      text.contains('socket') ||
      text.contains('websocket') ||
      text.contains('connection refused') ||
      text.contains('connection failed') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('dioexception') ||
      text.contains('clientexception') ||
      text.contains('/api');
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
    required this.iconOnly,
    required this.onTap,
    this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final NoticeTone tone;
  final IconData? icon;
  final bool compact;
  final bool iconOnly;
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
        position: Tween<Offset>(begin: const Offset(0, -0.18), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
            ),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: widget.iconOnly
                  ? const BoxConstraints.tightFor(width: 44, height: 44)
                  : BoxConstraints(maxWidth: widget.compact ? 320 : 380),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(
                  widget.iconOnly ? 22 : (widget.compact ? 14 : 16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: widget.iconOnly
                      ? EdgeInsets.zero
                      : EdgeInsets.symmetric(
                          horizontal: widget.compact ? 12 : 16,
                          vertical: widget.compact ? 9 : 12,
                        ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(
                      widget.iconOnly ? 22 : (widget.compact ? 14 : 16),
                    ),
                    border: Border.all(
                      color: widget.foregroundColor.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.backgroundColor.withValues(alpha: 0.28),
                        blurRadius: widget.iconOnly ? 12 : 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: widget.iconOnly
                      ? Icon(
                          widget.icon ?? _resolveIcon(widget.tone),
                          color: widget.foregroundColor,
                          size: 21,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.icon ?? _resolveIcon(widget.tone),
                              color: widget.foregroundColor,
                              size: widget.compact ? 16 : 18,
                            ),
                            SizedBox(width: widget.compact ? 7 : 9),
                            Expanded(
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: widget.foregroundColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.compact ? 12 : 13,
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
