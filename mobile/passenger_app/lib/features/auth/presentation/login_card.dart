import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Passenger Auth', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(sessionProvider.notifier).requestOtp(_phoneController.text),
              child: const Text('Request OTP'),
            ),
            if (session.otpRequested) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'OTP'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.read(sessionProvider.notifier).verifyOtp(_otpController.text),
                child: Text(session.isAuthenticated ? 'Authenticated' : 'Verify OTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
