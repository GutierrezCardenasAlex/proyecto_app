import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/driver_login_card.dart';
import '../../map/presentation/driver_map.dart';
import '../../trip/data/trip_repository.dart';
import '../data/driver_repository.dart';

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(driverSessionProvider);
    final driverState = ref.watch(driverStateProvider);
    final trip = ref.watch(offeredTripProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F5F8), Color(0xFFE4ECF3)],
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
                    children: [
                      const _DriverHero(),
                      const SizedBox(height: 16),
                      const DriverLoginCard(),
                      const SizedBox(height: 16),
                      Card(
                        child: SwitchListTile(
                          value: driverState.available,
                          onChanged: session.loggedIn
                              ? (value) => ref.read(driverStateProvider.notifier).toggleAvailability(value)
                              : null,
                          title: const Text(
                            'Disponibilidad del conductor',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            driverState.lastLocationPing == null
                                ? 'Sin ping GPS enviado todavia'
                                : 'Ultimo ping GPS: ${driverState.lastLocationPing}',
                          ),
                        ),
                      ),
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
                            const Text(
                              'Ruta activa',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Color(0xFF16354C),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Servidor: ${AppConfig.apiBaseUrl}',
                              style: const TextStyle(color: Color(0xFF657684)),
                            ),
                            const SizedBox(height: 14),
                            const SizedBox(
                              height: 320,
                              child: DriverMap(),
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
                                      color: const Color(0xFFE5EEF6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.notifications_active, color: Color(0xFF16354C)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Oferta de viaje',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Diseño listo para demo de conductor.',
                                          style: TextStyle(color: Color(0xFF657684)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoTile(label: 'Viaje', value: trip.id),
                              _InfoTile(label: 'Recojo', value: trip.passengerPickup),
                              _InfoTile(label: 'Destino', value: trip.destination),
                              _InfoTile(label: 'Estado', value: trip.status),
                              _InfoTile(label: 'Conductor', value: session.phone.isEmpty ? 'Sin sesion' : session.phone),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: session.loggedIn && driverState.available
                                      ? () => ref.read(offeredTripProvider.notifier).acceptTrip()
                                      : null,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    backgroundColor: const Color(0xFF16354C),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Aceptar viaje'),
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

class _DriverHero extends StatelessWidget {
  const _DriverHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16354C), Color(0xFF2E6186)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3316354C),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taxi Ya Driver',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Panel del conductor conectado a tu servidor local 192.168.0.99 para pruebas en tiempo real.',
            style: TextStyle(
              color: Color(0xFFDCE7EF),
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
