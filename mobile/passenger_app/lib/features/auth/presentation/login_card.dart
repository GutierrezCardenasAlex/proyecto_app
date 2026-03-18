import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/auth_repository.dart';

class LoginCard extends ConsumerStatefulWidget {
  const LoginCard({super.key});

  @override
  ConsumerState<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<LoginCard> {
  final _phoneController = TextEditingController(text: '+591 70000000');
  final _otpController = TextEditingController(text: '123456');

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF17364E), Color(0xFF24577A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2217354E),
              blurRadius: 26,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.phone_android, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingreso por OTP',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Conecta el pasajero directamente con el servidor Taxi Ya en tu red.',
                        style: TextStyle(color: Color(0xFFD8E6F1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'API: ${AppConfig.apiBaseUrl}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Telefono'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: session.isLoading
                  ? null
                  : () => ref.read(sessionProvider.notifier).requestOtp(_phoneController.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF8354),
                foregroundColor: const Color(0xFF112B3C),
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(session.isLoading ? 'Enviando...' : 'Solicitar OTP'),
            ),
            if (session.otpRequested) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Codigo OTP'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: session.isLoading
                    ? null
                    : () => ref.read(sessionProvider.notifier).verifyOtp(_otpController.text),
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(session.isAuthenticated ? 'Autenticado' : 'Verificar OTP'),
              ),
            ],
            if (session.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                session.errorMessage!,
                style: const TextStyle(color: Color(0xFFFFC9B8)),
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
      labelStyle: const TextStyle(color: Color(0xFFD8E6F1)),
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
