import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/auth_repository.dart';

enum _AuthMode { login, register }

class LoginCard extends ConsumerStatefulWidget {
  const LoginCard({super.key});

  @override
  ConsumerState<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<LoginCard> {
  final _firstNameController = TextEditingController(text: 'Maylex');
  final _phoneController = TextEditingController(text: '70000000');
  final _otpController = TextEditingController(text: '123456');
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;

  @override
  void dispose() {
    _firstNameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      return 'El numero debe tener 8 digitos.';
    }
    return null;
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+591$digits';
  }

  String? _validatePassword() {
    final password = _passwordController.text.trim();
    final valid = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(password);
    if (!valid) {
      return 'La contrasena debe tener al menos 8 caracteres, una letra y un numero.';
    }
    return null;
  }

  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final showRegisterOtp = _mode == _AuthMode.register && session.otpRequested;

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
            _mode == _AuthMode.login ? 'Inicia sesion' : 'Crea tu cuenta',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF000003),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _AuthMode.login
                ? 'Ingresa con tu celular y contrasena. Si el equipo esta autorizado, entras directo.'
                : 'Registra tu celular, valida con OTP y crea tu contrasena.',
            style: const TextStyle(
              color: Color(0xFF47464B),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment(value: _AuthMode.login, label: Text('Ingresar')),
              ButtonSegment(value: _AuthMode.register, label: Text('Registrarme')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
              });
            },
          ),
          const SizedBox(height: 26),
          if (_mode == _AuthMode.login) ...[
            _LabelText('Numero de telefono'),
            const SizedBox(height: 8),
            _PhoneField(controller: _phoneController),
            const SizedBox(height: 18),
            _LabelText('Contrasena'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _passwordController,
              hintText: 'Tu contrasena',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () {
                        final phoneError = _validatePhone();
                        if (phoneError != null) {
                          _showInlineError(phoneError);
                          return;
                        }
                        ref.read(sessionProvider.notifier).login(
                              _normalizedPhone(),
                              _passwordController.text.trim(),
                            );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006875),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Ingresando...' : 'Entrar',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
          ] else if (!showRegisterOtp) ...[
            _LabelText('Nombre'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _firstNameController,
              hintText: 'Ej. Maylex',
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 18),
            _LabelText('Celular'),
            const SizedBox(height: 8),
            _PhoneField(controller: _phoneController),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () {
                        final phoneError = _validatePhone();
                        if (phoneError != null) {
                          _showInlineError(phoneError);
                          return;
                        }
                        ref.read(sessionProvider.notifier).requestRegistrationOtp(
                              _normalizedPhone(),
                              _firstNameController.text.trim(),
                            );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF006875),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Enviando...' : 'Enviar OTP',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
          ] else ...[
            _LabelText('Codigo OTP'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _otpController,
              hintText: '123456',
              icon: Icons.sms_outlined,
            ),
            const SizedBox(height: 18),
            _LabelText('Contrasena'),
            const SizedBox(height: 8),
            _StyledField(
              controller: _passwordController,
              hintText: 'Minimo 8 caracteres',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            Text(
              'Se enviara al numero ${_normalizedPhone()}',
              style: const TextStyle(
                color: Color(0xFF47464B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: session.isLoading
                    ? null
                    : () {
                        final passwordError = _validatePassword();
                        if (passwordError != null) {
                          _showInlineError(passwordError);
                          return;
                        }
                        ref.read(sessionProvider.notifier).completeRegistration(
                              _otpController.text.trim(),
                              _passwordController.text.trim(),
                            );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E3FD),
                  foregroundColor: const Color(0xFF001F24),
                  minimumSize: const Size.fromHeight(62),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  elevation: 0,
                ),
                child: Text(
                  session.isLoading ? 'Verificando...' : 'Crear cuenta',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
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
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: '70000000',
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            '+591',
            style: TextStyle(
              color: Color(0xFF000003),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
