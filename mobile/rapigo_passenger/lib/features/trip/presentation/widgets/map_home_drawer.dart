import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

/// A single destination entry point; service selection belongs to the ride flow.
class MapHomeDrawer extends StatelessWidget {
  const MapHomeDrawer({super.key, required this.onTapSearch, this.query});

  final VoidCallback onTapSearch;
  final String? query;

  @override
  Widget build(BuildContext context) {
    final label = query?.trim();
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x180F172A),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapSearch,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppBrand.accentYellow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppBrand.textPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label != null && label.isNotEmpty
                      ? label
                      : '¿A dónde quieres ir?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 22,
                color: AppBrand.secondaryBlue,
              ),
            ],
          ),
        ),
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
