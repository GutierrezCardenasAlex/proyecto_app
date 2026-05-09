import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/driver_session.dart';
import '../../auth/presentation/driver_login_card.dart';
import '../../auth/presentation/driver_profile_completion_page.dart';
import '../../map/presentation/driver_map.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/driver_trip.dart';
import '../../../core/config/app_config.dart';
import '../../../../core/config/app_config.dart' as shared_config;
import '../../../core/notifications/local_notifications.dart';
import '../../../../core/map/offline_map.dart';
import '../../../../core/ui/top_notice.dart';
import 'pages/driver_detail_pages.dart';
import 'widgets/driver_app_drawer.dart';
import 'widgets/driver_ui_kit.dart';
import '../data/driver_repository.dart';
import '../domain/driver_state.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> with WidgetsBindingObserver {
  static const _inactivityDuration = Duration(minutes: 5);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _inactivityTimer;
  DateTime _lastInteractionAt = DateTime.now();
  io.Socket? _socket;
  String? _joinedDriverId;
  String? _joinedTripId;
  String? _restoredDriverId;
  int _selectedIndex = 0;
  String _activeDrawerItem = 'Panel de viaje';
  bool _openOffersFromDrawer = false;
  bool _bootstrappedExperience = false;
  bool _isPreparingExperience = false;
  bool _offlineSheetQueued = false;
  bool _isRefreshingAuthorization = false;
  Timer? _sessionRefreshTimer;

  void _handleDrawerSelection(String item) {
    switch (item) {
      case 'Panel de viaje':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 0;
        });
        break;
      case 'Historial':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 1;
        });
        break;
      case 'Viajes disponibles':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 0;
          _openOffersFromDrawer = true;
        });
        break;
      case 'Cuenta':
        setState(() {
          _activeDrawerItem = item;
          _selectedIndex = 2;
        });
        break;
      case 'Ganancias':
        _openPage(const DriverEarningsPage(), drawerItem: item);
        break;
      case 'Seguridad':
        _openPage(const DriverSecurityPage(), drawerItem: item);
        break;
      case 'Centro de ayuda':
        _openPage(const DriverHelpPage(), drawerItem: item);
        break;
      case 'Configuraciones':
        _openPage(const DriverSettingsPage(), drawerItem: item);
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

  void _goToDriverDashboard() {
    setState(() {
      _activeDrawerItem = 'Panel de viaje';
      _selectedIndex = 0;
    });
  }

  void _ensureSocket(String driverId) {
    if (_socket != null && _joinedDriverId == driverId) {
      return;
    }

    _socket?.dispose();
    _socket = io.io(
      AppConfig.websocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    _socket?.onConnect((_) {
      _socket?.emit('join:driver', driverId);
      _joinedDriverId = driverId;
      final tripId = ref.read(offeredTripProvider).value?.id;
      if (tripId != null && tripId.isNotEmpty) {
        _joinTripRoom(tripId);
      }
    });
    _socket?.on('driver:trip_offer', (_) {
      ref.read(offeredTripProvider.notifier).loadOffer();
      ref.read(driverOffersProvider.notifier).loadOffers();
      LocalNotifications.show(
        id: 2001,
        title: 'Nueva oferta',
        body: 'Tienes una solicitud de viaje disponible.',
      );
      if (mounted) {
        showTopNotice(
          context,
          'Nueva oferta disponible. Revisa el viaje entrante.',
          backgroundColor: const Color(0xFFF97316),
          foregroundColor: const Color(0xFF0F0F10),
        );
      }
    });
    _socket?.on('trip:status_changed', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      final status = map['status']?.toString();
      final currentTripId = ref.read(offeredTripProvider).value?.id;
      if (tripId != null &&
          status != null &&
          tripId.isNotEmpty &&
          status.isNotEmpty &&
          currentTripId == tripId) {
        ref.read(offeredTripProvider.notifier).setLocalStatus(status);
        LocalNotifications.show(
          id: 2002,
          title: 'Estado del viaje',
          body: _statusMessage(status),
        );
        if (mounted) {
          showTopNotice(
            context,
            _statusMessage(status),
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: const Color(0xFF0F0F10),
          );
        }
      }
    });
    _socket?.on('driver:trip_rejected', (_) {
      ref.read(driverOffersProvider.notifier).loadOffers();
    });
    _socket?.on('driver:trip_accepted', (_) {
      ref.read(driverOffersProvider.notifier).loadOffers();
      ref.read(offeredTripProvider.notifier).loadOffer();
    });
    _socket?.connect();
  }

  void _joinTripRoom(String tripId) {
    if (_joinedTripId == tripId) {
      return;
    }
    if (_joinedTripId != null && _joinedTripId!.isNotEmpty) {
      _socket?.emit('leave:trip', _joinedTripId);
    }
    _socket?.emit('join:trip', tripId);
    _joinedTripId = tripId;
  }

  String _statusMessage(String status) {
    return switch (status) {
      'arriving' => 'Dirigete al punto de recogida.',
      'at_pickup' => 'Marcaste llegada al punto.',
      'in_progress' => 'Viaje en progreso.',
      'completed' => 'Viaje finalizado.',
      'cancelled' => 'Viaje cancelado.',
      _ => 'Estado actualizado: $status',
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socket?.dispose();
    _inactivityTimer?.cancel();
    _sessionRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);

    if (session.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!session.loggedIn) {
      return const _DriverLoginShell();
    }

    if (session.deviceStatus != 'AUTORIZADO') {
      return _DriverDeviceAccessPendingShell(deviceStatus: session.deviceStatus);
    }

    if (!session.profileCompleted) {
      return const DriverProfileCompletionPage();
    }

    if (!_bootstrappedExperience) {
      _bootstrappedExperience = true;
      Future<void>.microtask(_prepareDriverExperience);
    }

    if (session.accessStatus != 'AUTORIZADO') {
      Future<void>.microtask(_refreshAuthorizationStatus);
    }

    if (session.accessStatus == 'AUTORIZADO' &&
        _restoredDriverId != session.driverId &&
        session.driverId.isNotEmpty) {
      _restoredDriverId = session.driverId;
      Future<void>.microtask(_restoreDriverOperationalState);
    }

    if (session.accessStatus != 'AUTORIZADO') {
      return _DriverAuthorizationPendingShell(
        accessStatus: session.accessStatus,
      );
    }

    if (session.accessStatus == 'AUTORIZADO' && session.driverId.isNotEmpty) {
      _ensureSocket(session.driverId);
    }

    final currentTrip = ref.watch(offeredTripProvider).value;
    if (currentTrip != null &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(currentTrip.status)) {
      _joinTripRoom(currentTrip.id);
    }

    final pages = [
      _DriverDashboard(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        openOffersFromDrawer: _openOffersFromDrawer,
        onOffersDrawerHandled: () {
          if (mounted && _openOffersFromDrawer) {
            setState(() => _openOffersFromDrawer = false);
          }
        },
      ),
      _DriverTripsTab(
        onBack: _goToDriverDashboard,
      ),
      _DriverAccountTab(
        fullName: session.fullName,
        phone: session.phone,
        onBack: _goToDriverDashboard,
        onOpenProfile: () => _openPage(const DriverProfilePage(), drawerItem: 'Configuraciones'),
        onOpenSecurity: () => _openPage(const DriverSecurityPage(), drawerItem: 'Seguridad'),
        onOpenSettings: () => _openPage(const DriverSettingsPage(), drawerItem: 'Configuraciones'),
        onOpenHelp: () => _openPage(const DriverHelpPage(), drawerItem: 'Centro de ayuda'),
      ),
    ];

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markInteraction(),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: DriverAppDrawer(
          fullName: session.fullName,
          phone: session.phone,
          activeItem: _activeDrawerItem,
          onSelect: _handleDrawerSelection,
          onLogout: () => ref.read(driverSessionProvider.notifier).logout(),
          onOpenProfile: () {
            Navigator.pop(context);
            _openPage(const DriverProfilePage(), drawerItem: 'Configuraciones');
          },
        ),
        backgroundColor: const Color(0xFF111214),
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armInactivityTimer();
    _sessionRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => Future<void>.microtask(_refreshDriverAccessState),
    );
  }

  Future<void> _prepareDriverExperience() async {
    if (_isPreparingExperience) {
      return;
    }
    _isPreparingExperience = true;
    try {
      await _ensureCriticalPermissions();
      await LocalNotifications.ensureInitialized();

      if (!mounted) {
        return;
      }

      final offlineController = ref.read(offlineMapProvider.notifier);
      await offlineController.refreshStatus();
      final offlineState = ref.read(offlineMapProvider);
      if (shared_config.AppConfig.hasDedicatedOfflineTileSource &&
          !offlineState.isReady &&
          !offlineState.isDownloading &&
          !_offlineSheetQueued) {
        _offlineSheetQueued = true;
        Future<void>.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) {
            return;
          }
          await showOfflineMapSheet(context);
        });
      }
    } catch (_) {
      // Keep startup stable if permissions/network are temporarily unavailable.
    } finally {
      _isPreparingExperience = false;
    }
  }

  Future<void> _ensureCriticalPermissions() async {
    while (mounted) {
      final notificationStatus = await Permission.notification.request();
      final locationStatus = await Permission.locationWhenInUse.request();
      final notificationsReady = notificationStatus.isGranted || notificationStatus.isLimited;
      final locationReady = locationStatus.isGranted || locationStatus.isLimited;
      if (notificationsReady && locationReady) {
        return;
      }
      await _showPermissionsRequiredDialog(
        notificationsReady: notificationsReady,
        locationReady: locationReady,
      );
    }
  }

  Future<void> _showPermissionsRequiredDialog({
    required bool notificationsReady,
    required bool locationReady,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF17181B),
          title: const Text(
            'Activa los permisos',
            style: TextStyle(color: Color(0xFFFFF4EC), fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Flash Go necesita ubicacion y notificaciones activas para trabajar correctamente desde el inicio.',
                style: TextStyle(color: Color(0xFFFFD8BF)),
              ),
              const SizedBox(height: 12),
              Text(
                '${locationReady ? '✓' : '•'} Ubicacion activa',
                style: TextStyle(
                  color: locationReady ? const Color(0xFF86EFAC) : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${notificationsReady ? '✓' : '•'} Notificaciones activas',
                style: TextStyle(
                  color: notificationsReady ? const Color(0xFF86EFAC) : const Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Configuracion'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: const Color(0xFF0F0F10),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      },
    );
  }

  void _armInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, _handleInactivityTimeout);
  }

  void _markInteraction() {
    _lastInteractionAt = DateTime.now();
    _armInactivityTimer();
  }

  Future<void> _handleInactivityTimeout() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn) {
      return;
    }
    final driverState = ref.read(driverStateProvider);
    if (driverState.available) {
      await ref.read(driverStateProvider.notifier).toggleAvailability(false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastInteractionAt) >= _inactivityDuration) {
        Future<void>.microtask(_handleInactivityTimeout);
        return;
      }
      _markInteraction();
      Future<void>.microtask(_restoreDriverOperationalState);
    }
  }

  Future<void> _restoreDriverOperationalState() async {
    if (!mounted) {
      return;
    }
    try {
      await ref.read(driverStateProvider.notifier).restoreOperationalState();
      await ref.read(offeredTripProvider.notifier).loadOffer();
      await ref.read(driverOffersProvider.notifier).loadOffers();
    } catch (_) {
      // Avoid surfacing lifecycle restoration failures as app-breaking errors.
    }
  }

  Future<void> _refreshAuthorizationStatus() async {
    if (_isRefreshingAuthorization) {
      return;
    }
    _isRefreshingAuthorization = true;
    try {
      await ref.read(driverSessionProvider.notifier).refreshAccessStatus();
      final updatedSession = ref.read(driverSessionProvider);
      if (updatedSession.accessStatus != 'AUTORIZADO') {
        final driverState = ref.read(driverStateProvider);
        if (driverState.available) {
          await ref.read(driverStateProvider.notifier).toggleAvailability(false);
        }
      }
    } finally {
      _isRefreshingAuthorization = false;
    }
  }

  Future<void> _refreshDriverAccessState() async {
    await ref.read(driverSessionProvider.notifier).refreshSessionStatus();
    final updatedSession = ref.read(driverSessionProvider);
    if (updatedSession.deviceStatus != 'AUTORIZADO') {
      final driverState = ref.read(driverStateProvider);
      if (driverState.available) {
        await ref.read(driverStateProvider.notifier).toggleAvailability(false);
      }
      return;
    }
    await _refreshAuthorizationStatus();
  }
}

