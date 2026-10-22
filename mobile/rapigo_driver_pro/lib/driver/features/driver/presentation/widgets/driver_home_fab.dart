import 'package:flutter/material.dart';

class DriverHomeFab extends StatefulWidget {
  const DriverHomeFab({
    super.key,
    required this.vehicleLabel,
    required this.onCenter,
    required this.onMapMode,
    required this.onOffers,
  });
  final String vehicleLabel;
  final VoidCallback onCenter;
  final VoidCallback onMapMode;
  final VoidCallback onOffers;

  @override
  State<DriverHomeFab> createState() => _DriverHomeFabState();
}

class _DriverHomeFabState extends State<DriverHomeFab> {
  bool _expanded = false;

  Widget _action(String label, IconData icon, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.icon(
        onPressed: () {
          setState(() => _expanded = false);
          action();
        },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0D1828),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _expanded) setState(() => _expanded = false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_expanded) ...[
            _action(
              'Centro del conductor',
              Icons.dashboard_outlined,
              widget.onCenter,
            ),
            _action(
              '${widget.vehicleLabel} · Vista del mapa',
              Icons.layers_outlined,
              widget.onMapMode,
            ),
            _action('Solicitudes', Icons.local_taxi_outlined, widget.onOffers),
          ],
          FloatingActionButton(
            heroTag: 'driver_home_menu',
            tooltip: _expanded ? 'Cerrar accesos' : 'Abrir accesos',
            backgroundColor: const Color(0xFFFFC400),
            foregroundColor: const Color(0xFF0D1828),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: AnimatedRotation(
              turns: _expanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
