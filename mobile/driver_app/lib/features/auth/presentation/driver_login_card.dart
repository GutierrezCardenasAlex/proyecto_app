import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/auth_repository.dart';

class DriverLoginCard extends ConsumerStatefulWidget {
  const DriverLoginCard({super.key});

  @override
  ConsumerState<DriverLoginCard> createState() => _DriverLoginCardState();
}

class _DriverLoginCardState extends ConsumerState<DriverLoginCard> {
  final _nameController = TextEditingController(text: 'Conductor Demo');
  final _phoneController = TextEditingController(text: '+591 71111111');
  final _otpController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);
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
            'Taxi Ya Driver',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF006875),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bienvenido conductor',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF000003),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inicia sesion para activar disponibilidad, recibir viajes y compartir tu ubicacion.',
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
              hintText: 'Ej. Juan Choque',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 18),
            _LabelText('Telefono'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _phoneController,
              hintText: 'Ej. +591 71111111',
              icon: Icons.phone_outlined,
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
                      'Zona operativa: Potosi, Bolivia',
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
                    : () => ref.read(driverSessionProvider.notifier).requestOtp(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ] else ...[
            _LabelText('Codigo OTP'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _otpController,
              hintText: '123456',
              icon: Icons.password_rounded,
            ),
            const SizedBox(height: 14),
            Text(
              'Te enviamos un codigo al ${session.phone}',
              style: const TextStyle(
                color: Color(0xFF47464B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () => ref.read(driverSessionProvider.notifier).verifyOtp(_otpController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E3FD),
                  foregroundColor: const Color(0xFF001F24),
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Verificando...' : 'Entrar al panel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: session.isLoading
                  ? null
                  : () => ref.read(driverSessionProvider.notifier).requestOtp(
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
