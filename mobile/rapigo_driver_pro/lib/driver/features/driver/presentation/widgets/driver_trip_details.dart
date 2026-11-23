import 'package:flutter/material.dart';
import '../../../trip/domain/driver_trip.dart';
import 'driver_home_design.dart';

const _background = Color(0xFF0D1828);
const _muted = Color(0xFFADBBD0);
const _gold = Color(0xFFFFC400);

/// Information only; journey controls belong on the map.
class DriverTripDetailsView extends StatelessWidget {
  const DriverTripDetailsView({
    super.key,
    required this.trip,
    required this.vehicleType,
    required this.onClose,
    this.completed = false,
  });

  final DriverTrip trip;
  final String vehicleType;
  final VoidCallback onClose;
  final bool completed;

  String get _service {
    final type =
        (trip.vehicleType?.trim().isNotEmpty == true
                ? trip.vehicleType!
                : vehicleType)
            .trim();
    return switch (type.toLowerCase()) {
      'taxi' => 'Taxi',
      'moto' || 'mototaxi' => 'Mototaxi',
      '' => 'No especificado',
      _ => type,
    };
  }

  String get _date {
    final date = DateTime.tryParse(trip.requestedAt ?? '')?.toLocal();
    if (date == null) return 'No disponible';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _field(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _muted, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF18283C),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF293B51)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !completed) onClose();
    },
    child: Scaffold(
      backgroundColor: _background,
      appBar: completed
          ? null
          : AppBar(
              backgroundColor: _background,
              foregroundColor: Colors.white,
              leading: BackButton(onPressed: onClose),
              title: const Text('Detalles del viaje'),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (completed) ...[
                    const Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Color(0xFF133C32),
                        child: Icon(
                          Icons.check_rounded,
                          size: 58,
                          color: Color(0xFF66E2B4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '¡Viaje finalizado!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este es el resumen de tu viaje.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _card([
                    const Text(
                      'PRECIO ACORDADO',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bs ${trip.fareAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Pago: ${trip.paymentMethodLabel}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (trip.isPromotional)
                      const Text(
                        'Viaje promocional',
                        style: TextStyle(color: _gold),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _card([
                    const Text(
                      'RECORRIDO',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    DriverRequestRoute(
                      pickup: trip.passengerPickup,
                      destination: trip.destination,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _card([
                    _field(
                      Icons.person_outline,
                      'Pasajero',
                      trip.passengerName?.trim().isNotEmpty == true
                          ? trip.passengerName!
                          : 'Pasajero',
                    ),
                    if (trip.passengerPhone?.trim().isNotEmpty == true)
                      _field(
                        Icons.phone_outlined,
                        'Teléfono',
                        trip.passengerPhone!,
                      ),
                    const Divider(color: Color(0xFF34465E)),
                    _field(
                      Icons.local_taxi_outlined,
                      'Tipo de servicio',
                      _service,
                    ),
                    if (trip.vehicleLabel?.trim().isNotEmpty == true)
                      _field(
                        Icons.directions_car_outlined,
                        'Vehículo de recogida',
                        trip.vehicleLabel!,
                      ),
                    if (trip.vehiclePlate?.trim().isNotEmpty == true)
                      _field(Icons.badge_outlined, 'Placa', trip.vehiclePlate!),
                    if (trip.vehicleColor?.trim().isNotEmpty == true)
                      _field(
                        Icons.palette_outlined,
                        'Color del vehículo',
                        trip.vehicleColor!,
                      ),
                    const Divider(color: Color(0xFF34465E)),
                    _field(
                      Icons.schedule_outlined,
                      'Fecha y hora de solicitud',
                      _date,
                    ),
                    _field(
                      Icons.receipt_long_outlined,
                      'Número de viaje',
                      trip.id,
                    ),
                  ]),
                  if (completed) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _background,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver al inicio'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
