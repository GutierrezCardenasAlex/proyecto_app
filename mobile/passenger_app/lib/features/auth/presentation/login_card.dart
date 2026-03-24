import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/auth_repository.dart';

class LoginCard extends ConsumerStatefulWidget {
  const LoginCard({super.key});

  @override
  ConsumerState<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<LoginCard> {
  final _nameController = TextEditingController(text: 'Maylex');
  final _phoneController = TextEditingController(text: '+591 70000000');
  final _otpController = TextEditingController(text: '123456');

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final showOtp = session.otpRequested;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000003),
            blurRadius: 40,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taxi Ya',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: const Color(0xFF006875),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bienvenido',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF000003),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tus datos para comenzar tu viaje por Potosi.',
            style: TextStyle(
              color: Color(0xFF47464B),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          if (!showOtp) ...[
            _LabelText('Nombre completo'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _nameController,
              hintText: 'Ej. Maylex Flores',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 18),
            _LabelText('Numero de telefono'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _phoneController,
              hintText: 'Ej. +591 70000000',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F5).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_city, size: 20, color: Color(0xFF006875)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ciudad operativa: Potosi, Bolivia',
                      style: TextStyle(
                        color: Color(0xFF47464B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () => ref.read(sessionProvider.notifier).requestOtp(
                          _phoneController.text,
                          _nameController.text,
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006875),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Enviando...' : 'Continuar',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _DividerText('o continua con'),
            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(
                  child: _SecondaryAction(icon: Icons.g_mobiledata_rounded, label: 'Google'),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _SecondaryAction(icon: Icons.apple_rounded, label: 'Apple'),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Codigo OTP',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF000003),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Te enviamos un codigo a ${session.phone}',
              style: const TextStyle(color: Color(0xFF47464B)),
            ),
            const SizedBox(height: 18),
            _LabelText('Codigo'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _otpController,
              hintText: '123456',
              icon: Icons.password_rounded,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () => ref.read(sessionProvider.notifier).verifyOtp(_otpController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E3FD),
                  foregroundColor: const Color(0xFF001F24),
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Verificando...' : 'Ingresar',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: session.isLoading
                  ? null
                  : () => ref.read(sessionProvider.notifier).requestOtp(
                        _phoneController.text,
                        _nameController.text,
                      ),
              child: const Text('Reenviar codigo'),
            ),
          ],
          if (session.errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                session.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFF93000A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Servidor activo',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF77767C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF77767C),
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF77767C)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFF00E3FD), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}

class _DividerText extends StatelessWidget {
  const _DividerText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFC8C5CC))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF77767C),
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFC8C5CC))),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF000003)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
