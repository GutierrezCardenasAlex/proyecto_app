import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../driver/features/auth/data/auth_repository.dart' as driver_auth;
import '../driver/features/driver/presentation/driver_home_page.dart';
import '../features/auth/data/auth_repository.dart' as passenger_auth;
import '../features/trip/presentation/passenger_home_page.dart';

enum _AppRole { passenger, driver }

class TaxiYaUnifiedApp extends StatelessWidget {
  const TaxiYaUnifiedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flash Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.manropeTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.dark,
          primary: const Color(0xFFF97316),
          secondary: const Color(0xFFC2410C),
          surface: const Color(0xFF151517),
        ),
        scaffoldBackgroundColor: const Color(0xFF111214),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1B1B1F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF111214),
          elevation: 0,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFF4EC),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFF97316)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A1D),
          indicatorColor: const Color(0xFFF97316),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: selected ? const Color(0xFF0F0F10) : const Color(0xFFFFC89B),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? const Color(0xFF0F0F10) : const Color(0xFFFFC89B),
            );
          }),
        ),
        useMaterial3: true,
      ),
      home: const UnifiedEntryPage(),
    );
  }
}

class UnifiedEntryPage extends ConsumerStatefulWidget {
  const UnifiedEntryPage({super.key});

  @override
  ConsumerState<UnifiedEntryPage> createState() => _UnifiedEntryPageState();
}

class _UnifiedEntryPageState extends ConsumerState<UnifiedEntryPage> {
  bool _showSplash = true;
  _AppRole? _preferredRole;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialState);
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('taxiya_last_role');
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) {
      return;
    }
    setState(() {
      _preferredRole = switch (savedRole) {
        'driver' => _AppRole.driver,
        'passenger' => _AppRole.passenger,
        _ => null,
      };
      _showSplash = false;
    });
  }

  Future<void> _selectRole(BuildContext context, _AppRole role) async {
    final navigator = Navigator.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('taxiya_last_role', role.name);
    if (!mounted) {
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => role == _AppRole.passenger ? const PassengerHomePage() : const DriverHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passengerSession = ref.watch(passenger_auth.sessionProvider);
    final driverSession = ref.watch(driver_auth.driverSessionProvider);

    if (_showSplash || passengerSession.isRestoring || driverSession.isRestoring) {
      return const _TaxiYaSplashScreen();
    }

    if (passengerSession.isAuthenticated &&
        (_preferredRole == _AppRole.passenger || !driverSession.loggedIn)) {
      return const PassengerHomePage();
    }

    if (driverSession.loggedIn &&
        (_preferredRole == _AppRole.driver || !passengerSession.isAuthenticated)) {
      return const DriverHomePage();
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF111214), Color(0xFF2A1406)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -140,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -130,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenido a Flash Go',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFFF4EC),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Todo esta en una sola aplicacion. Elige si vas a entrar como pasajero o como conductor y te llevamos a tu propio acceso.',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            height: 1.5,
                            color: const Color(0xFFFFC89B),
                          ),
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 720;
                            final passengerCard = _RoleCard(
                              title: 'Modo pasajero',
                              subtitle: 'Pide tu taxi, sigue el viaje y administra tu cuenta.',
                              badge: passengerSession.isAuthenticated ? 'Sesion activa' : 'Acceso pasajero',
                              icon: Icons.person_pin_circle_rounded,
                              accent: const Color(0xFFF97316),
                              onPressed: () => _selectRole(context, _AppRole.passenger),
                            );
                            final driverCard = _RoleCard(
                              title: 'Modo conductor',
                              subtitle: 'Recibe ofertas, activa disponibilidad y administra tu vehiculo.',
                              badge: driverSession.loggedIn ? 'Sesion activa' : 'Acceso conductor',
                              icon: Icons.local_shipping_rounded,
                              accent: const Color(0xFFC2410C),
                              onPressed: () => _selectRole(context, _AppRole.driver),
                            );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: passengerCard),
                                  const SizedBox(width: 20),
                                  Expanded(child: driverCard),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                passengerCard,
                                const SizedBox(height: 20),
                                driverCard,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxiYaSplashScreen extends StatefulWidget {
  const _TaxiYaSplashScreen();

  @override
  State<_TaxiYaSplashScreen> createState() => _TaxiYaSplashScreenState();
}

class _TaxiYaSplashScreenState extends State<_TaxiYaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0F10), Color(0xFFC2410C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1D).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: const Color(0x55F97316)),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Color(0xFFF97316),
                      size: 54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Flash Go',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFFF4EC),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Movilidad segura en una sola app',
                    style: GoogleFonts.manrope(
                      color: const Color(0xFFFFC89B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F0F10).withValues(alpha: 0.06),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
          child: Icon(icon, color: accent, size: 34),
        ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF25252B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: const Color(0xFFFFC89B),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFF4EC),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 15,
              height: 1.5,
              color: const Color(0xFFFFC89B),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Entrar'),
            ),
          ),
        ],
      ),
    );
  }
}
