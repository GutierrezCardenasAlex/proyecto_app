import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../auth/data/auth_repository.dart';
import '../../../../core/config/app_config.dart';
import '../../../map/data/location_controller.dart';
import '../../../map/presentation/potosi_map.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';

class RideTab extends ConsumerStatefulWidget {
  const RideTab({
    super.key,
    required this.onMenuTap,
    required this.onProfileTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<RideTab> createState() => _RideTabState();
}

class _RideTabState extends ConsumerState<RideTab> {
  final TextEditingController _destinationController = TextEditingController();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Timer? _refreshTimer;
  Timer? _notificationTimer;
  ProviderSubscription<TripState>? _tripSubscription;
  io.Socket? _socket;
  double _sheetSize = 0.34;
  String? _floatingNotification;
  RideMode _rideMode = RideMode.destino;
  String? _joinedTripId;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_syncDashboard);
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) => _syncDashboard());
    _connectSocket();
    _tripSubscription = ref.listenManual<TripState>(tripProvider, (previous, next) {
      final previousStatus = previous?.request.status;
      final currentStatus = next.request.status;
      if (previousStatus != currentStatus && currentStatus == 'accepted') {
        _showFloatingNotification('Tu auto ha sido aceptado');
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _notificationTimer?.cancel();
    _tripSubscription?.close();
    _socket?.dispose();
    _sheetController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _connectSocket() {
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
      final tripId = ref.read(tripProvider).request.activeTripId;
      if (tripId != null && tripId.isNotEmpty) {
        _joinTripRoom(tripId);
      }
    });
    _socket?.on('trip:accepted', (data) {
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final tripId = map['tripId']?.toString();
      if (tripId != null && tripId.isNotEmpty) {
        ref.read(tripProvider.notifier).markTripAccepted(tripId: tripId);
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

  Future<void> _syncDashboard() async {
    final session = ref.read(sessionProvider);
    final location = ref.read(passengerLocationProvider).position;
    if (!mounted || !session.isAuthenticated || location == null) {
      return;
    }

    await ref.read(tripProvider.notifier).loadDashboard(
          token: session.token,
          passengerId: session.userId,
          userLocation: location,
        );
  }

  Future<void> _requestRide() async {
    final session = ref.read(sessionProvider);
    final locationState = ref.read(passengerLocationProvider);
    final location = locationState.position;
    final destination = _destinationController.text.trim();

    if (location == null) {
      _showMessage(locationState.errorMessage ?? 'Activa tu ubicacion para pedir un taxi.');
      return;
    }

    if (destination.isEmpty) {
      _showMessage('Ingresa un destino para continuar.');
      return;
    }

    await ref.read(tripProvider.notifier).requestRide(
          token: session.token,
          passengerId: session.userId,
          userLocation: location,
          destinationAddress: destination,
        );

    final error = ref.read(tripProvider).errorMessage;
    if (error != null && mounted) {
      _showMessage(error.replaceFirst('Exception: ', ''));
      return;
    }

    if (mounted) {
      _showFloatingNotification('Solicitud enviada. Estamos buscando un conductor.');
    }
  }

  Future<void> _toggleSheet() async {
    final target = _sheetSize <= 0.08 ? 0.34 : 0.0;
    await _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectNearestTaxi() {
    final drivers = ref.read(tripProvider).nearbyDrivers;
    if (drivers.isEmpty) {
      _showMessage('No hay taxis cercanos disponibles en este momento.');
      return;
    }

    final nearest = drivers.first;
    _showFloatingNotification(
      'El taxi mas cercano llega en ${nearest.etaMinutes} min. Puedes abordarlo directamente.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showFloatingNotification(String message) {
    _notificationTimer?.cancel();
    setState(() => _floatingNotification = message);
    _notificationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _floatingNotification = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(passengerLocationProvider);
    final tripState = ref.watch(tripProvider);
    final activeTripId = tripState.request.activeTripId;
    if (activeTripId != null && activeTripId.isNotEmpty && _socket?.connected == true) {
      _joinTripRoom(activeTripId);
    }
    final userLocation = locationState.position ?? const LatLng(-19.5836, -65.7531);
    final driverPoints = tripState.nearbyDrivers
        .map((driver) => LatLng(driver.lat, driver.lng))
        .toList(growable: false);

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEDF8FB), Color(0xFFF9F9FB)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: PotosiMap(
                drivers: driverPoints,
                userLocation: userLocation,
                destination: null,
                showRoute: false,
              ),
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
                    _GlassIconButton(
                      icon: Icons.menu,
                      onTap: widget.onMenuTap,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Taxi Ya',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF000003),
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
                  child: Container(
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
                        const Icon(Icons.place, color: Color(0xFF006875)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu ubicacion',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF000003),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Potosi, Bolivia',
                              style: TextStyle(
                                color: Color(0xFF47464B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_floatingNotification != null) ...[
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(_floatingNotification),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000003).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000003),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFF00E3FD)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _floatingNotification!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 170,
          child: Column(
            children: [
              _MapActionButton(
                icon: Icons.my_location,
                onTap: () async {
                  await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
                  await _syncDashboard();
                },
              ),
              const SizedBox(height: 12),
              _MapActionButton(
                icon: _sheetSize <= 0.08 ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                onTap: _toggleSheet,
              ),
            ],
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if ((_sheetSize - notification.extent).abs() > 0.01) {
              setState(() => _sheetSize = notification.extent);
            }
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.34,
            minChildSize: 0.0,
            maxChildSize: 0.80,
            snap: true,
            snapSizes: const [0.0, 0.34, 0.58, 0.80],
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
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeButton(
                              label: 'Pedir taxi',
                              selected: _rideMode == RideMode.destino,
                              onTap: () => setState(() => _rideMode = RideMode.destino),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ModeButton(
                              label: 'Tomar taxi',
                              selected: _rideMode == RideMode.cercano,
                              onTap: () => setState(() => _rideMode = RideMode.cercano),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_rideMode == RideMode.destino)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Color(0xFF006875)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _destinationController,
                                decoration: const InputDecoration(
                                  hintText: '¿A dónde quieres ir?',
                                  border: InputBorder.none,
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.schedule, color: Color(0xFF77767C)),
                          ],
                        ),
                      ),
                    if (_rideMode == RideMode.destino) const SizedBox(height: 18),
                    if (locationState.errorMessage != null)
                      _StatusBanner(
                        message: locationState.errorMessage!,
                        color: const Color(0xFFFFDAD6),
                        textColor: const Color(0xFF93000A),
                      ),
                    if (tripState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _StatusBanner(
                          message: tripState.errorMessage!.replaceFirst('Exception: ', ''),
                          color: const Color(0xFFFFDAD6),
                          textColor: const Color(0xFF93000A),
                        ),
                      ),
                    if (tripState.request.activeTripId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _StatusBanner(
                          message:
                              'Viaje activo: ${tripState.request.destinationAddress} · estado ${tripState.request.status}',
                          color: const Color(0x1A00E3FD),
                          textColor: const Color(0xFF00616D),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      _rideMode == RideMode.destino ? 'Autos disponibles' : 'Que taxi tomar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF000003),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rideMode == RideMode.destino
                          ? 'Tu viaje sale desde tu ubicacion actual y termina donde elijas.'
                          : 'Mira los taxis cercanos para subir al que te convenga mas rapido.',
                      style: const TextStyle(
                        color: Color(0xFF47464B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ..._buildVehicleCards(tripState.nearbyDrivers),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: tripState.isRequestingTrip
                            ? null
                            : (_rideMode == RideMode.destino ? _requestRide : _selectNearestTaxi),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00E3FD),
                          foregroundColor: const Color(0xFF001F24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: tripState.isRequestingTrip
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : Text(
                                _rideMode == RideMode.destino
                                    ? 'Solicitar taxi'
                                    : 'Elegir taxi mas cercano',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        locationState.position == null
                            ? 'Estamos esperando tu GPS para afinar la oferta.'
                            : 'Tu punto actual esta dentro del radio operativo de Potosi.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF77767C),
                          fontWeight: FontWeight.w600,
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

  List<Widget> _buildVehicleCards(List<NearbyDriver> drivers) {
    if (drivers.isEmpty) {
      return const [
        _EmptyRideCard(),
      ];
    }

    const icons = [
      Icons.electric_car,
      Icons.directions_car,
      Icons.local_taxi,
      Icons.airport_shuttle,
    ];
    const names = ['Taxi Eco', 'Taxi Plus', 'Taxi Ejecutivo', 'Taxi Max'];

    return List<Widget>.generate(drivers.length, (index) {
      final driver = drivers[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _VehicleOptionCard(
          title: names[index % names.length],
          eta: '${driver.etaMinutes} min',
          price: 'Bs ${(8 + driver.distanceMeters / 300).toStringAsFixed(0)}',
          rating: driver.rating.toStringAsFixed(1),
          distance: '${(driver.distanceMeters / 1000).toStringAsFixed(1)} km',
          icon: icons[index % icons.length],
          highlighted: index == 0,
        ),
      );
    });
  }
}

enum RideMode {
  destino,
  cercano,
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF00E3FD) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? const Color(0xFF001F24) : const Color(0xFF47464B),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleOptionCard extends StatelessWidget {
  const _VehicleOptionCard({
    required this.title,
    required this.eta,
    required this.price,
    required this.rating,
    required this.distance,
    required this.icon,
    required this.highlighted,
  });

  final String title;
  final String eta;
  final String price;
  final String rating;
  final String distance;
  final IconData icon;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF3F3F5) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted ? Colors.transparent : const Color(0x1AC8C5CC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFF000003) : const Color(0xFFE8E8EA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: highlighted ? const Color(0xFF00E3FD) : const Color(0xFF000003),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Llega en $eta · $distance',
                  style: const TextStyle(
                    color: Color(0xFF47464B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFF00E3FD), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRideCard extends StatelessWidget {
  const _EmptyRideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Todavia no vemos taxis activos. Usa "mi ubicacion" y espera unos segundos para cargar autos cercanos.',
        style: TextStyle(
          color: Color(0xFF47464B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
