import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/driver_login_card.dart';
import '../../auth/presentation/driver_profile_completion_page.dart';
import '../../map/presentation/driver_map.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/driver_trip.dart';
import '../../../core/config/app_config.dart';
import '../../../core/notifications/local_notifications.dart';
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

    if (!session.profileCompleted) {
      return const DriverProfileCompletionPage();
    }

    if (_restoredDriverId != session.driverId && session.driverId.isNotEmpty) {
      _restoredDriverId = session.driverId;
      Future<void>.microtask(_restoreDriverOperationalState);
    }

    if (session.driverId.isNotEmpty) {
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
        onProfileTap: () => _openPage(const DriverProfilePage(), drawerItem: 'Configuraciones'),
      ),
      const _DriverTripsTab(),
      _DriverAccountTab(
        fullName: session.fullName,
        phone: session.phone,
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
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            height: 74,
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0x22F97316),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (value) => setState(() {
              _markInteraction();
              _selectedIndex = value;
              _activeDrawerItem = switch (value) {
                0 => 'Panel de viaje',
                1 => 'Historial',
                _ => 'Configuraciones',
              };
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.local_taxi_outlined),
                selectedIcon: Icon(Icons.local_taxi),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: 'Viajes',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Cuenta',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armInactivityTimer();
    Future<void>.microtask(() async {
      await Permission.notification.request();
      await LocalNotifications.ensureInitialized();
    });
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
    await ref.read(driverStateProvider.notifier).restoreOperationalState();
    await ref.read(offeredTripProvider.notifier).loadOffer();
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
    required this.onProfileTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<_DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<_DriverDashboard> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetSize = 0.36;

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

  void _showStatusSheet(BuildContext context, DriverState driverState, DriverTrip? trip) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF121214),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
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
                _InfoTile(label: 'Viaje', value: trip.id),
                _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                _InfoTile(label: 'Estado viaje', value: trip.status),
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
      'completed' => 'Viaje finalizado. Ya puedes calificar al pasajero.',
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
      'completed' => 'Calificar pasajero',
      _ => 'Aceptar viaje',
    };
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

  String _driverStatusMiniDetail(DriverTrip trip) {
    if (trip.passengerPickup.isNotEmpty) {
      return trip.passengerPickup;
    }
    return 'Ver detalle';
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

  Future<void> _handleDriverPrimaryAction(DriverTrip? trip) async {
    if (trip == null) {
      return;
    }

    if (trip.status == 'requested' || trip.status == 'searching') {
      await ref.read(offeredTripProvider.notifier).acceptTrip();
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
      return;
    }
    await _submitDriverRating(context, ref, trip);
  }

  Future<void> _submitDriverRating(BuildContext context, WidgetRef ref, DriverTrip trip) async {
    int selectedScore = 5;
    final commentController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Califica al pasajero'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 4,
                      children: List<Widget>.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () => setDialogState(() => selectedScore = value),
                          icon: Icon(
                            value <= selectedScore ? Icons.star : Icons.star_border,
                            color: const Color(0xFFF97316),
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Comentario opcional',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Luego'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Enviar'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true) {
        await ref.read(offeredTripProvider.notifier).submitRating(
              score: selectedScore,
              comment: commentController.text,
            );
        await ref.read(driverStateProvider.notifier).toggleAvailability(true);
      }
    } finally {
      commentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverStateProvider);
    final tripAsync = ref.watch(offeredTripProvider);
    final trip = tripAsync.value;
    final session = ref.watch(driverSessionProvider);

    if (session.loggedIn && driverState.available && !tripAsync.isLoading && trip == null) {
      Future<void>.microtask(() => ref.read(offeredTripProvider.notifier).loadOffer());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DriverMap(
              key: ValueKey(
                'driver-map-${trip?.status}-${trip?.pickupLat}-${trip?.pickupLng}-${driverState.lat}-${driverState.lng}',
              ),
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
                    Expanded(
                      child: Center(
                        child: Text(
                          'Flash Go Driver',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFFF4EC),
                          ),
                        ),
                      ),
                    ),
                    _GlassIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () async {
                        await ref.read(driverStateProvider.notifier).restoreOperationalState();
                        await ref.read(offeredTripProvider.notifier).loadOffer();
                      },
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0x33F97316), width: 2),
                        color: const Color(0xFF1A1A1D).withValues(alpha: 0.90),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onProfileTap,
                        child: const Icon(Icons.person, color: Color(0xFFF97316)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17181B).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0x44F97316)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: driverState.available
                                ? const Color(0x33F97316)
                                : const Color(0xFF25252B),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            driverState.available ? Icons.radar_rounded : Icons.pause_circle_outline,
                            color: driverState.available ? const Color(0xFFF97316) : const Color(0xFFFFC89B),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverState.available ? 'Buscando viaje' : 'Fuera de linea',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFF4EC),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _statusChipLabel(driverState, trip),
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
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        if (trip != null)
          Positioned(
            right: 20,
            top: 132,
            child: _DriverSideStatusChip(
              title: 'Estado',
              value: _driverStatusShortLabel(trip.status),
              subtitle: _driverStatusMiniDetail(trip),
              accentColor: _driverStatusAccentColor(trip.status),
              onTap: () => _showStatusSheet(context, driverState, trip),
            ),
          ),
        if (trip != null && trip.status != 'completed')
          Positioned(
            right: 20,
            top: 258,
            child: _DriverQuickActionChip(
              label: _driverActionLabel(trip),
              accentColor: _driverStatusAccentColor(trip.status),
              onTap: () => _handleDriverPrimaryAction(trip),
            ),
          ),
        Positioned(
          right: 20,
          bottom: trip != null && trip.status != 'completed' ? 204 : 236,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
              const SizedBox(height: 12),
              _MapActionButton(
                icon: Icons.tune_rounded,
                onTap: () => _showStatusSheet(context, driverState, trip),
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
                    'Viaje entrante',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tripDescription(trip),
                    style: const TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (tripAsync.isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ))
                  else if (trip == null)
                    const DriverEmptyCard(
                      title: 'Sin ofertas activas',
                      subtitle: 'Cuando un pasajero solicite un taxi cercano, aparecera aqui.',
                    )
                  else
                    Container(
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
                                child: Icon(_tripVehicleIcon(trip), color: const Color(0xFFF97316)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                (trip.vehicleType ?? 'taxi').toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFF4EC),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _InfoTile(label: 'Viaje', value: trip.id),
                          _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                          _InfoTile(label: 'Destino', value: trip.destination),
                          _InfoTile(label: 'Tarifa', value: 'Bs ${trip.fareAmount.toStringAsFixed(0)}'),
                          _InfoTile(label: 'Estado', value: trip.status),
                          const SizedBox(height: 12),
                          _DriverTripProgressBar(status: trip.status),
                        ],
                      ),
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
  const _DriverTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(offeredTripProvider).value;
    final historyAsync = ref.watch(driverTripHistoryProvider);
    return DriverPageShell(
      eyebrow: 'Actividad',
      title: 'Tus viajes',
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
    required this.onOpenProfile,
    required this.onOpenSecurity,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final String fullName;
  final String phone;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSecurity;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DriverPageShell(
      eyebrow: 'Cuenta',
      title: 'Perfil del conductor',
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

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
          child: Icon(icon, color: const Color(0xFFF97316)),
        ),
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

class _DriverHistoryCard extends StatelessWidget {
  const _DriverHistoryCard({
    required this.trip,
    required this.title,
  });

  final DriverTrip trip;
  final String title;

  @override
  Widget build(BuildContext context) {
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
            _InfoTile(label: 'Tarifa', value: 'Bs ${trip.fareAmount.toStringAsFixed(0)}'),
            const SizedBox(height: 10),
            _DriverTripProgressBar(status: trip.status),
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

class _DriverSideStatusChip extends StatelessWidget {
  const _DriverSideStatusChip({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accentColor.withValues(alpha: 0.70)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timeline_rounded, color: accentColor, size: 20),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFC89B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFFF4EC),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFC89B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverQuickActionChip extends StatelessWidget {
  const _DriverQuickActionChip({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 108,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF0F0F10), size: 20),
              const SizedBox(height: 8),
              const Text(
                'Accion',
                style: TextStyle(
                  color: Color(0xFF3B1B05),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F0F10),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