class _DriverAuthorizationPendingShell extends StatelessWidget {
  const _DriverAuthorizationPendingShell({
    required this.accessStatus,
  });

  final String accessStatus;

  @override
  Widget build(BuildContext context) {
    final rejected = accessStatus == 'RECHAZADO';
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFF2A2A2E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (rejected ? const Color(0xFF7F1D1D) : const Color(0xFF3A2310)),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        rejected ? Icons.block_rounded : Icons.verified_user_outlined,
                        color: rejected ? const Color(0xFFFCA5A5) : const Color(0xFFF97316),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      rejected ? 'Permisos insuficientes' : 'Falta autorizacion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rejected
                          ? 'La central todavia no habilito este registro de conductor. Deben revisar tus datos y volver a autorizar el uso.'
                          : 'Tu cuenta de conductor ya se registro correctamente, pero la central todavia debe autorizarla para que puedas operar.',
                      style: const TextStyle(
                        color: Color(0xFFFFC89B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1D20),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mientras esperas',
                            style: TextStyle(
                              color: Color(0xFFFFF4EC),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'La app ya puede dejar listos permisos y mapa offline de Potosi. Cuando la central te autorice, solo vuelves a entrar y podras usar el panel de conductor.',
                            style: TextStyle(
                              color: Color(0xFFFFD8BF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverDeviceAccessPendingShell extends StatelessWidget {
  const _DriverDeviceAccessPendingShell({
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF151517).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFF2A2A2E)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      rejected ? Icons.block_rounded : Icons.phone_android_rounded,
                      color: rejected ? const Color(0xFFEF4444) : const Color(0xFFF97316),
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rejected ? 'Equipo bloqueado' : 'Equipo pendiente',
                      style: const TextStyle(
                        color: Color(0xFFFFF4EC),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rejected
                          ? 'La central bloqueo este dispositivo. Si lo vuelven a autorizar, la app del conductor se habilitara sola.'
                          : 'La central aun no autoriza este dispositivo. Apenas lo hagan, la app del conductor seguira sola.',
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
      ),
    );
  }
}

class _DriverLoginShell extends StatelessWidget {
  const _DriverLoginShell();

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
                    child: const DriverLoginCard(),
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

class _DriverDashboard extends ConsumerStatefulWidget {
  const _DriverDashboard({
    required this.onMenuTap,
    required this.openOffersFromDrawer,
    required this.onOffersDrawerHandled,
  });

  final VoidCallback onMenuTap;
  final bool openOffersFromDrawer;
  final VoidCallback onOffersDrawerHandled;

  @override
  ConsumerState<_DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<_DriverDashboard> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetSize = 0.36;
  DateTime? _lastOfferRefreshAt;
  bool _isRefreshingOffer = false;
  int _mapFocusSignal = 0;

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _toggleSheet() async {
    final target = _sheetSize <= 0.08 ? 0.36 : 0.0;
    await _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _maybeRefreshOffer(DriverSession session, DriverState driverState, AsyncValue<DriverTrip?> tripAsync) async {
    if (!session.loggedIn || !driverState.available || tripAsync.isLoading || _isRefreshingOffer) {
      return;
    }
    final now = DateTime.now();
    if (_lastOfferRefreshAt != null && now.difference(_lastOfferRefreshAt!) < const Duration(seconds: 8)) {
      return;
    }
    _isRefreshingOffer = true;
    _lastOfferRefreshAt = now;
    try {
      await Future.wait([
        ref.read(offeredTripProvider.notifier).loadOffer(),
        ref.read(driverOffersProvider.notifier).loadOffers(),
      ]);
    } catch (_) {
      // Ignore transient polling failures to keep dashboard smooth.
    } finally {
      _isRefreshingOffer = false;
    }
  }

  LatLngBounds? _buildDriverFocusBounds({
    required double driverLat,
    required double driverLng,
    DriverTrip? trip,
  }) {
    if (trip == null) {
      return null;
    }
    final driverPoint = LatLng(driverLat, driverLng);
    if (trip.status == 'in_progress') {
      return LatLngBounds.fromPoints([
        driverPoint,
        LatLng(trip.destinationLat, trip.destinationLng),
      ]);
    }
    if (const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status)) {
      return LatLngBounds.fromPoints([
        driverPoint,
        LatLng(trip.pickupLat, trip.pickupLng),
      ]);
    }
    return null;
  }

  void _showStatusSheet(BuildContext context, DriverState driverState, DriverTrip? trip) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x66F97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Estado del conductor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(
                      label: 'Disponibilidad',
                      value: driverState.available ? 'Buscando viaje' : 'Fuera de linea',
                    ),
                    _InfoTile(
                      label: 'Operacion',
                      value: _statusChipLabel(driverState, trip),
                    ),
                    _InfoTile(
                      label: 'Ultimo GPS',
                      value: driverState.lastLocationPing == null
                          ? 'Sin ubicacion enviada aun'
                          : driverState.lastLocationPing.toString(),
                    ),
                    if (trip != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1D),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: _driverStatusAccentColor(trip.status).withValues(alpha: 0.30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _driverStatusAccentColor(trip.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _statusChipLabel(driverState, trip),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFFFF4EC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (trip.passengerName?.trim().isNotEmpty ?? false)
                              Text(
                                trip.passengerName!.trim(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFF4EC),
                                ),
                              ),
                            if (trip.passengerPhone?.trim().isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                trip.passengerPhone!.trim(),
                                style: const TextStyle(
                                  color: Color(0xFFFFC89B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _DriverCompactInfoRow(
                              icon: Icons.radio_button_checked_rounded,
                              label: 'Recojo',
                              value: trip.passengerPickup,
                              iconColor: const Color(0xFFF97316),
                            ),
                            const SizedBox(height: 8),
                            _DriverCompactInfoRow(
                              icon: Icons.location_on_rounded,
                              label: 'Destino',
                              value: trip.destination,
                              iconColor: const Color(0xFF22C55E),
                            ),
                            const SizedBox(height: 8),
                            _DriverCompactInfoRow(
                              icon: _tripVehicleIcon(trip),
                              label: 'Vehiculo',
                              value: (trip.vehicleType ?? 'taxi').toUpperCase(),
                              iconColor: const Color(0xFF38BDF8),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showIncomingTripDetail(trip),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFFD8BF),
                                    side: BorderSide(
                                      color: _driverStatusAccentColor(trip.status).withValues(alpha: 0.32),
                                    ),
                                  ),
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: const Text('Detalle'),
                                ),
                                if ((trip.passengerPhone?.trim().isNotEmpty ?? false) && _canManageTrip(trip))
                                  FilledButton.tonalIcon(
                                    onPressed: () => _openPassengerWhatsAppFromDashboard(trip),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF1F3A2A),
                                      foregroundColor: const Color(0xFFB6F5C8),
                                    ),
                                    icon: const Icon(Icons.chat_bubble_rounded),
                                    label: Text(trip.status == 'at_pickup' ? 'Avisar llegada' : 'WhatsApp'),
                                  ),
                                if (_canCancelDriverTrip(trip))
                                  FilledButton.tonalIcon(
                                    onPressed: () => _cancelDriverTripFromDashboard(trip),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF3A1F1F),
                                      foregroundColor: const Color(0xFFFFC9C9),
                                    ),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Cancelar'),
                                  ),
                              ],
                            ),
                            if (_canManageTrip(trip)) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => _handleDriverPrimaryAction(trip),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: const Color(0xFF0F0F10),
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    _driverActionLabel(trip),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: driverState.available,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) async {
                        Navigator.of(context).pop();
                        await ref.read(driverStateProvider.notifier).toggleAvailability(value);
                      },
                      title: const Text(
                        'Activar disponibilidad',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFF4EC),
                        ),
                      ),
                      subtitle: const Text(
                        'Mantiene tu estado de busqueda y vuelve a enviar GPS.',
                        style: TextStyle(color: Color(0xFFFFC89B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _tripDescription(DriverTrip? trip) {
    if (trip == null) {
      return 'No hay ofertas en este momento. Activa disponibilidad y mantente cerca de la demanda.';
    }

    return switch (trip.status) {
      'accepted' => 'Ya aceptaste este viaje. Ahora ve hacia el punto de recogida.',
      'arriving' => 'Estas en camino al punto de recogida.',
      'at_pickup' => 'Ya llegaste. Espera a que el pasajero suba o inicia el trayecto.',
      'in_progress' => 'Viaje en progreso hacia el destino.',
      'completed' => 'Viaje finalizado. Espera una nueva solicitud cuando vuelvas a estar disponible.',
      _ => 'Revisa la solicitud y decide si quieres aceptarla.',
    };
  }

  String _driverActionLabel(DriverTrip? trip) {
    if (trip == null) {
      return 'Aceptar viaje';
    }

    return switch (trip.status) {
      'searching' => 'Aceptar viaje',
      'accepted' => 'Ir a recoger',
      'arriving' => 'Llegue a la ubicacion',
      'at_pickup' => 'Iniciar viaje',
      'in_progress' => 'Finalizar viaje',
      'completed' => 'Viaje finalizado',
      _ => 'Aceptar viaje',
    };
  }

  bool _canManageTrip(DriverTrip? trip) {
    return trip != null && !const {'completed', 'cancelled'}.contains(trip.status);
  }

  bool _canCancelDriverTrip(DriverTrip? trip) {
    return trip != null && const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status);
  }

  String? _normalizeWhatsAppPhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('591')) {
      return digits;
    }
    return '591$digits';
  }

  Future<void> _openPassengerWhatsAppFromDashboard(DriverTrip trip) async {
    final normalizedPhone = _normalizeWhatsAppPhone(trip.passengerPhone);
    if (normalizedPhone == null) {
      if (mounted) {
        showTopNotice(
          context,
          'Todavia no hay numero del pasajero para WhatsApp.',
          backgroundColor: const Color(0xFFF97316),
          foregroundColor: const Color(0xFF0F0F10),
        );
      }
      return;
    }

    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'pasajero';
    final message = trip.status == 'at_pickup'
        ? 'Hola $passengerName, ya llegue al punto de recojo en Flash Go.'
        : 'Hola $passengerName, te escribo por tu viaje de Flash Go.';
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showTopNotice(
        context,
        'No se pudo abrir WhatsApp en este momento.',
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: const Color(0xFF0F0F10),
      );
    }
  }

  Future<void> _cancelDriverTripFromDashboard(DriverTrip trip) async {
    await ref.read(offeredTripProvider.notifier).updateTripStatus('cancelled');
    if (mounted) {
      final error = ref.read(offeredTripProvider).error;
      showTopNotice(
        context,
        error == null ? 'Viaje cancelado.' : error.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: const Color(0xFF0F0F10),
      );
    }
  }

  String _statusChipLabel(DriverState driverState, DriverTrip? trip) {
    if (trip != null) {
      return switch (trip.status) {
        'accepted' => 'Viaje aceptado',
        'arriving' => 'En camino al recojo',
        'at_pickup' => 'Esperando al pasajero',
        'in_progress' => 'Viaje en progreso',
        'completed' => 'Listo para nueva solicitud',
        _ => 'Nueva oferta recibida',
      };
    }
    return driverState.available ? 'Buscando viaje' : 'Desconectado';
  }

  String _driverStatusShortLabel(String status) {
    return switch (status) {
      'requested' => 'Solicitud',
      'searching' => 'Pendiente',
      'accepted' => 'Aceptado',
      'arriving' => 'En camino',
      'at_pickup' => 'Llego',
      'in_progress' => 'En curso',
      'completed' => 'Finalizado',
      _ => 'Activo',
    };
  }

  bool _hasPendingOffer(DriverTrip? trip) {
    return trip != null && const {'requested', 'searching'}.contains(trip.status);
  }

  bool _hasLiveTripStatus(DriverTrip? trip) {
    return trip != null && const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(trip.status);
  }

  IconData _driverPrimaryActionIcon(DriverTrip? trip) {
    return switch (trip?.status) {
      'accepted' => Icons.route_rounded,
      'arriving' => Icons.place_rounded,
      'at_pickup' => Icons.play_arrow_rounded,
      'in_progress' => Icons.flag_rounded,
      _ => Icons.flash_on_rounded,
    };
  }

  Color _driverStatusAccentColor(String status) {
    return switch (status) {
      'requested' || 'searching' || 'accepted' || 'arriving' => const Color(0xFFF97316),
      'at_pickup' => const Color(0xFF22C55E),
      'in_progress' => const Color(0xFF0EA5E9),
      'completed' => const Color(0xFF9CA3AF),
      _ => const Color(0xFFF97316),
    };
  }

  IconData _tripVehicleIcon(DriverTrip? trip) {
    return switch ((trip?.vehicleType ?? '').toLowerCase()) {
      'moto' => Icons.two_wheeler_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }

  void _showAvailableTripsSheet({
    required AsyncValue<DriverTrip?> tripAsync,
    required DriverTrip? trip,
    required AsyncValue<List<DriverTrip>> offersAsync,
  }) {
    final offers = offersAsync.value ?? const <DriverTrip>[];
    final pendingOffers = offers.where((item) => _hasPendingOffer(item)).toList(growable: false);
    final accent = pendingOffers.isEmpty
        ? const Color(0xFFF97316)
        : _driverStatusAccentColor(pendingOffers.first.status);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111214),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFF4EC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.22),
                            const Color(0xFF1A1A1D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: accent.withValues(alpha: 0.32)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111214),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.local_taxi_rounded,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Viajes disponibles',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF4EC),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pendingOffers.isEmpty
                                      ? 'Revisa nuevas solicitudes apenas entren.'
                                      : 'Tienes ${pendingOffers.length} solicitudes listas para revisar y decidir.',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD8BF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111214),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: accent.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              '${pendingOffers.length}',
                              style: const TextStyle(
                                color: Color(0xFFF97316),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: offersAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => DriverEmptyCard(
                          title: 'No pudimos cargar ofertas',
                          subtitle: error.toString().replaceFirst('Exception: ', ''),
                        ),
                        data: (_) {
                          if (pendingOffers.isEmpty) {
                            if (_hasLiveTripStatus(trip)) {
                              return const DriverEmptyCard(
                                title: 'Ya tienes un viaje en curso',
                                subtitle: 'Termina o actualiza ese viaje para recibir una nueva solicitud.',
                              );
                            }
                            return const DriverEmptyCard(
                              title: 'No hay viajes disponibles',
                              subtitle: 'En cuanto entre una nueva solicitud, la veras aqui.',
                            );
                          }

                          return ListView.separated(
                            itemCount: pendingOffers.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final pendingOffer = pendingOffers[index];
                              return _DriverAvailableTripCard(
                                trip: pendingOffer,
                                accentColor: _driverStatusAccentColor(pendingOffer.status),
                                onViewDetails: () {
                                  Navigator.of(context).pop();
                                  _showIncomingTripDetail(pendingOffer);
                                },
                                onAccept: () async {
                                  Navigator.of(context).pop();
                                  await _handleDriverPrimaryAction(pendingOffer);
                                },
                                onReject: () async {
                                  await ref.read(driverOffersProvider.notifier).rejectOffer(pendingOffer.id);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showIncomingTripDetail(DriverTrip trip) {
    final accent = _driverStatusAccentColor(trip.status);
    final passengerName =
        trip.passengerName?.trim().isNotEmpty == true ? trip.passengerName!.trim() : 'Pasajero';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF111214),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x33FFF4EC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.26),
                            const Color(0xFF1A1A1D),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: accent.withValues(alpha: 0.36)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111214),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(_tripVehicleIcon(trip), color: accent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Detalle del viaje',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFFFF4EC),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(trip.vehicleType ?? 'taxi').toUpperCase()} para $passengerName',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD8BF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (trip.isPromotional) ...[
                                      const SizedBox(height: 10),
                                      const _DriverPromoChip(label: 'PASAJERO CON VIAJE GRATIS'),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _DriverMiniBadge(icon: Icons.flag_rounded, label: _driverStatusShortLabel(trip.status)),
                              if (trip.isPromotional)
                                const _DriverMiniBadge(
                                  icon: Icons.card_giftcard_rounded,
                                  label: 'PROMO GRATIS',
                                ),
                              _DriverMiniBadge(icon: Icons.tag_rounded, label: trip.id),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1D),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x26F97316)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoTile(label: 'Pasajero', value: passengerName),
                          if (trip.passengerPhone?.trim().isNotEmpty ?? false)
                            _InfoTile(label: 'Telefono', value: trip.passengerPhone!.trim()),
                          _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                          _InfoTile(label: 'Destino', value: trip.destination),
                          _InfoTile(
                            label: 'Vehiculo pedido',
                            value: (trip.vehicleType ?? 'taxi').toUpperCase(),
                          ),
                          if (trip.isPromotional)
                            const _InfoTile(
                              label: 'Promocion',
                              value: 'Este pasajero esta usando un viaje gratis promocional',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await ref.read(driverOffersProvider.notifier).rejectOffer(trip.id);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFC9C9),
                              side: const BorderSide(color: Color(0x44EF4444)),
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _handleDriverPrimaryAction(trip);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316),
                              foregroundColor: const Color(0xFF0F0F10),
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Aceptar viaje',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDriverPrimaryAction(DriverTrip? trip) async {
    if (trip == null) {
      return;
    }

    if (trip.status == 'requested' || trip.status == 'searching') {
      await ref.read(offeredTripProvider.notifier).acceptTrip(trip);
      ref.read(driverOffersProvider.notifier).removeOfferLocally(trip.id);
      if (trip.isPromotional && mounted) {
        showTopNotice(
          context,
          'El pasajero gano y esta usando su viaje gratis.',
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: const Color(0xFF0F0F10),
        );
      }
      return;
    }
    if (trip.status == 'accepted') {
      await ref.read(offeredTripProvider.notifier).updateTripStatus('arriving');
      return;
    }
    if (trip.status == 'arriving') {
      await ref.read(offeredTripProvider.notifier).updateTripStatus('at_pickup');
      return;
    }
    if (trip.status == 'at_pickup') {
      await ref.read(offeredTripProvider.notifier).updateTripStatus('in_progress');
      return;
    }
    if (trip.status == 'in_progress') {
      await ref.read(offeredTripProvider.notifier).updateTripStatus('completed');
      await ref.read(driverOffersProvider.notifier).loadOffers();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverStateProvider);
    final tripAsync = ref.watch(offeredTripProvider);
    final offersAsync = ref.watch(driverOffersProvider);
    final offers = offersAsync.value ?? const <DriverTrip>[];
    final availableOffersCount = offers.where((item) => _hasPendingOffer(item)).length;
    final trip = tripAsync.value;
    final routeColor = trip?.status == 'in_progress'
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFF97316);
    final focusBounds = _buildDriverFocusBounds(
      driverLat: driverState.lat,
      driverLng: driverState.lng,
      trip: trip,
    );
    final session = ref.watch(driverSessionProvider);
    if (widget.openOffersFromDrawer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onOffersDrawerHandled();
        _showAvailableTripsSheet(tripAsync: tripAsync, trip: trip, offersAsync: offersAsync);
      });
    }

    if (session.loggedIn && driverState.available && trip == null) {
      Future<void>.microtask(() => _maybeRefreshOffer(session, driverState, tripAsync));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DriverMap(
              available: driverState.available,
              tripAccepted: const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(trip?.status),
              driverLat: driverState.lat,
              driverLng: driverState.lng,
              vehicleType: (trip?.vehicleType?.isNotEmpty ?? false)
                  ? trip!.vehicleType!
                  : session.vehicleType,
              tripStatus: trip?.status,
              pickupLat: trip?.pickupLat,
              pickupLng: trip?.pickupLng,
              destinationLat: trip?.destinationLat,
              destinationLng: trip?.destinationLng,
              routeColor: routeColor,
              focusBounds: focusBounds,
              focusSignal: _mapFocusSignal,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F0F10).withValues(alpha: 0.78),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF161618),
                  ],
                  stops: const [0, 0.18, 0.72, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassIconButton(icon: Icons.menu, onTap: widget.onMenuTap),
                    const Spacer(),
                    _GlassIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () async {
                        await ref.read(driverStateProvider.notifier).restoreOperationalState();
                        await ref.read(offeredTripProvider.notifier).loadOffer();
                        await ref.read(driverOffersProvider.notifier).loadOffers();
                        if (mounted) {
                          setState(() => _mapFocusSignal++);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _GlassIconButton(
                      icon: driverState.available ? Icons.radio_button_checked_rounded : Icons.do_not_disturb_on_rounded,
                      iconColor: driverState.available ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      onTap: () => _showStatusSheet(context, driverState, trip),
                    ),
                    const SizedBox(width: 10),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _GlassIconButton(
                          icon: availableOffersCount > 0 ? Icons.notifications_active_rounded : Icons.assignment_rounded,
                          onTap: () => _showAvailableTripsSheet(
                            tripAsync: tripAsync,
                            trip: trip,
                            offersAsync: offersAsync,
                          ),
                        ),
                        if (availableOffersCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFF111214), width: 2),
                              ),
                              child: Text(
                                availableOffersCount > 9 ? '9+' : '$availableOffersCount',
                                style: const TextStyle(
                                  color: Color(0xFFFFF4EC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        if (_hasLiveTripStatus(trip))
          Positioned(
            left: 20,
            right: 84,
            bottom: 140,
            child: SafeArea(
              top: false,
              child: Material(
                color: const Color(0xFF17181B).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: tripAsync.isLoading ? null : () => _handleDriverPrimaryAction(trip),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _driverStatusAccentColor(trip!.status).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _driverPrimaryActionIcon(trip),
                            color: _driverStatusAccentColor(trip.status),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _statusChipLabel(driverState, trip),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFF4EC),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _driverActionLabel(trip),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFC89B),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: tripAsync.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation(Color(0xFF0F0F10)),
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF0F0F10),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 20,
          bottom: 140,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
            ],
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            setState(() => _sheetSize = notification.extent);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.36,
            minChildSize: 0.0,
            maxChildSize: 0.82,
            snap: true,
            snapSizes: const [0.0, 0.22, 0.36, 0.60, 0.82],
            builder: (context, scrollController) {
              return DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x16000003),
                    blurRadius: 40,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
                  children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0x66F97316),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sesion',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                session.phone,
                                style: const TextStyle(
                                  color: Color(0xFFFFD8BF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _statusChipLabel(driverState, trip),
                                style: const TextStyle(
                                  color: Color(0xFFFFD8BF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SwitchListTile(
                    value: driverState.available,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    onChanged: (value) => ref.read(driverStateProvider.notifier).toggleAvailability(value),
                    title: const Text(
                      'Activar disponibilidad',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Envia tu GPS cada 5 segundos y permite recibir viajes.'),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _showStatusSheet(context, driverState, trip),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Ver estados'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: const Color(0xFF0F0F10),
                        ),
                      ),
                    ],
                  ),
                  if (driverState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B1313),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        driverState.errorMessage!.replaceFirst('Exception: ', ''),
                        style: const TextStyle(
                          color: Color(0xFF93000A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Viajes entrantes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    availableOffersCount > 0
                        ? 'Tienes $availableOffersCount viajes disponibles para revisar.'
                        : _tripDescription(trip),
                    style: const TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (offersAsync.isLoading && offers.isEmpty && trip == null)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  else if (availableOffersCount == 0 && trip == null)
                    const DriverEmptyCard(
                      title: 'Sin ofertas activas',
                      subtitle: 'Cuando un pasajero solicite un taxi cercano, aparecera aqui.',
                    )
                  else if (availableOffersCount > 0)
                    Column(
                      children: offers
                          .where((item) => _hasPendingOffer(item))
                          .map(
                            (offer) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DriverAvailableTripCard(
                                trip: offer,
                                accentColor: _driverStatusAccentColor(offer.status),
                                onViewDetails: () => _showIncomingTripDetail(offer),
                                onAccept: () async => _handleDriverPrimaryAction(offer),
                                onReject: () async => ref.read(driverOffersProvider.notifier).rejectOffer(offer.id),
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    Builder(
                      builder: (context) {
                        final activeTrip = trip!;
                        return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x33F97316)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25252B),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(_tripVehicleIcon(activeTrip), color: const Color(0xFFF97316)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                (activeTrip.vehicleType ?? 'taxi').toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFF4EC),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _InfoTile(label: 'Viaje', value: activeTrip.id),
                          _InfoTile(label: 'Recojo', value: activeTrip.passengerPickup),
                          _InfoTile(label: 'Destino', value: activeTrip.destination),
                          _InfoTile(label: 'Estado', value: activeTrip.status),
                          if (activeTrip.passengerName?.isNotEmpty ?? false)
                            _InfoTile(label: 'Pasajero', value: activeTrip.passengerName!),
                          if (activeTrip.passengerPhone?.isNotEmpty ?? false)
                            _InfoTile(label: 'Telefono', value: activeTrip.passengerPhone!),
                          const SizedBox(height: 12),
                          _DriverTripProgressBar(status: activeTrip.status),
                        ],
                      ),
                    );
                      },
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: session.loggedIn && trip != null
                          ? () => _handleDriverPrimaryAction(trip)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: const Color(0xFF0F0F10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: Text(
                        _driverActionLabel(trip),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DriverTripsTab extends ConsumerWidget {
  const _DriverTripsTab({
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(offeredTripProvider).value;
    final historyAsync = ref.watch(driverTripHistoryProvider);
    return DriverPageShell(
      eyebrow: 'Actividad',
      title: 'Tus viajes',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      child: historyAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => DriverEmptyCard(
          title: 'No pudimos cargar el historial',
          subtitle: error.toString().replaceFirst('Exception: ', ''),
        ),
        data: (history) {
          final trips = <DriverTrip>[
            ...?trip == null ? null : [trip],
            ...history.where((item) => item.id != trip?.id),
          ];

          if (trips.isEmpty) {
            return const DriverEmptyCard(
              title: 'Todavia no hay viajes',
              subtitle: 'Activa disponibilidad para empezar a recibir solicitudes reales.',
            );
          }

          return Column(
            children: [
              for (final item in trips) ...[
                _DriverHistoryCard(
                  trip: item,
                  title: item.id == trip?.id ? 'Viaje actual' : 'Viaje reciente',
                  isCurrentTrip: item.id == trip?.id,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DriverAccountTab extends ConsumerWidget {
  const _DriverAccountTab({
    required this.fullName,
    required this.phone,
    this.onBack,
    required this.onOpenProfile,
    required this.onOpenSecurity,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final String fullName;
  final String phone;
  final VoidCallback? onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSecurity;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DriverPageShell(
      eyebrow: 'Cuenta',
      title: 'Perfil del conductor',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      trailing: IconButton.filledTonal(
        onPressed: onOpenProfile,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF1B1B1F),
          foregroundColor: const Color(0xFFF97316),
        ),
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF2E2E34)),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25252B),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, size: 36, color: Color(0xFFFFF4EC)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFF4EC),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFFFFC89B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DriverMenuTile(
            icon: Icons.shield_outlined,
            title: 'Seguridad',
            subtitle: 'Sesion, OTP y proteccion del conductor.',
            onTap: onOpenSecurity,
          ),
          const SizedBox(height: 14),
          DriverMenuTile(
            icon: Icons.settings_outlined,
            title: 'Configuraciones',
            subtitle: 'Mapa, alertas y preferencias de operacion.',
            onTap: onOpenSettings,
          ),
          const SizedBox(height: 14),
          DriverMenuTile(
            icon: Icons.support_agent,
            title: 'Centro de ayuda',
            subtitle: 'Soporte operativo para viajes y pagos.',
            onTap: onOpenHelp,
          ),
        ],
      ),
    );
  }
}

class _DriverCompactInfoRow extends StatelessWidget {
  const _DriverCompactInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9F978F),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFFF97316),
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1D).withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class _DriverAvailableTripCard extends StatelessWidget {
  const _DriverAvailableTripCard({
    required this.trip,
    required this.accentColor,
    required this.onViewDetails,
    required this.onAccept,
    required this.onReject,
  });

  final DriverTrip trip;
  final Color accentColor;
  final VoidCallback onViewDetails;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final passengerName =
        trip.passengerName?.trim().isNotEmpty == true ? trip.passengerName!.trim() : 'Pasajero';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  switch ((trip.vehicleType ?? '').toLowerCase()) {
                    'moto' => Icons.two_wheeler_rounded,
                    _ => Icons.local_taxi_rounded,
                  },
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passengerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(trip.vehicleType ?? 'taxi').toUpperCase()} solicitado',
                      style: const TextStyle(
                        color: Color(0xFFFFC89B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (trip.isPromotional) ...[
                      const SizedBox(height: 8),
                      const _DriverPromoChip(label: 'VIAJE GRATIS'),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Nuevo',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTile(label: 'Recojo', value: trip.passengerPickup),
          _InfoTile(label: 'Destino', value: trip.destination),
          if (trip.passengerPhone?.trim().isNotEmpty ?? false)
            _InfoTile(label: 'Telefono', value: trip.passengerPhone!.trim()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD8BF),
                    side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Ver detalle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC9C9),
                    side: const BorderSide(color: Color(0x44EF4444)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: const Color(0xFF0F0F10),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverPromoChip extends StatelessWidget {
  const _DriverPromoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x1F22C55E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3322C55E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.card_giftcard_rounded, size: 15, color: Color(0xFF86EFAC)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF86EFAC),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1D),
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: const Color(0x14000003),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: const Color(0xFFF97316)),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFD8BF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverTripProgressBar extends StatelessWidget {
  const _DriverTripProgressBar({
    required this.status,
  });

  final String status;

  static const _steps = [
    ('searching', 'Solicitud'),
    ('accepted', 'Aceptado'),
    ('arriving', 'En camino'),
    ('at_pickup', 'Llego'),
    ('in_progress', 'En curso'),
    ('completed', 'Finalizado'),
  ];

  int get _activeIndex {
    switch (status) {
      case 'requested':
      case 'searching':
        return 0;
      case 'accepted':
        return 1;
      case 'arriving':
        return 2;
      case 'at_pickup':
        return 3;
      case 'in_progress':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(_steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              final segmentIndex = index ~/ 2;
              final isActive = segmentIndex < _activeIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFF97316) : const Color(0x55F97316),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }

            final stepIndex = index ~/ 2;
            final isReached = stepIndex <= _activeIndex;
            return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isReached ? const Color(0xFFF97316) : const Color(0xFF25252B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReached ? const Color(0xFFF97316) : const Color(0x55F97316),
                ),
              ),
              child: Icon(
                isReached ? Icons.check : Icons.circle,
                size: isReached ? 14 : 8,
                color: isReached ? const Color(0xFF0F0F10) : const Color(0xFFFFC89B),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _steps.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value.$2;
            final highlighted = index <= _activeIndex;
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: highlighted ? const Color(0xFFFFF4EC) : const Color(0xFFFFC89B),
                  fontSize: 10,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DriverHistoryCard extends ConsumerWidget {
  const _DriverHistoryCard({
    required this.trip,
    required this.title,
    required this.isCurrentTrip,
  });

  final DriverTrip trip;
  final String title;
  final bool isCurrentTrip;

  bool get _canChat {
    final phone = (trip.passengerPhone ?? '').trim();
    return phone.isNotEmpty &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(trip.status);
  }

  bool get _canCancel {
    return isCurrentTrip &&
        const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status);
  }

  String? _normalizeWhatsAppPhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('591')) {
      return digits;
    }
    return '591$digits';
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final normalizedPhone = _normalizeWhatsAppPhone(trip.passengerPhone);
    if (normalizedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay numero valido del pasajero para WhatsApp.')),
      );
      return;
    }
    final passengerName = (trip.passengerName ?? '').trim().isEmpty ? 'pasajero' : trip.passengerName!.trim();
    final message = trip.status == 'at_pickup'
        ? 'Hola $passengerName, ya llegue al punto de recojo en Flash Go.'
        : 'Hola $passengerName, te escribo por tu viaje de Flash Go.';
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp en este momento.')),
      );
    }
  }

  Future<void> _cancelTrip(BuildContext context, WidgetRef ref) async {
    await ref.read(offeredTripProvider.notifier).updateTripStatus('cancelled');
    if (context.mounted) {
      final error = ref.read(offeredTripProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null ? 'Viaje cancelado.' : error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x55F97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Detalle del viaje',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoTile(label: 'Estado', value: _historyStatusLabel(trip.status)),
                    _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                    _InfoTile(label: 'Destino', value: trip.destination),
                    if (trip.passengerName?.isNotEmpty ?? false)
                      _InfoTile(label: 'Pasajero', value: trip.passengerName!),
                    if (trip.passengerPhone?.isNotEmpty ?? false)
                      _InfoTile(label: 'Telefono', value: trip.passengerPhone!),
                    if (trip.vehicleType?.isNotEmpty ?? false)
                      _InfoTile(label: 'Vehiculo', value: trip.vehicleType!),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _historyAccentColor(trip.status);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _historyStatusLabel(trip.status),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoTile(label: 'ID', value: trip.id),
            _InfoTile(label: 'Recojo', value: trip.passengerPickup),
            _InfoTile(label: 'Destino', value: trip.destination),
            if (trip.passengerName?.isNotEmpty ?? false)
              _InfoTile(label: 'Pasajero', value: trip.passengerName!),
            if (trip.passengerPhone?.isNotEmpty ?? false)
              _InfoTile(label: 'Telefono', value: trip.passengerPhone!),
            const SizedBox(height: 10),
            _DriverTripProgressBar(status: trip.status),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDetails(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD8BF),
                    side: BorderSide(color: accent.withValues(alpha: 0.32)),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Detalle'),
                ),
                if (_canChat)
                  FilledButton.tonalIcon(
                    onPressed: () => _openWhatsApp(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F3A2A),
                      foregroundColor: const Color(0xFFB6F5C8),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    label: const Text('WhatsApp'),
                  ),
                if (_canCancel)
                  FilledButton.tonalIcon(
                    onPressed: () => _cancelTrip(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3A1F1F),
                      foregroundColor: const Color(0xFFFFC9C9),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _historyAccentColor(String status) {
    return switch (status) {
      'completed' => const Color(0xFF22C55E),
      'cancelled' => const Color(0xFFEF4444),
      'in_progress' => const Color(0xFF0EA5E9),
      _ => const Color(0xFFF97316),
    };
  }

  String _historyStatusLabel(String status) {
    return switch (status) {
      'requested' => 'Solicitado',
      'searching' => 'Buscando',
      'accepted' => 'Aceptado',
      'arriving' => 'En camino',
      'at_pickup' => 'Llego',
      'in_progress' => 'En curso',
      'completed' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => status,
    };
  }
}

class _DriverMiniBadge extends StatelessWidget {
  const _DriverMiniBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFF97316)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFF4EC),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
