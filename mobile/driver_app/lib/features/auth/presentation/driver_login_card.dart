import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver Access', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 12),
            TextField(controller: _otpController, decoration: const InputDecoration(labelText: 'OTP')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.read(driverSessionProvider.notifier).login(
                    _phoneController.text,
                    _otpController.text,
                  ),
              child: Text(session.loggedIn ? 'Ready to drive' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}
