import 'package:flutter/material.dart';

class DriverCounterOfferDialog extends StatefulWidget {
  const DriverCounterOfferDialog({
    super.key,
    required this.originalFare,
    required this.onSubmit,
  });
  final double originalFare;
  final Future<void> Function(double) onSubmit;

  @override
  State<DriverCounterOfferDialog> createState() =>
      _DriverCounterOfferDialogState();
}

class _DriverCounterOfferDialogState extends State<DriverCounterOfferDialog> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final raw = _controller.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null ||
        !amount.isFinite ||
        amount <= widget.originalFare ||
        amount > 99999999.99 ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) {
      setState(
        () => _error =
            'Ingresa un precio mayor a Bs ${widget.originalFare.toStringAsFixed(2)}, con hasta 2 decimales.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(amount);
      if (mounted) Navigator.of(context).pop();
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
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: const Text('Proponer otro precio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'El pasajero ofrece Bs ${widget.originalFare.toStringAsFixed(2)}. Si acepta tu precio, podrás ir a recogerlo. Si rechaza, el viaje se cancela.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_sending,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Tu contraoferta',
                  prefixText: 'Bs ',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  errorMaxLines: 4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: Text(_sending ? 'Enviando…' : 'Enviar contraoferta'),
          ),
        ],
      ),
    );
  }
}
