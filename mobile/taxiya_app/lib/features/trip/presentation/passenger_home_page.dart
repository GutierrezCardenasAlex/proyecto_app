import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../auth/presentation/passenger_profile_completion_page.dart';
import '../../../core/notifications/local_notifications.dart';
import 'pages/detail_pages.dart';
import 'widgets/account_tab.dart';
import 'widgets/activity_tab.dart';
import 'widgets/app_drawer.dart';
import 'widgets/ride_tab.dart';

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _sessionRefreshTimer;
  int _selectedIndex = 0;
  String _activeDrawerItem = 'Inicio';

  @override
  void initState() {
    super.initState();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => Future<void>.microtask(_refreshPassengerSession),
    );
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPassengerSession() async {
    final earnedFreeTrip = await ref.read(sessionProvider.notifier).refreshSessionStatus();
    if (earnedFreeTrip) {
      await LocalNotifications.ensureInitialized();
      await LocalNotifications.show(
        id: 3001,
        title: 'Tienes un viaje gratis',
        body: 'Completaste 5 viajes. Tu siguiente viaje sera gratis a donde sea.',
      );
    }
  }

  void _handleDrawerSelection(String item) {
    switch (item) {
      case 'Inicio':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 0;
        });
        break;
      case 'Tus viajes':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 1;
        });
        break;
      case 'Cuenta':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 2;
        });
        break;
      case 'Promociones':
        _openPage(const PromotionsPage(), drawerItem: item);
        break;
      case 'Notificaciones':
        _openPage(const NotificationsPage(), drawerItem: item);
        break;
      case 'Soporte':
        _openPage(const SupportPage(), drawerItem: item);
        break;
      case 'Configuraciones':
        _openPage(const SettingsPage(), drawerItem: item);
        break;
    }
  }

  void _openPage(Widget page, {String? drawerItem}) {
    if (drawerItem != null) {
      setState(() => _activeDrawerItem = drawerItem);
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _goHomeFromSection() {
    setState(() {
      _activeDrawerItem = 'Inicio';
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.isAuthenticated) {
      return const _LoginShell();
    }

    if (session.deviceStatus != 'AUTORIZADO') {
      return _PassengerAccessPendingShell(deviceStatus: session.deviceStatus);
    }

    if (!session.profileCompleted) {
      return const PassengerProfileCompletionPage();
    }

    final pages = [
      RideTab(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      ActivityTab(
        onBack: _goHomeFromSection,
      ),
      AccountTab(
        onBack: _goHomeFromSection,
        onOpenProfile: () => _openPage(const ProfilePage(), drawerItem: 'Configuraciones'),
        onOpenNotifications: () => _openPage(const NotificationsPage(), drawerItem: 'Notificaciones'),
        onOpenSettings: () => _openPage(const SettingsPage(), drawerItem: 'Configuraciones'),
        onOpenSupport: () => _openPage(const SupportPage(), drawerItem: 'Soporte'),
      ),
    ];

    return Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(
          fullName: session.fullName,
          phone: session.phone,
          token: session.token,
          onLogout: () => ref.read(sessionProvider.notifier).signOut(),
          activeItem: _activeDrawerItem,
          onSelect: _handleDrawerSelection,
          promoProgress: session.promoProgressCount,
          totalTrips: session.completedTripCount,
          freeTripCredits: session.freeTripCredits,
          promoEnabled: session.promoEnabled,
          promoCycleLength: session.promoCycleLength,
          onOpenProfile: () {
            Navigator.pop(context);
            _openPage(const ProfilePage(), drawerItem: 'Configuraciones');
          },
        ),
        backgroundColor: const Color(0xFF111214),
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: pages),
      );
  }
}

class _PassengerAccessPendingShell extends StatelessWidget {
  const _PassengerAccessPendingShell({
    required this.deviceStatus,
  });

  final String deviceStatus;

  @override
  Widget build(BuildContext context) {
    final rejected = deviceStatus == 'RECHAZADO';
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF151517).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFF2A2A2E)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                    color: rejected ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    rejected ? 'Acceso bloqueado' : 'Acceso pendiente',
                    style: const TextStyle(
                      color: Color(0xFFFFF4EC),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    rejected
                        ? 'La central bloqueo este equipo. Cuando vuelva a autorizarlo, la app se habilitara sola.'
                        : 'La central aun no autoriza este equipo. En cuanto lo haga, la app se activara automaticamente.',
                    style: const TextStyle(
                      color: Color(0xFFFFD8BF),
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

class _LoginShell extends StatelessWidget {
  const _LoginShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
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
              top: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFC2410C).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const LoginCard(),
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
