import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/ui/top_notice.dart';
import '../data/auth_repository.dart';

enum _AuthMode { login, register }

class LoginCard extends ConsumerStatefulWidget {
  const LoginCard({super.key});

  @override
  ConsumerState<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends ConsumerState<LoginCard> {
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  String? _fallbackOtpCode;

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

  String? _validateName() {
    if (_firstNameController.text.trim().isEmpty) {
      return 'El campo nombre no se lleno.';
    }
    return null;
  }

  String get _currentStepTitle {
    if (_mode == _AuthMode.login) {
      return 'Ingreso rapido';
    }
    return ref.read(sessionProvider).otpRequested ? 'Verifica tu celular' : 'Datos iniciales';
  }

  String get _currentStepMessage {
    if (_mode == _AuthMode.login) {
      return 'Aqui ingresas con tu celular y tu contrasena. Si el equipo ya fue autorizado por la central, entras directo.';
    }
    if (ref.read(sessionProvider).otpRequested) {
      return 'Aqui escribe el codigo que te llego por SMS y luego crea la contrasena con la que entraras la proxima vez.';
    }
    return 'Aqui escribe tu nombre y tu numero real. Con eso te enviaremos un codigo para activar tu cuenta.';
  }

  void _showInlineError(String message) {
    showTopNotice(context, message, tone: NoticeTone.error);
  }

  void _showSuccess(String message) {
    showTopNotice(context, message, tone: NoticeTone.success);
  }

  void _applyOtpFallback(OtpRequestResult result, {required String successMessage}) {
    if (!mounted) {
      return;
    }
    if (!result.smsDelivered && (result.otp?.isNotEmpty ?? false)) {
      setState(() => _fallbackOtpCode = result.otp);
      _otpController.text = result.otp!;
      showTopNotice(
        context,
        'No pudimos enviar SMS, usa el codigo de respaldo ${result.otp}. Ya lo escribimos por ti.',
        tone: NoticeTone.warning,
      );
      return;
    }
    setState(() => _fallbackOtpCode = null);
    _showSuccess(successMessage);
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
                    const Text(
                      'Te enviaremos un OTP al numero registrado y luego podras definir una nueva contrasena.',
                    ),
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
                        final result = await ref.read(authRepositoryProvider).requestPasswordResetOtp(_normalizedPhone());
                        if (!context.mounted) {
                          return;
                        }
                        setDialogState(() => otpRequested = true);
                        if (!result.smsDelivered && (result.otp?.isNotEmpty ?? false)) {
                          otpController.text = result.otp!;
                          showTopNotice(
                            context,
                            'No pudimos enviar SMS, usa el codigo de respaldo ${result.otp}.',
                            tone: NoticeTone.warning,
                          );
                        } else {
                          _showSuccess('OTP enviado para recuperar la contrasena.');
                        }
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
                        navigator.pop();
                        _showSuccess('Contrasena actualizada. Ya puedes ingresar.');
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
    final session = ref.watch(sessionProvider);
    final showRegisterOtp = _mode == _AuthMode.register && session.otpRequested;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAPIGO',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: AppBrand.primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _mode == _AuthMode.login ? 'Inicia sesion' : 'Crea tu cuenta',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppBrand.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _mode == _AuthMode.login
                ? 'Ingresa con tu celular y contrasena. Si el equipo esta autorizado, entras directo.'
                : 'Registra tu celular, valida con OTP y crea tu contrasena.',
            style: const TextStyle(
              color: AppBrand.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          _StepGuideCard(
            title: _currentStepTitle,
            message: _currentStepMessage,
            accent: AppBrand.primaryBlue,
            icon: showRegisterOtp ? Icons.sms_rounded : (_mode == _AuthMode.login ? Icons.login_rounded : Icons.person_add_alt_1_rounded),
          ),
          const SizedBox(height: 20),
          SegmentedButton<_AuthMode>(
            segments: const [
              ButtonSegment(value: _AuthMode.login, label: Text('Ingresar')),
              ButtonSegment(value: _AuthMode.register, label: Text('Registrarme')),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
                _fallbackOtpCode = null;
              });
            },
          ),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _mode == _AuthMode.login
                ? Column(
                    key: const ValueKey('passenger-login'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _LabelText('Numero de telefono'),
                      const SizedBox(height: 8),
                      _PhoneField(
                        controller: _phoneController,
                        helperText: 'Aqui va tu celular real. Solo escribe los 8 digitos.',
                      ),
                      const SizedBox(height: 18),
                      const _LabelText('Contrasena'),
                      const SizedBox(height: 8),
                      const _FieldHint('Aqui va la contrasena con la que entraras siempre desde este equipo.'),
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
                                  await ref.read(sessionProvider.notifier).login(
                                        _normalizedPhone(),
                                        _passwordController.text.trim(),
                                      );
                                  if (!mounted) {
                                    return;
                                  }
                                  final updated = ref.read(sessionProvider);
                                  if (updated.isAuthenticated && updated.errorMessage == null) {
                                    _showSuccess('Acabas de iniciar sesion correctamente.');
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppBrand.primaryBlue,
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
                        key: const ValueKey('passenger-register-start'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LabelText('Nombre'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui escribe como quieres que te reconozcamos en tu perfil.'),
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
                            helperText: 'Te enviaremos un codigo unico por SMS a este numero.',
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
                                      final otpResult = await ref.read(sessionProvider.notifier).requestRegistrationOtp(
                                            _normalizedPhone(),
                                            _firstNameController.text.trim(),
                                          );
                                      if (!mounted) {
                                        return;
                                      }
                                      final updated = ref.read(sessionProvider);
                                      if (updated.otpRequested && updated.errorMessage == null && otpResult != null) {
                                        _applyOtpFallback(
                                          otpResult,
                                          successMessage: 'Te enviamos un codigo de verificacion para continuar.',
                                        );
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppBrand.primaryBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(62),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                elevation: 0,
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
                        key: const ValueKey('passenger-register-otp'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LabelText('Codigo OTP'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui escribe el codigo SMS que te llego a tu celular.'),
                          const SizedBox(height: 8),
                          _StyledField(
                            controller: _otpController,
                            icon: Icons.sms_outlined,
                            helperText: 'Si no llego el mensaje, revisa el numero o vuelve al paso anterior.',
                          ),
                          if (_fallbackOtpCode != null) ...[
                            const SizedBox(height: 12),
                            _OtpFallbackCard(code: _fallbackOtpCode!),
                          ],
                          const SizedBox(height: 18),
                          const _LabelText('Contrasena'),
                          const SizedBox(height: 8),
                          const _FieldHint('Aqui crea tu contrasena. Debe llevar al menos 8 caracteres, una letra y un numero.'),
                          const SizedBox(height: 8),
                          _StyledField(
                            controller: _passwordController,
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Codigo enviado a ${_normalizedPhone()}',
                            style: const TextStyle(
                              color: Color(0xFF47464B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: session.isLoading
                                      ? null
                                      : () {
                                          setState(() => _fallbackOtpCode = null);
                                          ref.read(sessionProvider.notifier).cancelRegistrationOtp();
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
                                          await ref.read(sessionProvider.notifier).completeRegistration(
                                                _otpController.text.trim(),
                                                _passwordController.text.trim(),
                                              );
                                          if (!mounted) {
                                            return;
                                          }
                                          final updated = ref.read(sessionProvider);
                                          if (updated.isAuthenticated && updated.errorMessage == null) {
                                            _showSuccess('Tu cuenta fue creada y el celular quedo verificado.');
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppBrand.primaryBlue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    elevation: 0,
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
              color: AppBrand.textSecondary,
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
        color: AppBrand.textSecondary,
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
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
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
                    color: AppBrand.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppBrand.textSecondary,
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
        color: AppBrand.textSecondary,
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
        prefixIcon: Icon(icon, color: AppBrand.primaryBlue),
        filled: true,
        fillColor: AppBrand.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppBrand.primaryBlue, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        helperText: helperText,
        helperStyle: const TextStyle(color: AppBrand.textSecondary),
      ),
      style: const TextStyle(color: AppBrand.textPrimary),
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
              color: AppBrand.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppBrand.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppBrand.primaryBlue, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        helperText: helperText,
        helperStyle: const TextStyle(color: AppBrand.textSecondary),
      ),
      style: const TextStyle(color: AppBrand.textPrimary),
    );
  }
}

class _OtpFallbackCard extends StatelessWidget {
  const _OtpFallbackCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Codigo de respaldo',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppBrand.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            code,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppBrand.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa este codigo si el SMS no llego. Ya lo dejamos escrito en el campo OTP.',
            style: TextStyle(
              color: AppBrand.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
