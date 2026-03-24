import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
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
  int _selectedIndex = 0;
  String _activeDrawerItem = 'Configuraciones';

  void _handleDrawerSelection(String item) {
    switch (item) {
      case 'Tus viajes':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 1;
        });
        break;
      case 'Metodos de pago':
        _openPage(const PaymentMethodsPage(), drawerItem: item);
        break;
      case 'Promociones':
        _openPage(const PromotionsPage(), drawerItem: item);
        break;
      case 'Seguridad':
        _openPage(const SecurityPage(), drawerItem: item);
        break;
      case 'Centro de ayuda':
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.isAuthenticated) {
      return const _LoginShell();
    }

    final pages = [
      RideTab(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onProfileTap: () => _openPage(const ProfilePage(), drawerItem: 'Configuraciones'),
      ),
      const ActivityTab(),
      AccountTab(
        onOpenProfile: () => _openPage(const ProfilePage(), drawerItem: 'Configuraciones'),
        onOpenNotifications: () => _openPage(const NotificationsPage(), drawerItem: 'Configuraciones'),
        onOpenSecurity: () => _openPage(const SecurityPage(), drawerItem: 'Seguridad'),
        onOpenSettings: () => _openPage(const SettingsPage(), drawerItem: 'Configuraciones'),
        onOpenSupport: () => _openPage(const SupportPage(), drawerItem: 'Centro de ayuda'),
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        fullName: session.fullName,
        phone: session.phone,
        onLogout: () => ref.read(sessionProvider.notifier).signOut(),
        activeItem: _activeDrawerItem,
        onSelect: _handleDrawerSelection,
        onOpenProfile: () {
          Navigator.pop(context);
          _openPage(const ProfilePage(), drawerItem: 'Configuraciones');
        },
      ),
      backgroundColor: const Color(0xFFF9F9FB),
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000003),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          height: 74,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0x1A00E3FD),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (value) => setState(() {
            _selectedIndex = value;
            _activeDrawerItem = switch (value) {
              0 => 'Promociones',
              1 => 'Tus viajes',
              _ => 'Configuraciones',
            };
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Viaje'),
            NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historial'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
          ],
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
      backgroundColor: const Color(0xFFF9F9FB),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F9FB), Color(0xFFEAFBFD)],
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
                  color: const Color(0xFF00E3FD).withValues(alpha: 0.12),
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
                  color: const Color(0xFF006875).withValues(alpha: 0.10),
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
