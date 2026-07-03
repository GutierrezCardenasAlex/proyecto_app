import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/config/app_brand.dart';

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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: AppBrand.accentYellow,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 20),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0C1830),
            Color(0xFF0A1323),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Color(0xFF1A3A66)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFD9E7FF),
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
    return Material(
      color: const Color(0xFF0C1830),
      borderRadius: BorderRadius.circular(24),
      shadowColor: const Color(0x22000000),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0x191D4ED8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x551D4ED8)),
                ),
                child: Icon(icon, color: AppBrand.accentYellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFD9E7FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppBrand.accentYellow),
            ],
          ),
        ),
      ),
    );
  }
}
