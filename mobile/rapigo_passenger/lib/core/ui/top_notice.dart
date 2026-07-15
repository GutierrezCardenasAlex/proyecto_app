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
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNotice?.remove();

  final overlay = Overlay.of(context, rootOverlay: true);

  _activeTopNotice = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Positioned(
        top: topPadding + 12,
        left: 20,
        right: 20,
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
    final accent = _accentForTone(widget.tone);
    final title = _titleFor(widget.message);
    final subtitle = _subtitleFor(widget.message);

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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                      blurRadius: 26,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.70),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.icon ?? _resolveIcon(widget.tone),
                        color: _iconColorForTone(widget.tone),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF07142F),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF49607F),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                height: 1.22,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'ahora',
                          style: TextStyle(
                            color: Color(0xFF7C8AA3),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _NoticeTaxiIllustration(tone: widget.tone),
                      ],
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
        return Icons.local_taxi_rounded;
      case NoticeTone.warning:
        return Icons.local_taxi_rounded;
      case NoticeTone.error:
        return Icons.error_outline_rounded;
      case NoticeTone.info:
        return Icons.local_taxi_rounded;
    }
  }

  Color _accentForTone(NoticeTone tone) {
    switch (tone) {
      case NoticeTone.success:
      case NoticeTone.info:
        return const Color(0xFFFFD21E);
      case NoticeTone.warning:
        return const Color(0xFFFFE49A);
      case NoticeTone.error:
        return const Color(0xFFFFE2E5);
    }
  }

  Color _iconColorForTone(NoticeTone tone) {
    switch (tone) {
      case NoticeTone.error:
        return const Color(0xFFDC2626);
      case NoticeTone.success:
      case NoticeTone.warning:
      case NoticeTone.info:
        return const Color(0xFF082044);
    }
  }

  String _titleFor(String message) {
    final clean = message.trim();
    if (clean.isEmpty) {
      return 'RAPIGO';
    }
    if (clean.toLowerCase().contains('camino')) {
      return 'Tu taxi está llegando!';
    }
    if (clean.toLowerCase().contains('acept')) {
      return 'Conductor asignado!';
    }
    if (clean.toLowerCase().contains('lleg')) {
      return 'Tu taxi llegó!';
    }
    if (clean.toLowerCase().contains('finaliz')) {
      return 'Viaje finalizado';
    }
    if (clean.length <= 30) {
      return clean;
    }
    final sentenceEnd = clean.indexOf('.');
    if (sentenceEnd > 8 && sentenceEnd <= 42) {
      return clean.substring(0, sentenceEnd + 1);
    }
    return clean;
  }

  String? _subtitleFor(String message) {
    final clean = message.trim();
    if (clean.isEmpty || clean.length <= 30) {
      return null;
    }
    final title = _titleFor(clean);
    if (title == clean) {
      return null;
    }
    if (!clean.startsWith(title)) {
      return clean;
    }
    final subtitle = clean.substring(title.length).trim();
    return subtitle.isEmpty ? clean : subtitle;
  }
}

class _NoticeTaxiIllustration extends StatelessWidget {
  const _NoticeTaxiIllustration({required this.tone});

  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final carColor = tone == NoticeTone.error
        ? const Color(0xFFEF4444)
        : const Color(0xFF1D4ED8);
    return SizedBox(
      width: 62,
      height: 32,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 5,
            child: Container(
              width: 46,
              height: 18,
              decoration: BoxDecoration(
                color: carColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            top: 5,
            child: Container(
              width: 28,
              height: 15,
              decoration: BoxDecoration(
                color: carColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(left: 10, bottom: 0, child: const _NoticeWheel()),
          Positioned(right: 10, bottom: 0, child: const _NoticeWheel()),
        ],
      ),
    );
  }
}

class _NoticeWheel extends StatelessWidget {
  const _NoticeWheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
