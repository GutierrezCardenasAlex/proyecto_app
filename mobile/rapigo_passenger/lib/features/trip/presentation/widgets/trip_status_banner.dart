import 'package:flutter/material.dart';

class TripStatusPresentation {
  const TripStatusPresentation(
    this.title,
    this.message,
    this.icon,
    this.color,
    this.step,
  );
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final int step;

  static TripStatusPresentation fromStatus(String status) => switch (status) {
    'requested' || 'searching' => const TripStatusPresentation(
      'Buscando conductor',
      'Enviamos tu solicitud a los conductores cercanos.',
      Icons.radar_rounded,
      Color(0xFF1D4ED8),
      0,
    ),
    'accepted' => const TripStatusPresentation(
      'Conductor asignado',
      'Tu solicitud fue aceptada. Revisa los datos del vehículo.',
      Icons.local_taxi_rounded,
      Color(0xFF1D4ED8),
      1,
    ),
    'arriving' => const TripStatusPresentation(
      'Tu taxi está en camino',
      'El conductor se dirige al punto de recogida.',
      Icons.near_me_rounded,
      Color(0xFF1D4ED8),
      1,
    ),
    'at_pickup' => const TripStatusPresentation(
      'Tu taxi llegó',
      'Verifica la placa y el conductor antes de subir.',
      Icons.location_on_rounded,
      Color(0xFF047857),
      1,
    ),
    'in_progress' => const TripStatusPresentation(
      'Viaje en curso',
      'Sigue el recorrido hacia tu destino en el mapa.',
      Icons.route_rounded,
      Color(0xFF1D4ED8),
      2,
    ),
    'completed' => const TripStatusPresentation(
      'Llegaste a tu destino',
      'Tu viaje finalizó. Gracias por viajar con Rápigo.',
      Icons.check_circle_rounded,
      Color(0xFF047857),
      3,
    ),
    'cancelled' => const TripStatusPresentation(
      'Viaje cancelado',
      'La solicitud terminó. Puedes iniciar un nuevo viaje.',
      Icons.cancel_outlined,
      Color(0xFFB45309),
      -1,
    ),
    _ => const TripStatusPresentation(
      'Prepara tu viaje',
      'Revisa el destino y la oferta antes de solicitar.',
      Icons.map_outlined,
      Color(0xFF1D4ED8),
      -1,
    ),
  };
}

class TripStatusBanner extends StatelessWidget {
  const TripStatusBanner({
    super.key,
    required this.status,
    this.showProgress = true,
  });
  final String status;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final visual = TripStatusPresentation.fromStatus(status);
    return Semantics(
      liveRegion: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8EBF2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      key: ValueKey(status),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: visual.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(visual.icon, color: visual.color, size: 25),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visual.title,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          visual.message,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showProgress && visual.step >= 0) ...[
                const SizedBox(height: 16),
                Row(
                  children: List.generate(
                    4,
                    (index) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 3 ? 0 : 5),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: index <= visual.step
                                ? visual.color
                                : const Color(0xFFE8EBF2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final label in const [
                      'Solicitud',
                      'Recogida',
                      'Viaje',
                      'Llegada',
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
