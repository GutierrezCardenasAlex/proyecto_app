import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../shared/theme/rapigo_theme.dart';

class DriverPageShell extends StatelessWidget {
  const DriverPageShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    this.leading,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          metrics.pagePadding,
          metrics.sectionGap,
          metrics.pagePadding,
          metrics.pagePadding + 96,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: metrics.itemGap * 0.75),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: palette.accentYellow,
                      ),
                    ),
                    SizedBox(height: metrics.itemGap * 0.6),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                        height: 1.04,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: metrics.itemGap * 0.75),
                trailing!,
              ],
            ],
          ),
          SizedBox(height: metrics.sectionGap),
          child,
        ],
      ),
    );
  }
}

class DriverEmptyCard extends StatelessWidget {
  const DriverEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(metrics.pagePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surfacePrimary,
            palette.surfaceSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(metrics.radiusLarge),
        border: Border.all(color: palette.outlineStrong),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: palette.textPrimary,
            ),
          ),
          SizedBox(height: metrics.itemGap * 0.45),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverMenuTile extends StatelessWidget {
  const DriverMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: palette.surfacePrimary,
      borderRadius: BorderRadius.circular(metrics.radiusLarge),
      shadowColor: palette.shadowSoft,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(metrics.pagePadding),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: palette.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(metrics.radiusSmall),
                  border: Border.all(color: palette.accentBlue.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: palette.accentYellow),
              ),
              SizedBox(width: metrics.itemGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: palette.textPrimary,
                      ),
                    ),
                    SizedBox(height: metrics.itemGap * 0.35),
                    Text(
                      subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.accentYellow),
            ],
          ),
        ),
      ),
    );
  }
}
