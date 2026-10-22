import 'package:flutter/material.dart';
import '../../domain/trip_request.dart';

class TripCompletionDialog extends StatefulWidget {
  const TripCompletionDialog({
    super.key,
    required this.request,
    required this.onRate,
  });
  final TripRequest request;
  final Future<void> Function(int score, String comment) onRate;
  @override
  State<TripCompletionDialog> createState() => _TripCompletionDialogState();
}

class _TripCompletionDialogState extends State<TripCompletionDialog> {
  final _comment = TextEditingController();
  int _score = 5;
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onRate(_score, _comment.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error =
              'No pudimos enviar tu calificación. Puedes reintentar o terminar sin calificar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Column(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF047857),
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Llegaste a tu destino',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                request.destinationAddress,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              if (request.fareAmount != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Bs ${request.fareAmount!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
                Text(
                  request.paymentMethod == 'qr'
                      ? 'Pago por QR'
                      : 'Pago en efectivo',
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                '¿Cómo estuvo tu viaje?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    tooltip: '${index + 1} estrellas',
                    onPressed: _sending
                        ? null
                        : () => setState(() => _score = index + 1),
                    icon: Icon(
                      index < _score
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFB45309),
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                enabled: !_sending,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Comentario opcional',
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C), height: 1.4),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Terminar sin calificar'),
          ),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
            ),
            child: Text(_sending ? 'Enviando…' : 'Calificar y terminar'),
          ),
        ],
      ),
    );
  }
}
