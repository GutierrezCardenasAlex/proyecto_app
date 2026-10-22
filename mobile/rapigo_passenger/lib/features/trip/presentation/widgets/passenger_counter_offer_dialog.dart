import 'package:flutter/material.dart';

class PassengerCounterOfferDialog extends StatefulWidget {
  const PassengerCounterOfferDialog({
    super.key,
    required this.originalFare,
    required this.counterFare,
    required this.driverName,
    required this.onRespond,
  });
  final double originalFare;
  final double counterFare;
  final String driverName;
  final Future<void> Function(bool) onRespond;

  @override
  State<PassengerCounterOfferDialog> createState() =>
      _PassengerCounterOfferDialogState();
}

class _PassengerCounterOfferDialogState
    extends State<PassengerCounterOfferDialog> {
  bool _sending = false;
  String? _error;

  Future<void> _respond(bool accept) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onRespond(accept);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('El conductor propone otro precio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.driverName.isEmpty ? 'Tu conductor' : widget.driverName,
            ),
            const SizedBox(height: 16),
            Text('Tu oferta: Bs ${widget.originalFare.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              'Bs ${widget.counterFare.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Si aceptas, este será el precio del viaje y el conductor irá a recogerte. Si rechazas, se cancelará la solicitud.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => _respond(false),
          child: const Text('Rechazar y cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : () => _respond(true),
          child: Text(
            _sending
                ? 'Guardando…'
                : 'Aceptar Bs ${widget.counterFare.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }
}
