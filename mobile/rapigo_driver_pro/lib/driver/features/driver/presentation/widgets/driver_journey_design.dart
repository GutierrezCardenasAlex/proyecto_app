import 'package:flutter/material.dart';
import '../../../trip/domain/driver_trip.dart';
import 'driver_home_design.dart';

const _bg = Color(0xFF0D1828);
const _muted = Color(0xFFADBBD0);
const _gold = Color(0xFFFFC400);

/// The map must fill the viewport even when the only non-positioned child
/// is a compact header. A loose Stack otherwise shrinks to that header.
class DriverJourneyCanvas extends StatelessWidget {
  const DriverJourneyCanvas({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(fit: StackFit.expand, children: children),
  );
}

String journeyStage(String status) => switch (status) {
  'at_pickup' => 'Pasajero en recogida',
  'in_progress' => 'En viaje al destino',
  'completed' => 'Viaje completado',
  _ => 'En camino a recogida',
};
String journeyAction(String status) => switch (status) {
  'accepted' => 'Ir al punto de recogida',
  'arriving' => 'Llegué a recogida',
  'at_pickup' => 'Pasajero a bordo · Iniciar viaje',
  'in_progress' => 'Llegué al destino · Finalizar',
  _ => 'Continuar',
};
String _passenger(DriverTrip trip) =>
    trip.passengerName?.trim().isNotEmpty == true
    ? trip.passengerName!.trim()
    : 'Pasajero';

class DriverAcceptedView extends StatelessWidget {
  const DriverAcceptedView({
    super.key,
    required this.trip,
    required this.onContinue,
    this.busy = false,
    this.acceptedOriginalFare = false,
  });
  final DriverTrip trip;
  final VoidCallback onContinue;
  final bool busy;
  final bool acceptedOriginalFare;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF133C32),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Icon(
                          Icons.check_rounded,
                          size: 64,
                          color: Color(0xFF66E2B4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    acceptedOriginalFare
                        ? '¡Aceptaste el viaje!'
                        : '¡Tu viaje fue aceptado!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    acceptedOriginalFare
                        ? 'Aceptaste el precio de ${_passenger(trip)}. El viaje ya está confirmado.'
                        : '${_passenger(trip)} aceptó tu oferta. El viaje ya está confirmado.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18283C),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'PRECIO ACORDADO',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Bs ${trip.fareAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Pago: ${trip.paymentMethodLabel}${trip.isPromotional ? ' · Promoción' : ''}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Divider(height: 32, color: Color(0xFF34465E)),
                        Text(
                          _passenger(trip),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        if (trip.passengerPhone?.isNotEmpty == true)
                          Text(
                            trip.passengerPhone!,
                            style: const TextStyle(color: _muted),
                          ),
                        const SizedBox(height: 18),
                        DriverRequestRoute(
                          pickup: trip.passengerPickup,
                          destination: trip.destination,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _bg,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 12,
                      ),
                    ),
                    icon: const Icon(Icons.near_me_rounded),
                    label: Text(busy ? 'Preparando…' : 'Continuar al recojo'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Revisa los datos y continúa cuando estés listo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DriverJourneyHeader extends StatelessWidget {
  const DriverJourneyHeader({
    super.key,
    required this.trip,
    required this.title,
    required this.subtitle,
    required this.distanceLabel,
    required this.pickupStage,
  });
  final DriverTrip trip;
  final String title, subtitle, distanceLabel;
  final bool pickupStage;
  @override
  Widget build(BuildContext context) => Material(
    color: _bg,
    elevation: 4,
    borderRadius: BorderRadius.circular(22),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                pickupStage
                    ? Icons.person_pin_circle_rounded
                    : Icons.flag_rounded,
                color: _gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journeyStage(trip.status),
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color:
                          i <=
                              (trip.status == 'in_progress'
                                  ? 2
                                  : trip.status == 'at_pickup'
                                  ? 1
                                  : 0)
                          ? _gold
                          : const Color(0xFF34465E),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class DriverJourneyPanel extends StatelessWidget {
  const DriverJourneyPanel({
    super.key,
    required this.trip,
    required this.etaLabel,
    required this.distanceLabel,
    required this.detailsExpanded,
    required this.onNavigate,
    required this.onExpand,
    required this.onPrimary,
    required this.onCall,
    required this.onChat,
  });
  final DriverTrip trip;
  final String etaLabel, distanceLabel;
  final bool detailsExpanded;
  final VoidCallback onNavigate, onExpand, onCall, onChat;
  final VoidCallback? onPrimary;
  @override
  Widget build(BuildContext context) => Material(
    color: _bg,
    elevation: 8,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _passenger(trip),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Bs ${trip.fareAmount.toStringAsFixed(2)} · ${trip.paymentMethodLabel}',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: detailsExpanded ? 'Cerrar datos' : 'Datos del viaje',
                onPressed: onExpand,
                icon: Icon(
                  detailsExpanded ? Icons.close_rounded : Icons.tune_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.status == 'at_pickup'
                      ? 'Espera a que el pasajero suba'
                      : '~$etaLabel · $distanceLabel estimados',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Llamar al pasajero',
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined, color: Colors.white),
              ),
              IconButton(
                tooltip: 'Mensaje al pasajero',
                onPressed: onChat,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                ),
              ),
              IconButton(
                tooltip: 'Abrir navegación',
                onPressed: onNavigate,
                icon: const Icon(Icons.navigation_outlined, color: _gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: trip.status == 'in_progress'
                    ? const Color(0xFF66E2B4)
                    : _gold,
                foregroundColor: _bg,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
              ),
              child: Text(
                journeyAction(trip.status),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
