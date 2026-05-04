import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import 'ui_kit.dart';

class ActivityTab extends ConsumerWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final tripState = ref.watch(tripProvider);

    return PageShell(
      eyebrow: 'Historial',
      title: 'Tus viajes',
      child: Column(
        children: [
          if (tripState.history.isEmpty)
            const EmptyCard(
              title: 'Sin historial aun',
              subtitle: 'Tus viajes confirmados apareceran aqui cuando empieces a moverte por Potosi.',
            )
          else
            ...tripState.history.map((trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _JourneyCard(
                    trip: trip,
                    passengerName: session.fullName,
                  ),
                )),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.trip,
    required this.passengerName,
  });

  final TripHistoryItem trip;
  final String passengerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 132,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              gradient: LinearGradient(
                colors: [Color(0xFFEAFBFD), Color(0xFFF3F3F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 22,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E3FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trip.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFF001F24),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 24,
                  bottom: 22,
                  child: Icon(Icons.alt_route, size: 52, color: Color(0x22006875)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.requestedAt.isEmpty ? 'Fecha no disponible' : trip.requestedAt,
                            style: const TextStyle(
                              color: Color(0xFF77767C),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${trip.pickupAddress} a ${trip.destinationAddress}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF000003),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Bs 18',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF000003),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF000003)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pasajero',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                color: Color(0xFF77767C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              passengerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF000003),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Color(0xFF00E3FD)),
                          SizedBox(width: 4),
                          Text(
                            '4.9',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
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
