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
  String? title,
  Duration duration = const Duration(seconds: 4),
}) {
  _activeTopNoticeTimer?.cancel();
  _activeTopNotice?.remove();
  _activeTopNotice = null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final accent =
      backgroundColor ??
      switch (tone) {
        NoticeTone.info => AppBrand.secondaryBlue,
        NoticeTone.success => const Color(0xFF047857),
        NoticeTone.warning => const Color(0xFFB45309),
        NoticeTone.error => AppBrand.danger,
      };
  late final OverlayEntry entry;
  void dismiss() {
    if (_activeTopNotice != entry) return;
    _activeTopNoticeTimer?.cancel();
    _activeTopNoticeTimer = null;
    _activeTopNotice = null;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Semantics(
            liveRegion: true,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, -12 * (1 - value)),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: const Color(0x220F172A),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          icon ??
                              switch (tone) {
                                NoticeTone.info => Icons.info_outline_rounded,
                                NoticeTone.success =>
                                  Icons.check_circle_outline_rounded,
                                NoticeTone.warning =>
                                  Icons.warning_amber_rounded,
                                NoticeTone.error => Icons.error_outline_rounded,
                              },
                          color: accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title ??
                                  switch (tone) {
                                    NoticeTone.info => 'Rápigo',
                                    NoticeTone.success => 'Listo',
                                    NoticeTone.warning => 'Ten en cuenta',
                                    NoticeTone.error => 'No se pudo completar',
                                  },
                              style: const TextStyle(
                                color: AppBrand.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(
                                color: AppBrand.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        onPressed: dismiss,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppBrand.textSecondary,
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
    ),
  );
  _activeTopNotice = entry;
  overlay.insert(entry);
  _activeTopNoticeTimer = Timer(duration, dismiss);
}
