import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/ui/top_notice.dart';
import '../data/auth_repository.dart';

enum _DriverAuthMode { login, register }

class DriverLoginCard extends ConsumerStatefulWidget {
  const DriverLoginCard({super.key});

  @override
  ConsumerState<DriverLoginCard> createState() => _DriverLoginCardState();
}

class _DriverLoginCardState extends ConsumerState<DriverLoginCard> {
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  _DriverAuthMode _mode = _DriverAuthMode.login;

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

  String? _validateName() {
    if (_firstNameController.text.trim().isEmpty) {
      return 'El campo nombre no se lleno.';
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

  String get _currentStepTitle {
    if (_mode == _DriverAuthMode.login) {
      return 'Ingreso de conductor';
    }
    return ref.read(driverSessionProvider).otpRequested ? 'Verifica tu celular' : 'Datos iniciales';
  }

  String get _currentStepMessage {
    if (_mode == _DriverAuthMode.login) {
      return 'Aqui ingresa el conductor con su numero y su contrasena. Si este equipo ya fue aprobado por central, entra sin OTP.';
    }
    if (ref.read(driverSessionProvider).otpRequested) {
      return 'Aqui va el codigo SMS y luego la contrasena que usara el conductor para volver a entrar.';
    }
    return 'Aqui escribe el nombre del conductor y el celular real donde enviaremos el codigo de activacion.';
  }

  void _showInlineError(String message) {
    showTopNotice(
      context,
      message,
      backgroundColor: const Color(0xFF93000A),
      foregroundColor: Colors.white,
    );
  }

  void _showSuccess(String message) {
    showTopNotice(
      context,
      message,
      backgroundColor: const Color(0xFFF97316),
      foregroundColor: const Color(0xFF0F0F10),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final navigator = Navigator.of(context);
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool otpRequested = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Recuperar contrasena'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Solicita un OTP de recuperacion y luego define una nueva contrasena.'),
                    const SizedBox(height: 16),
                    _PhoneField(controller: _phoneController),
                    const SizedBox(height: 12),
                    if (otpRequested) ...[
                      _StyledField(
                        controller: otpController,
                        icon: Icons.sms_outlined,
                      ),
                      const SizedBox(height: 12),
                      _StyledField(
                        controller: newPasswordController,
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  if (!otpRequested)
                    FilledButton(
                      onPressed: () async {
                        final phoneError = _validatePhone();
                        if (phoneError != null) {
                          _showInlineError(phoneError);
                          return;
                        }
                        await ref.read(authRepositoryProvider).requestPasswordResetOtp(_normalizedPhone());
                        if (!context.mounted) {
                          return;
                        }
                        setDialogState(() => otpRequested = true);
                        showTopNotice(
                          context,
                          'OTP enviado para recuperar la contrasena.',
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: const Color(0xFF0F0F10),
                        );
                      },
                      child: const Text('Enviar OTP'),
                    )
                  else
                    FilledButton(
                      onPressed: () async {
                        final password = newPasswordController.text.trim();
                        final valid = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(password);
                        if (!valid) {
                          _showInlineError(
                            'La contrasena debe tener al menos 8 caracteres, una letra y un numero.',
                          );
                          return;
                        }
                        await ref.read(authRepositoryProvider).resetPassword(
                              phone: _normalizedPhone(),
                              otp: otpController.text.trim(),
                              password: password,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        navigator.pop();
                        showTopNotice(
                          context,
                          'Contrasena actualizada. Ya puedes ingresar.',
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: const Color(0xFF0F0F10),
                        );
                      },
                      child: const Text('Actualizar'),
                    ),
                ],
              );
            },
          );
        },
      );
    } finally {
      otpController.dispose();
      newPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);
    final showRegisterOtp = _mode == _DriverAuthMode.register && session.otpRequested;

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
              color: const Color(0xFFC2410C),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _mode == _DriverAuthMode.login ? 'Ingreso de conductor' : 'Registro de conductor',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F0F10),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _DriverAuthMode.login
                ? 'Entra con celular y contrasena. El equipo registrado entra sin volver a pedir OTP.'
                : 'Registra tu numero, valida con OTP y crea tu contrasena para empezar.',
            style: const TextStyle(
              color: Color(0xFF47464B),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          _StepGuideCard(
            title: _currentStepTitle,
            message: _currentStepMessage,
            accent: const Color(0xFFF97316),
            icon: showRegisterOtp ? Icons.sms_rounded : (_mode == _DriverAuthMode.login ? Icons.login_rounded : Icons.badge_rounded),
          ),
          const SizedBox(height: 20),
          SegmentedButton<_DriverAuthMode>(
            segments: const [
              ButtonSegment(value: _DriverAuthMode.login, label: Text('Ingresar')),
              ButtonSegment(value: _DriverAuthMode.register, label: Text('Registrarme')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _mode == _DriverAuthMode.login
                ? Column(
                    key: const ValueKey('driver-login'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LabelText('Celular'),
                      const SizedBox(height: 8),
                      _PhoneField(
                        controller: _phoneController,
                        helperText: 'Aqui escribe el celular real del conductor. Solo van los 8 digitos.',
                      ),
                      const SizedBox(height: 18),
                      const _LabelText('Contrasena'),
                      const SizedBox(height: 8),
                      const _FieldHint('Aqui va la contrasena que el conductor usara siempre para ingresar.'),
                      const SizedBox(height: 8),
                      _StyledField(
                        controller: _passwordController,
                        icon: Icons.lock_outline_rounded,
                        obscureText: true,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: session.isLoading
                              ? null
                              : () async {
                                  final phoneError = _validatePhone();
                                  if (phoneError != null) {
                                    _showInlineError(phoneError);
                                    return;
                                  }
                                  await ref.read(driverSessionProvider.notifier).login(
                                        _normalizedPhone(),
                                        _passwordController.text.trim(),
                                      );
                                  if (!mounted) {
                                    return;
                                  }
                                  final updated = ref.read(driverSessionProvider);
                                  if (updated.loggedIn && updated.errorMessage == null) {
                                    _showSuccess('Acabas de iniciar sesion como conductor.');
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC2410C),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(62),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: Text(
                            session.isLoading ? 'Ingresando...' : 'Entrar al panel',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showResetPasswordDialog,
                          child: const Text('Olvide mi contrasena'),
                        ),
                      ),
                    ],
                  )
                : !showRegisterOtp
                    ? Column(
                        key: const ValueKey('driver-register-start'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LabelText('Nombre'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui escribe el nombre real del conductor tal como debe verse en su perfil.'),
                          const SizedBox(height: 8),
                          _StyledField(
                            controller: _firstNameController,
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 18),
                          const _LabelText('Celular'),
                          const SizedBox(height: 8),
                          _PhoneField(
                            controller: _phoneController,
                            helperText: 'La central y el conductor usaran este numero para verificar acceso.',
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: session.isLoading
                                  ? null
                                  : () async {
                                      final nameError = _validateName();
                                      if (nameError != null) {
                                        _showInlineError(nameError);
                                        return;
                                      }
                                      final phoneError = _validatePhone();
                                      if (phoneError != null) {
                                        _showInlineError(phoneError);
                                        return;
                                      }
                                      await ref.read(driverSessionProvider.notifier).requestRegistrationOtp(
                                            _normalizedPhone(),
                                            _firstNameController.text.trim(),
                                          );
                                      if (!mounted) {
                                        return;
                                      }
                                      final updated = ref.read(driverSessionProvider);
                                      if (updated.otpRequested && updated.errorMessage == null) {
                                        _showSuccess('Te enviamos un codigo SMS para activar al conductor.');
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFC2410C),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(62),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              ),
                              child: Text(
                                session.isLoading ? 'Enviando...' : 'Continuar y enviar OTP',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('driver-register-otp'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LabelText('Codigo OTP'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui escribe el codigo que llego por SMS al celular del conductor.'),
                          const SizedBox(height: 8),
                          _StyledField(
                            controller: _otpController,
                            icon: Icons.sms_outlined,
                            helperText: 'Si no llego el mensaje, revisa el numero o vuelve al paso anterior.',
                          ),
                          const SizedBox(height: 18),
                          const _LabelText('Contrasena'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui crea la contrasena del conductor. Debe llevar una letra y un numero como minimo.'),
                          const SizedBox(height: 8),
                          _StyledField(
                            controller: _passwordController,
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Codigo enviado a ${_normalizedPhone()}',
                            style: const TextStyle(color: Color(0xFF47464B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: session.isLoading
                                      ? null
                                      : () {
                                          ref.read(driverSessionProvider.notifier).cancelRegistrationOtp();
                                        },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('Volver'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  onPressed: session.isLoading
                                      ? null
                                      : () async {
                                          final passwordError = _validatePassword();
                                          if (passwordError != null) {
                                            _showInlineError(passwordError);
                                            return;
                                          }
                                          await ref.read(driverSessionProvider.notifier).completeRegistration(
                                                _otpController.text.trim(),
                                                _passwordController.text.trim(),
                                              );
                                          if (!mounted) {
                                            return;
                                          }
                                          final updated = ref.read(driverSessionProvider);
                                          if (updated.loggedIn && updated.errorMessage == null) {
                                            _showSuccess('El conductor ya quedo registrado y verificado.');
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: const Color(0xFF0F0F10),
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                  ),
                                  child: Text(
                                    session.isLoading ? 'Verificando...' : 'Verificar y crear cuenta',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
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

class _StepGuideCard extends StatelessWidget {
  const _StepGuideCard({
    required this.title,
    required this.message,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String message;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFFC2410C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF0F0F10),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF47464B),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF77767C),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.helperText,
  });

  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF77767C)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.55),
        helperText: helperText,
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
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    this.helperText,
  });

  final TextEditingController controller;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            '+591',
            style: TextStyle(
              color: Color(0xFF0F0F10),
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
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        helperText: helperText,
      ),
    );
  }
}
