import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';

class DriverLoginCard extends ConsumerStatefulWidget {
  const DriverLoginCard({super.key});

  @override
  ConsumerState<DriverLoginCard> createState() => _DriverLoginCardState();
}

class _DriverLoginCardState extends ConsumerState<DriverLoginCard> {
  final _phoneController = TextEditingController(text: '+591 71111111');
  final _otpController = TextEditingController(text: '123456');

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);
    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF102A3B), Color(0xFF1A4A6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22102A3B),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acceso del conductor',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'API: ${AppConfig.apiBaseUrl}',
              style: const TextStyle(color: Color(0xFFD9E5ED)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Telefono'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('OTP'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: session.isLoading
                  ? null
                  : () => ref.read(driverSessionProvider.notifier).login(
                        _phoneController.text,
                        _otpController.text,
                      ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFFEF8354),
                foregroundColor: const Color(0xFF112B3C),
              ),
              child: Text(
                session.loggedIn ? 'Listo para conducir' : (session.isLoading ? 'Conectando...' : 'Ingresar'),
              ),
            ),
            if (session.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                session.errorMessage!,
                style: const TextStyle(color: Color(0xFFFFCAB8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFD9E5ED)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFEF8354), width: 1.4),
      ),
    );
  }
}
