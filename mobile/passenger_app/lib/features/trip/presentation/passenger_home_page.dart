import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../map/data/location_controller.dart';
import '../../map/presentation/potosi_map.dart';
import '../data/trip_repository.dart';
import '../domain/trip_request.dart';

class PassengerHomePage extends ConsumerStatefulWidget {
  const PassengerHomePage({super.key});

  @override
  ConsumerState<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends ConsumerState<PassengerHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session.isRestoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!session.isAuthenticated) {
      return const _LoginShell();
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _HomeTab(),
          _HistoryTab(),
          _NotificationsTab(),
          _SupportTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) => setState(() => _selectedIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications), label: 'Avisos'),
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Soporte'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _LoginShell extends StatelessWidget {
  const _LoginShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F1E8), Color(0xFFE6EDF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _HeroSection(),
              SizedBox(height: 16),
              LoginCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(passengerLocationProvider.notifier).loadCurrentLocation();
      await _loadData();
      _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _loadData());
    });
  }

  Future<void> _loadData() async {
    final session = ref.read(sessionProvider);
    final location = ref.read(passengerLocationProvider);
    final controller = ref.read(tripProvider.notifier);
    final userLocation = location.position ?? const LatLng(-19.5836, -65.7531);

    await controller.loadDashboard(
      token: session.token,
      passengerId: session.userId,
      userLocation: userLocation,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final tripState = ref.watch(tripProvider);
    final locationState = ref.watch(passengerLocationProvider);
    final locationController = ref.read(passengerLocationProvider.notifier);

    final userLocation = locationState.position ?? const LatLng(-19.5836, -65.7531);
    final destination = LatLng(userLocation.latitude + 0.0085, userLocation.longitude + 0.0065);
    final nearbyDrivers = tripState.nearbyDrivers;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: PotosiMap(
              drivers: nearbyDrivers.map((item) => LatLng(item.lat, item.lng)).toList(),
              userLocation: userLocation,
              destination: destination,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A17354E),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hola, ${session.fullName}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF132A3A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Potosi, Bolivia',
                                  style: TextStyle(
                                    color: Color(0xFF6C7B86),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () async {
                              await locationController.loadCurrentLocation();
                              await _loadData();
                            },
                            icon: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                    if (locationState.errorMessage != null || tripState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            locationState.errorMessage ?? tripState.errorMessage ?? '',
                            style: const TextStyle(
                              color: Color(0xFF214A6B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.18,
            maxChildSize: 0.76,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F4EE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x3317354E),
                      blurRadius: 24,
                      offset: Offset(0, -10),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D7DD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Que auto tomar',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF132A3A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nearbyDrivers.isEmpty
                          ? 'Aun no hay conductores cercanos.'
                          : '${nearbyDrivers.length} autos cerca de tu ubicacion actual.',
                      style: const TextStyle(color: Color(0xFF667785)),
                    ),
                    const SizedBox(height: 14),
                    if (tripState.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (nearbyDrivers.isEmpty)
                      const _EmptyCard(
                        title: 'No hay autos cercanos por ahora',
                        subtitle: 'Deja el simulador corriendo o actualiza tu ubicacion.',
                      )
                    else
                      ...nearbyDrivers.map(
                        (driver) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _NearbyCarTile(
                            driver: driver,
                            onRequest: () => _showRequestTripSheet(context, ref, userLocation),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestTripSheet(BuildContext context, WidgetRef ref, LatLng userLocation) async {
    final controller = TextEditingController(text: 'Terminal de Buses Potosi');
    final session = ref.read(sessionProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solicitar taxi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Destino',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(tripProvider.notifier).requestRide(
                          token: session.token,
                          passengerId: session.userId,
                          userLocation: userLocation,
                          destinationAddress: controller.text,
                        );
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Confirmar viaje'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final session = ref.read(sessionProvider);
      final location = ref.read(passengerLocationProvider);
      await ref.read(tripProvider.notifier).loadDashboard(
            token: session.token,
            passengerId: session.userId,
            userLocation: location.position ?? const LatLng(-19.5836, -65.7531),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(tripProvider).history;
    return _PageShell(
      title: 'Historial de solicitudes',
      subtitle: 'Tus viajes reales guardados en el backend.',
      child: history.isEmpty
          ? const _EmptyCard(
              title: 'Sin historial disponible',
              subtitle: 'Todavia no hay viajes registrados para este usuario.',
            )
          : Column(
              children: history
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HistoryTile(item: item),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return const _PageShell(
      title: 'Notificaciones',
      subtitle: 'Actualizaciones de viajes, seguridad y actividad de la cuenta.',
      child: Column(
        children: [
          _SimpleListTile(title: 'Tu ultimo viaje fue completado', subtitle: 'Hace 1 hora', icon: Icons.check_circle_outline),
          SizedBox(height: 12),
          _SimpleListTile(title: 'Verifica siempre la placa del auto', subtitle: 'Consejo de seguridad', icon: Icons.verified_user_outlined),
          SizedBox(height: 12),
          _SimpleListTile(title: 'Promociones activas en Potosi', subtitle: 'Ahorra en tus proximos viajes', icon: Icons.local_offer_outlined),
        ],
      ),
    );
  }
}

class _SupportTab extends StatelessWidget {
  const _SupportTab();

  @override
  Widget build(BuildContext context) {
    return const _PageShell(
      title: 'Ayuda y soporte',
      subtitle: 'Canales de soporte, seguridad y asistencia.',
      child: Column(
        children: [
          _SimpleListTile(title: 'Centro de ayuda', subtitle: 'Guias para usar la app y resolver problemas', icon: Icons.help_outline_rounded),
          SizedBox(height: 12),
          _SimpleListTile(title: 'Soporte en viaje', subtitle: 'Reporta un incidente o pide ayuda inmediata', icon: Icons.support_agent_rounded),
          SizedBox(height: 12),
          _SimpleListTile(title: 'Seguridad', subtitle: 'Consejos y opciones para proteger tu cuenta', icon: Icons.shield_outlined),
        ],
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider).request;

    return _PageShell(
      title: 'Perfil',
      subtitle: 'Tus datos personales y configuraciones principales.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF16354C), Color(0xFF25597C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  session.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(session.phone, style: const TextStyle(color: Color(0xFFD9E5ED))),
                const SizedBox(height: 4),
                const Text('Ciudad: Potosi', style: TextStyle(color: Color(0xFFD9E5ED))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileInfoCard(
            title: 'Datos de la persona',
            rows: [
              ('Nombre', session.fullName),
              ('Telefono', session.phone),
              ('Ciudad', 'Potosi'),
              ('Estado de viaje', trip.status),
            ],
          ),
          const SizedBox(height: 16),
          const _ProfileMenuCard(
            title: 'Configuraciones',
            items: [
              ('Seguridad', Icons.shield_outlined),
              ('Configuraciones', Icons.settings_outlined),
              ('Ayuda', Icons.help_outline_rounded),
              ('Soporte', Icons.support_agent_rounded),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesion'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF4EEE4), Color(0xFFE7EDF3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF132A3A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF6C7B86)),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDB5F2D), Color(0xFFF09A63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33DB5F2D),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taxi Ya',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Mapa grande, autos cercanos y flujo de viaje real conectado al backend.',
            style: TextStyle(
              color: Color(0xFFFFF3EB),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyCarTile extends StatelessWidget {
  const _NearbyCarTile({
    required this.driver,
    required this.onRequest,
  });

  final NearbyDriver driver;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1417354E),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE6DB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.local_taxi, color: Color(0xFFDB5F2D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto cercano ${driver.driverId.substring(0, 6)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${driver.etaMinutes} min • ${(driver.distanceMeters / 1000).toStringAsFixed(2)} km • rating ${driver.rating.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF667785)),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onRequest,
            child: const Text('Tomar'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final TripHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.pickupAddress} -> ${item.destinationAddress}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                item.status,
                style: const TextStyle(
                  color: Color(0xFF16354C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.requestedAt,
            style: const TextStyle(color: Color(0xFF667785)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF667785)),
          ),
        ],
      ),
    );
  }
}

class _SimpleListTile extends StatelessWidget {
  const _SimpleListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF16354C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF667785)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        color: Color(0xFF667785),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<(String, IconData)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(item.$2),
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}
