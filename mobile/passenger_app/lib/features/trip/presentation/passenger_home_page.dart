import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/login_card.dart';
import '../../map/presentation/potosi_map.dart';
import '../data/trip_repository.dart';

class PassengerHomePage extends ConsumerWidget {
  const PassengerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final trip = ref.watch(tripProvider);
    final nearbyDrivers = const [
      LatLng(-19.586, -65.755),
      LatLng(-19.580, -65.748),
      LatLng(-19.592, -65.751),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F1E8), Color(0xFFE7EEF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _HeroSection(),
                      const SizedBox(height: 16),
                      const LoginCard(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A17354E),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Centro de operaciones Potosi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: Color(0xFF16354C),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Mapa en vivo limitado a 15 km desde el centro de la ciudad.',
                                        style: TextStyle(color: Color(0xFF5A6B78)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCE6DB),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Solo Potosi',
                                    style: TextStyle(
                                      color: Color(0xFFBE562C),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 320,
                              child: PotosiMap(
                                drivers: nearbyDrivers,
                                pickup: const LatLng(-19.5854, -65.7542),
                                destination: const LatLng(-19.5747, -65.7454),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE6DB),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.route, color: Color(0xFFDB5F2D)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Viaje actual',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Prueba tu app contra el backend en tu Wi-Fi local.',
                                          style: TextStyle(color: Color(0xFF667785)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoTile(label: 'Pasajero', value: session.phone.isEmpty ? 'No autenticado' : session.phone),
                              _InfoTile(label: 'Pickup', value: trip.pickupAddress),
                              _InfoTile(label: 'Destino', value: trip.destinationAddress),
                              _InfoTile(label: 'Estado', value: trip.status),
                              _InfoTile(label: 'Gateway', value: AppConfig.apiBaseUrl),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: session.isAuthenticated
                                      ? () => ref.read(tripProvider.notifier).requestRide()
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFDB5F2D),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(54),
                                  ),
                                  child: const Text('Solicitar Taxi'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            'Movilidad urbana en tiempo real para Potosi, lista para probarse desde tu servidor 192.168.0.99.',
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

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
                color: Color(0xFF667785),
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
