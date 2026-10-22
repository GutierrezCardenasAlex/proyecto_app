import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
import '../../../auth/data/auth_repository.dart';
import 'ride_tab.dart';

class RideLauncherView extends ConsumerWidget {
  const RideLauncherView({
    super.key,
    required this.onChooseMode,
    required this.onOpenProfile,
    required this.onOpenDestinationSearch,
    required this.onOpenTrips,
  });

  final ValueChanged<RideMode> onChooseMode;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDestinationSearch;
  final VoidCallback onOpenTrips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final displayName = session.firstName.trim().isNotEmpty
        ? session.firstName.trim()
        : (session.fullName.trim().isNotEmpty
              ? session.fullName.trim().split(' ').first
              : 'Pasajero');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppBrand.accentYellow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: AppBrand.textPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Rápigo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppBrand.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppBrand.secondaryBlue,
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          'Potosí',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppBrand.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Hola, $displayName',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: AppBrand.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu próximo viaje\nempieza aquí.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      height: 1.16,
                      letterSpacing: -1.1,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DestinationCard(onTap: onOpenDestinationSearch),
                  const SizedBox(height: 30),
                  Text(
                    'Muévete a tu manera',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Elige cómo quieres comenzar tu viaje.',
                    style: TextStyle(
                      color: AppBrand.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RideOption(
                    title: 'Pedir taxi',
                    description: 'Elige tu destino y solicita un viaje.',
                    icon: Icons.local_taxi_rounded,
                    iconBackground: AppBrand.accentYellow,
                    onTap: () => onChooseMode(RideMode.destino),
                  ),
                  const SizedBox(height: 12),
                  _RideOption(
                    title: 'Tomar taxi',
                    description: 'Explora los taxis cercanos en el mapa.',
                    icon: Icons.near_me_rounded,
                    iconBackground: const Color(0xFFE8EEFF),
                    onTap: () => onChooseMode(RideMode.cercano),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _HomeNavigation(
        onOpenTrips: onOpenTrips,
        onOpenProfile: onOpenProfile,
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.secondaryBlue,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.route_rounded,
                    color: AppBrand.accentYellow,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'VAMOS A TU DESTINO',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '¿A dónde vamos?',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 26,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Busca una dirección o elige un punto en el mapa.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppBrand.secondaryBlue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Buscar destino',
                        style: TextStyle(
                          color: AppBrand.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppBrand.secondaryBlue,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideOption extends StatelessWidget {
  const _RideOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8EBF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: AppBrand.secondaryBlue, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        color: AppBrand.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppBrand.secondaryBlue,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavigation extends StatelessWidget {
  const _HomeNavigation({
    required this.onOpenTrips,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenTrips;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8EBF2))),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppBrand.accentYellow,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppBrand.secondaryBlue : AppBrand.textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.all(
            const IconThemeData(color: AppBrand.secondaryBlue, size: 24),
          ),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) onOpenTrips();
            if (index == 2) onOpenProfile();
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              label: 'Viajes',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
