import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../auth/presentation/passenger_profile_completion_page.dart';
import '../../../core/config/app_brand.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../map/data/location_controller.dart';
import 'pages/profile_hub_page.dart';
import 'widgets/destination_search_sheet.dart';
import 'widgets/activity_tab.dart';
import 'widgets/ride_launcher_view.dart';
import 'widgets/ride_tab.dart';
import 'package:latlong2/latlong.dart';

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  static const _shellStateKey = 'rapigo_passenger_home_shell_v1';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _sessionRefreshTimer;
  DateTime? _lastBackPressAt;
  int _selectedIndex = 0;
  bool _showRideLauncher = true;
  RideMode _pendingRideMode = RideMode.destino;
  int _rideFlowVersion = 0;
  String? _pendingDestinationLabel;
  LatLng? _pendingDestinationPoint;
  bool _pendingStartInMapPicker = false;
  String? _lastShellSignature;

  @override
  void initState() {
    super.initState();
    _restoreShellState();
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
    final earnedFreeTrip = await ref
        .read(sessionProvider.notifier)
        .refreshSessionStatus();
    if (earnedFreeTrip) {
      await LocalNotifications.ensureInitialized();
      await LocalNotifications.show(
        id: 3001,
        title: 'Tienes un viaje gratis',
        body:
            'Completaste 5 viajes. Tu siguiente viaje sera gratis a donde sea.',
      );
    }
  }

  void _goHomeFromSection() {
    setState(() {
      _selectedIndex = 0;
    });
    unawaited(_persistShellState());
  }

  void _openRideFlow(RideMode mode) {
    setState(() {
      _showRideLauncher = false;
      _pendingRideMode = mode;
      _selectedIndex = 0;
      _rideFlowVersion++;
      _pendingDestinationLabel = null;
      _pendingDestinationPoint = null;
      _pendingStartInMapPicker = false;
    });
    unawaited(_persistShellState());
  }

  void _openRideFlowWithDestination({
    String? destinationLabel,
    LatLng? destinationPoint,
    bool startInMapPicker = false,
  }) {
    setState(() {
      _showRideLauncher = false;
      _pendingRideMode = RideMode.destino;
      _selectedIndex = 0;
      _rideFlowVersion++;
      _pendingDestinationLabel = destinationLabel;
      _pendingDestinationPoint = destinationPoint;
      _pendingStartInMapPicker = startInMapPicker;
    });
    unawaited(_persistShellState());
  }

  void _backToRideLauncher() {
    setState(() {
      _showRideLauncher = true;
      _selectedIndex = 0;
      _pendingDestinationLabel = null;
      _pendingDestinationPoint = null;
      _pendingStartInMapPicker = false;
    });
    unawaited(_persistShellState());
  }

  Future<void> _restoreShellState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shellStateKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 0;
      _showRideLauncher = true;
      _pendingRideMode = RideMode.destino;
      _pendingStartInMapPicker = false;
    });
  }

  Future<void> _persistShellState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = [
      _selectedIndex.toString(),
      _showRideLauncher ? '1' : '0',
      _pendingRideMode.name,
      _pendingStartInMapPicker ? '1' : '0',
    ].join('|');
    await prefs.setString(_shellStateKey, raw);
  }

  Future<void> _handleRootBack() async {
    if (!_showRideLauncher) {
      _backToRideLauncher();
      return;
    }

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
        _showRideLauncher = true;
      });
      return;
    }

    final now = DateTime.now();
    final pressedRecently =
        _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) <= const Duration(seconds: 2);

    if (pressedRecently) {
      await SystemNavigator.pop();
      return;
    }

    _lastBackPressAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Presiona atrás otra vez para salir'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openDestinationSearchSheet() async {
    final locationState = ref.read(passengerLocationProvider);
    final originLabel = locationState.position == null
        ? 'Potosí · ubicación actual'
        : 'Potosí · ubicación actual';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 1,
        child: DestinationSearchSheet(
          originLabel: originLabel,
          onClose: () => Navigator.of(context).pop(),
          onMapTap: () {
            Navigator.of(context).pop();
            _openRideFlowWithDestination(startInMapPicker: true);
          },
          onSuggestionTap: (label, point) {
            Navigator.of(context).pop();
            _openRideFlowWithDestination(
              destinationLabel: label,
              destinationPoint: point,
            );
          },
        ),
      ),
    );
  }

  void _openProfileHub() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileHubPage(
          onGoHome: _goHomeFromSection,
          onGoTrips: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
          onLogout: () => ref.read(sessionProvider.notifier).signOut(),
        ),
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

    if (session.deviceStatus != 'AUTORIZADO') {
      return _PassengerAccessPendingShell(deviceStatus: session.deviceStatus);
    }

    if (!session.profileCompleted) {
      return const PassengerProfileCompletionPage();
    }

    final showRideFlow = !_showRideLauncher;
    final shellSignature =
        '$_selectedIndex|${_showRideLauncher ? 1 : 0}|${_pendingRideMode.name}|${_pendingStartInMapPicker ? 1 : 0}|${showRideFlow ? 1 : 0}';
    if (_lastShellSignature != shellSignature) {
      _lastShellSignature = shellSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_persistShellState());
      });
    }

    final pages = [
      !showRideFlow
          ? RideLauncherView(
              onChooseMode: _openRideFlow,
              onOpenProfile: _openProfileHub,
              onOpenDestinationSearch: _openDestinationSearchSheet,
              onOpenTrips: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
            )
          : RideTab(
              key: ValueKey(
                'ride-flow-$_rideFlowVersion-${_pendingRideMode.name}',
              ),
              onMenuTap: _openProfileHub,
              initialMode: _pendingRideMode,
              openFlowOnStart: true,
              initialDestinationLabel: _pendingDestinationLabel,
              initialDestinationPoint: _pendingDestinationPoint,
              startInMapPicker: _pendingStartInMapPicker,
              onBackToLauncher: _backToRideLauncher,
            ),
      ActivityTab(onBack: _goHomeFromSection),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_handleRootBack());
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppBrand.surfaceSoft,
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: pages),
      ),
    );
  }
}

class _PassengerAccessPendingShell extends StatelessWidget {
  const _PassengerAccessPendingShell({required this.deviceStatus});

  final String deviceStatus;

  @override
  Widget build(BuildContext context) {
    final rejected = deviceStatus == 'RECHAZADO';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    rejected
                        ? Icons.block_rounded
                        : Icons.hourglass_top_rounded,
                    color: rejected ? AppBrand.danger : AppBrand.primaryBlue,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    rejected ? 'Acceso bloqueado' : 'Acceso pendiente',
                    style: const TextStyle(
                      color: AppBrand.textPrimary,
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
                      color: AppBrand.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
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
      backgroundColor: const Color(0xFFF5F5F7),
      body: Container(
        color: const Color(0xFFF5F5F7),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: AppBrand.primaryBlue.withValues(alpha: 0.10),
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
                  color: AppBrand.accentYellow.withValues(alpha: 0.18),
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
