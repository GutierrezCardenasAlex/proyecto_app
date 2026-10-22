import 'package:flutter/material.dart';

/// Presentation only: the dashboard owns availability and navigation actions.
class DriverHomeHeader extends StatelessWidget {
  const DriverHomeHeader({
    super.key,
    required this.available,
    required this.onMenuTap,
    required this.onAvailabilityTap,
  });

  final bool available;
  final VoidCallback onMenuTap;
  final VoidCallback onAvailabilityTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = available
        ? const Color(0xFF087F5B)
        : const Color(0xFF526078);
    return Material(
      color: const Color(0xFFFDFEFE),
      elevation: 5,
      shadowColor: const Color(0x260D1828),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Abrir menú del conductor',
                  onPressed: onMenuTap,
                  icon: const Icon(Icons.menu_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F3F7),
                    foregroundColor: const Color(0xFF0D1828),
                    minimumSize: const Size(48, 48),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RAPIGO PRO',
                        style: TextStyle(
                          color: Color(0xFF0D1828),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tu espacio de conductor',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              toggled: available,
              child: InkWell(
                onTap: onAvailabilityTap,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: available
                        ? const Color(0xFFE9F7EF)
                        : const Color(0xFFF0F3F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              available
                                  ? 'Estás disponible'
                                  : 'Estás desconectado',
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              available
                                  ? 'Puedes recibir solicitudes'
                                  : 'Toca para recibir viajes',
                              style: const TextStyle(
                                color: Color(0xFF526078),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        available
                            ? Icons.toggle_on_rounded
                            : Icons.toggle_off_rounded,
                        color: statusColor,
                        size: 38,
                      ),
                    ],
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

class DriverRequestRoute extends StatelessWidget {
  const DriverRequestRoute({
    super.key,
    required this.pickup,
    required this.destination,
  });

  final String pickup;
  final String destination;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stop(
          'RECOGIDA',
          pickup,
          Icons.radio_button_checked,
          const Color(0xFFFFC400),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 32, top: 10, bottom: 10),
          child: Divider(height: 1, color: Color(0xFF29374A)),
        ),
        _stop(
          'DESTINO',
          destination,
          Icons.location_on_outlined,
          const Color(0xFF8EBBFF),
        ),
      ],
    );
  }

  Widget _stop(String label, String address, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address.trim().isEmpty ? 'Ubicación en el mapa' : address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
