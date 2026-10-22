import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

class AccountPageShell extends StatelessWidget {
  const AccountPageShell({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.actions,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F6FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF5F6FA),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: onBack == null
          ? null
          : IconButton(
              tooltip: 'Volver',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppBrand.textPrimary,
        ),
      ),
      actions: actions,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 648),
          child: child,
        ),
      ),
    ),
  );
}

class AccountIntro extends StatelessWidget {
  const AccountIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEFF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: AppBrand.secondaryBlue, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AppBrand.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(color: AppBrand.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}

class AccountStateCard extends StatelessWidget {
  const AccountStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onRetry,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE8EBF2)),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppBrand.secondaryBlue, size: 32),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppBrand.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppBrand.textSecondary, height: 1.5),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ],
    ),
  );
}
