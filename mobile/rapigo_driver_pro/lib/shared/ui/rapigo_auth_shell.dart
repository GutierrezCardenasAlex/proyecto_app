import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RapigoAuthShell extends StatelessWidget {
  const RapigoAuthShell({
    super.key,
    required this.brand,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String brand;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 36,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                brand,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              child,
              if (footer != null) ...[
                const SizedBox(height: 18),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
