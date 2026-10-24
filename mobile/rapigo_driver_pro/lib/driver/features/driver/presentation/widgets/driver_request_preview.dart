import 'dart:async';

import 'package:flutter/material.dart';
import '../../../trip/domain/driver_trip.dart';
import 'driver_home_design.dart';

const _ink = Color(0xFF0D1828);
const _gold = Color(0xFFFFC400);
const _muted = Color(0xFFADBBD0);

String _name(DriverTrip trip) => trip.passengerName?.trim().isNotEmpty == true
    ? trip.passengerName!.trim()
    : 'Pasajero';

void showDriverRequestInfo(
  BuildContext context,
  DriverTrip trip,
  String pickupSummary,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: _ink,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Datos del viaje',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar datos',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DriverRequestRoute(
              pickup: trip.passengerPickup,
              destination: trip.destination,
            ),
            const SizedBox(height: 16),
            Text(
              _name(trip),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (trip.passengerPhone?.trim().isNotEmpty == true)
              Text(trip.passengerPhone!, style: const TextStyle(color: _muted)),
            const SizedBox(height: 12),
            Text(
              'Pago: ${trip.paymentMethodLabel}',
              style: const TextStyle(color: Colors.white),
            ),
            if (pickupSummary.isNotEmpty)
              Text(pickupSummary, style: const TextStyle(color: _muted)),
            if (trip.isPromotional)
              const Text('Viaje promocional', style: TextStyle(color: _gold)),
            const SizedBox(height: 12),
            const Text(
              'Aceptar confirma el viaje al precio del pasajero. Solo un precio distinto necesita su aprobación.',
              style: TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class DriverRequestPreviewPanel extends StatefulWidget {
  const DriverRequestPreviewPanel({
    super.key,
    required this.trip,
    required this.onReject,
    required this.onPropose,
    required this.onAccept,
    this.pickupSummary = '',
  });
  final DriverTrip trip;
  final VoidCallback onReject, onPropose;
  final FutureOr<void> Function() onAccept;
  final String pickupSummary;

  @override
  State<DriverRequestPreviewPanel> createState() =>
      _DriverRequestPreviewPanelState();
}

class _DriverRequestPreviewPanelState extends State<DriverRequestPreviewPanel> {
  bool _accepting = false;
  String? _acceptError;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() {
      _accepting = true;
      _acceptError = null;
    });
    try {
      await widget.onAccept();
    } catch (error) {
      if (mounted) {
        setState(
          () => _acceptError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final legacyPending = trip.hasPendingCounterOffer;
    final ignored = trip.myOfferStatus == 'ignored';
    return Material(
      color: _ink,
      elevation: 8,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name(trip),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Bs ${trip.fareAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Mostrar datos del viaje',
                  onPressed: () => showDriverRequestInfo(
                    context,
                    trip,
                    widget.pickupSummary,
                  ),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            if (trip.myOfferStatus != null || legacyPending)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  legacyPending || trip.myOfferStatus == 'pending'
                      ? 'Oferta Bs ${(trip.myOfferAmount ?? trip.counterOfferAmount ?? trip.fareAmount).toStringAsFixed(2)} · Esperando respuesta'
                      : ignored
                      ? 'El pasajero ignoró tu oferta'
                      : 'Actualiza tu oferta para este recorrido',
                  style: const TextStyle(color: _gold, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttons = <Widget>[
                  OutlinedButton(
                    onPressed: _accepting ? null : widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(legacyPending ? 'Cancelar' : 'Ignorar'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _accepting ||
                            legacyPending ||
                            ignored ||
                            trip.isPromotional
                        ? null
                        : widget.onPropose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _gold,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Proponer'),
                  ),
                  FilledButton(
                    onPressed: _accepting || legacyPending || ignored
                        ? null
                        : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(_accepting ? 'Aceptando…' : 'Aceptar'),
                  ),
                ];
                final stacked = MediaQuery.textScalerOf(context).scale(14) > 21;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final button in buttons)
                      SizedBox(
                        width: stacked
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 16) / 3,
                        child: button,
                      ),
                  ],
                );
              },
            ),
            if (_accepting)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_acceptError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _acceptError!,
                  semanticsLabel: 'Error al aceptar: $_acceptError',
                  style: const TextStyle(color: Color(0xFFFFB4AB)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DriverRequestPreviewHeader extends StatelessWidget {
  const DriverRequestPreviewHeader({
    super.key,
    required this.trip,
    required this.onBack,
  });
  final DriverTrip trip;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Material(
    color: _ink,
    elevation: 4,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a solicitudes',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'VISTA DE RUTA',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                _RouteLine(
                  label: 'A',
                  text: trip.passengerPickup,
                  color: _gold,
                ),
                const SizedBox(height: 5),
                _RouteLine(
                  label: 'B',
                  text: trip.destination,
                  color: const Color(0xFF55C9FF),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.label,
    required this.text,
    required this.color,
  });
  final String label, text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text.isEmpty ? 'Por confirmar' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class DriverRequestListCard extends StatelessWidget {
  const DriverRequestListCard({
    super.key,
    required this.trip,
    required this.onRoute,
    required this.onReject,
  });
  final DriverTrip trip;
  final VoidCallback onRoute, onReject;
  @override
  Widget build(BuildContext context) => Material(
    color: _ink,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _name(trip),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bs ${trip.fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RouteLine(label: 'A', text: trip.passengerPickup, color: _gold),
          const SizedBox(height: 8),
          _RouteLine(
            label: 'B',
            text: trip.destination,
            color: const Color(0xFF55C9FF),
          ),
          if (trip.myOfferStatus == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tu oferta: Bs ${trip.myOfferAmount?.toStringAsFixed(2)} · En espera',
                style: const TextStyle(color: _muted),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onRoute,
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _ink,
                  ),
                  child: const Text('Ver ruta'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
