import 'package:flutter/material.dart';

/// Presentation only: the dashboard owns availability and navigation actions.
class DriverHomeHeader extends StatelessWidget {
  const DriverHomeHeader({
    super.key,
    required this.available,
    this.statusLabel,
    this.updating = false,
    required this.onMenuTap,
    required this.onAvailabilityTap,
  });

  final bool available;
  final String? statusLabel;
  final bool updating;
  final VoidCallback onMenuTap;
  final VoidCallback onAvailabilityTap;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF202938);
    const accent = Color(0xFFFACC15);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Abrir menú del conductor',
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                toggled: available,
                button: true,
                label: available ? 'Desconectarse' : 'Activar disponibilidad',
                child: Tooltip(
                  message: available
                      ? 'Toca para desconectarte'
                      : 'Toca para recibir viajes',
                  child: InkWell(
                    onTap: updating ? null : onAvailabilityTap,
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'RAPIGO PRO',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusLabel ??
                                      (available
                                          ? 'Estás disponible'
                                          : 'Estás desconectado'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
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
                            color: available ? accent : const Color(0xFF94A3B8),
                            size: 44,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
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
