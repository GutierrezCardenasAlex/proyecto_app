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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nueva oferta disponible. Revisa el viaje entrante.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_statusMessage(status)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
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

    return Scaffold(
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
      backgroundColor: const Color(0xFFF9F9FB),
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
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
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.microtask(() async {
      await Permission.notification.request();
      await LocalNotifications.ensureInitialized();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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

  void _showOfferSheet(BuildContext context, DriverTrip? trip) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Color(0xFFFEFEFF),
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
                    color: const Color(0xFFE2E2E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Ofertas activas',
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (trip == null)
                const DriverEmptyCard(
                  title: 'Sin ofertas por ahora',
                  subtitle: 'Activa disponibilidad para recibir solicitudes cercanas.',
                )
              else ...[
                _InfoTile(label: 'Viaje', value: trip.id),
                _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                _InfoTile(label: 'Tarifa', value: 'Bs ${trip.fareAmount.toStringAsFixed(0)}'),
                _InfoTile(label: 'Estado', value: trip.status),
                _InfoTile(
                  label: 'Ubicacion',
                  value: '${trip.pickupLat.toStringAsFixed(5)}, ${trip.pickupLng.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _handleDriverPrimaryAction(trip);
                    },
                    child: Text(_driverActionLabel(trip)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
            color: Color(0xFFFEFEFF),
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
                    color: const Color(0xFFE2E2E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Estado del conductor',
                style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800),
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
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Mantiene tu estado de busqueda y vuelve a enviar GPS.'),
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
                            color: const Color(0xFF00E3FD),
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
              tripAccepted: trip?.status == 'accepted',
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
                    const Color(0xFFF9F9FB).withValues(alpha: 0.90),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFFF9F9FB),
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
                          'Taxi Ya Driver',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onProfileTap,
                        child: const Icon(Icons.person, color: Color(0xFF000003)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000003),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              driverState.available ? Icons.radio_button_checked : Icons.pause_circle_outline,
                              color: driverState.available ? const Color(0xFF006875) : const Color(0xFF77767C),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverState.available ? 'Buscando viaje' : 'Fuera de linea',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _statusChipLabel(driverState, trip),
                                  style: const TextStyle(
                                    color: Color(0xFF47464B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showStatusSheet(context, driverState, trip),
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Estado'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.86),
                          foregroundColor: const Color(0xFF001F24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showOfferSheet(context, trip),
                        icon: const Icon(Icons.local_activity_outlined),
                        label: const Text('Ofertas activas'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.86),
                          foregroundColor: const Color(0xFF001F24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 236,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
              const SizedBox(height: 12),
              _MapActionButton(
                icon: Icons.tune_outlined,
                onTap: () => _showStatusSheet(context, driverState, trip),
              ),
              const SizedBox(height: 12),
              _MapActionButton(
                icon: Icons.local_activity_outlined,
                onTap: () => _showOfferSheet(context, trip),
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
                color: Color(0xFFFEFEFF),
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
                        color: const Color(0xFFE2E2E4),
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
                            color: const Color(0xFFF3F3F5),
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
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                session.phone,
                                style: const TextStyle(
                                  color: Color(0xFF47464B),
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
                            color: const Color(0xFFF3F3F5),
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
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _statusChipLabel(driverState, trip),
                                style: const TextStyle(
                                  color: Color(0xFF47464B),
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
                        icon: const Icon(Icons.tune_outlined),
                        label: const Text('Ver estado'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showOfferSheet(context, trip),
                        icon: const Icon(Icons.local_activity_outlined),
                        label: const Text('Ver ofertas'),
                      ),
                    ],
                  ),
                  if (driverState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDAD6),
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tripDescription(trip),
                    style: const TextStyle(
                      color: Color(0xFF47464B),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x1AC8C5CC)),
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
                                  color: const Color(0xFFF3F3F5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(_tripVehicleIcon(trip), color: const Color(0xFF006875)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                (trip.vehicleType ?? 'taxi').toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
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
                        backgroundColor: const Color(0xFF00E3FD),
                        foregroundColor: const Color(0xFF001F24),
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
    return DriverPageShell(
      eyebrow: 'Actividad',
      title: 'Tus viajes',
      child: Column(
        children: [
          if (trip == null)
            const DriverEmptyCard(
              title: 'Todavia no hay viajes',
              subtitle: 'Activa disponibilidad para empezar a recibir solicitudes reales.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitud actual',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoTile(label: 'ID', value: trip.id),
                    _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                    _InfoTile(label: 'Destino', value: trip.destination),
                    _InfoTile(label: 'Estado', value: trip.status),
                  ],
                ),
              ),
            ),
        ],
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
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, size: 36),
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF47464B),
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
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: const Color(0xFF000003)),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: const Color(0x14000003),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: const Color(0xFF1A1C1D)),
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
                color: Color(0xFF657684),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF102A3B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
