import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

class MapHomeDrawer extends StatelessWidget {
  const MapHomeDrawer({
    super.key,
    required this.expanded,
    required this.onTapSearch,
    required this.onToggleExpanded,
    required this.onTapSettings,
    this.query,
    this.showLocationTile = true,
    this.premiumStyle = false,
    this.primaryActionLabel = 'ir',
    this.onPrimaryAction,
    this.showMoreButton = true,
    this.forceExpanded = false,
  });

  final bool expanded;
  final VoidCallback onTapSearch;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTapSettings;
  final String? query;
  final bool showLocationTile;
  final bool premiumStyle;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool showMoreButton;
  final bool forceExpanded;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isExpanded = forceExpanded || expanded;

    if (premiumStyle) {
      return _PremiumMapHomeDrawerLayout(
        bottomInset: bottomInset,
        label: (query?.trim().isNotEmpty ?? false)
            ? (query?.trim() ?? '¿A dónde vas?')
            : '¿A dónde vas?',
        onTapSearch: onTapSearch,
        expanded: expanded,
        onToggleExpanded: onToggleExpanded,
        onTapSettings: onTapSettings,
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.985),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 38,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD6D8DE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
              child: _LargeWhereToGoCard(
                  onTap: onTapSearch,
                  label: (query?.trim().isNotEmpty ?? false)
                      ? (query?.trim() ?? '¿A dónde vas?')
                      : '¿A dónde vas?',
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: const Color(0xFF1D4ED8),
                shape: const CircleBorder(),
                elevation: 12,
                shadowColor: const Color(0x331D4ED8),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onToggleExpanded,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Icon(
                  isExpanded ? Icons.close_rounded : Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showLocationTile) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD8E8FF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Potosí',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Departamento de Potosí',
                          style: TextStyle(
                            color: AppBrand.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '7 min',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isExpanded) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapSettings,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD8E8FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8D9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                        Icons.settings_rounded,
                          color: Color(0xFFB45309),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configuraciones',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppBrand.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumMapHomeDrawerLayout extends StatelessWidget {
  const _PremiumMapHomeDrawerLayout({
    required this.bottomInset,
    required this.label,
    required this.onTapSearch,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTapSettings,
  });

  final double bottomInset;
  final String label;
  final VoidCallback onTapSearch;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTapSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + bottomInset),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF9D9), Color(0xFFFFF5C2)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border.all(color: const Color(0xFF1D4ED8), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261D4ED8),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _PremiumWhereToGoCard(
                  label: label,
                  onTap: onTapSearch,
                ),
              ),
              const SizedBox(width: 14),
              _PremiumToggleActionButton(
                expanded: expanded,
                onTap: onToggleExpanded,
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            _PremiumSettingsTile(onTap: onTapSettings),
          ],
        ],
      ),
    );
  }
}

class LargeNavigatorHeader extends StatelessWidget {
  const LargeNavigatorHeader({
    super.key,
    required this.trailing,
    this.locationLabel = 'Potosí',
  });

  final Widget trailing;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 34,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16171A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                Positioned(
                  top: 7,
                  child: Container(
                    width: 22,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: AppBrand.accentYellow,
                      borderRadius: BorderRadius.all(Radius.elliptical(16, 24)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33FACC15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NAVEGADOR',
                style: GoogleFonts.oswald(
                  fontSize: 42,
                  height: 0.94,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: AppBrand.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locationLabel,
                    style: const TextStyle(
                      color: AppBrand.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppBrand.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _LargeWhereToGoCard extends StatelessWidget {
  const _LargeWhereToGoCard({
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D4ED8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumWhereToGoCard extends StatelessWidget {
  const _PremiumWhereToGoCard({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF1D4ED8), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x201D4ED8),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x331D4ED8),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumToggleActionButton extends StatelessWidget {
  const _PremiumToggleActionButton({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1D4ED8),
      shape: const CircleBorder(),
      elevation: 14,
      shadowColor: const Color(0x331D4ED8),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 78,
          height: 78,
          child: Center(
            child: Icon(
              expanded ? Icons.close_rounded : Icons.more_horiz_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumSettingsTile extends StatelessWidget {
  const _PremiumSettingsTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF1D4ED8), width: 2.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFACC15), Color(0xFFFFD84D)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.settings_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Configuraciones',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF1D4ED8),
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
