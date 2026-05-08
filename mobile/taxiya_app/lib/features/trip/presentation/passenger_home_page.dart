import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../auth/presentation/passenger_profile_completion_page.dart';
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
  String _activeDrawerItem = 'Inicio';

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
        backgroundColor: const Color(0xFF111214),
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: pages),
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
