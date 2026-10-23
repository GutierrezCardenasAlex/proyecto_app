import 'package:flutter/material.dart';
import '../../domain/driver_offer.dart';

class PassengerDriverOffersDialog extends StatefulWidget {
  const PassengerDriverOffersDialog({
    super.key,
    required this.offers,
    required this.onRespond,
  });
  final List<DriverOffer> offers;
  final Future<void> Function(DriverOffer, bool) onRespond;
  @override
  State<PassengerDriverOffersDialog> createState() =>
      _PassengerDriverOffersDialogState();
}

class _PassengerDriverOffersDialogState
    extends State<PassengerDriverOffersDialog> {
  bool _busy = false;
  String? _error;
  Future<void> _respond(DriverOffer offer, bool accept) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onRespond(offer, accept);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text('Ofertas de conductores (${widget.offers.length})'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Compara y elige. Ignorar una oferta no cancela tu solicitud.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (widget.offers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Esperando ofertas. Tu solicitud sigue abierta.'),
                ),
              for (final offer in widget.offers)
                Card(
                  margin: const EdgeInsets.only(top: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.driverName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            offer.vehicle,
                            offer.color,
                            offer.plate,
                          ].where((v) => v.isNotEmpty).join(' · '),
                        ),
                        if (offer.rating.isNotEmpty)
                          Text('Calificación: ${offer.rating}'),
                        const SizedBox(height: 10),
                        Text(
                          'Bs ${offer.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(offer, false),
                              child: const Text('Ignorar'),
                            ),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(offer, true),
                              child: const Text('Elegir conductor'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(_busy ? 'Guardando…' : 'Seguir esperando'),
        ),
      ],
    ),
  );
}
