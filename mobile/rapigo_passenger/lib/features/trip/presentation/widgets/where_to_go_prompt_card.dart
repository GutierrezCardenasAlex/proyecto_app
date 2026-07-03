import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

class WhereToGoPromptCard extends StatelessWidget {
  const WhereToGoPromptCard({
    super.key,
    required this.onTap,
    this.label = '¿A dónde vamos?',
    this.showArrow = true,
  });

  final VoidCallback onTap;
  final String label;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppBrand.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              if (showArrow)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppBrand.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
