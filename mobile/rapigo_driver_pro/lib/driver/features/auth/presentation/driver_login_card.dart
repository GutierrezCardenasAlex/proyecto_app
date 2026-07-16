import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/top_notice.dart';
import '../data/auth_repository.dart';
import '../domain/driver_session.dart';

enum _DriverAuthMode { login, register }

class DriverLoginCard extends ConsumerStatefulWidget {
  const DriverLoginCard({super.key});

  @override
  ConsumerState<DriverLoginCard> createState() => _DriverLoginCardState();
}

class _DriverLoginCardState extends ConsumerState<DriverLoginCard> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerFirstNameController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List<FocusNode>.generate(
    6,
    (_) => FocusNode(),
  );

  _DriverAuthMode _mode = _DriverAuthMode.login;
  bool _rememberSession = true;
  bool _showLoginPassword = false;
  bool _showRegisterPassword = false;
  String? _fallbackOtpCode;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _registerFirstNameController.dispose();
    _registerPasswordController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+591$digits';
  }

  String? _validatePhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) {
      return 'El numero debe tener 8 digitos.';
    }
    return null;
  }

  String? _validatePassword(String password) {
    final valid = RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
    ).hasMatch(password.trim());
    if (!valid) {
      return 'La contrasena debe tener al menos 8 caracteres, una letra y un numero.';
    }
    return null;
  }

  String? _validateRealName(String value) {
    final text = value.trim();
    final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}').hasMatch(text);
    final isGeneric = RegExp(
      r'^(conductor|conductora|driver|chofer|taxista|usuario|user|test|prueba)$',
      caseSensitive: false,
    ).hasMatch(text);
    if (text.length < 2 || !hasLetters || isGeneric) {
      return 'Ingresa tu nombre real para continuar.';
    }
    return null;
  }

  String get _otpValue =>
      _otpControllers.map((controller) => controller.text).join();

  void _showInlineError(String message) {
    showTopNotice(context, message, tone: NoticeTone.error);
  }

  void _showSuccess(String message) {
    showTopNotice(context, message, tone: NoticeTone.success);
  }

  void _clearOtp() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
  }

  void _fillOtp(String code) {
    for (var index = 0; index < _otpControllers.length; index++) {
      _otpControllers[index].text = index < code.length ? code[index] : '';
    }
  }

  void _applyOtpFallback(DriverOtpRequestResult result) {
    if (!mounted) {
      return;
    }
    if (!result.smsDelivered && (result.otp?.isNotEmpty ?? false)) {
      setState(() => _fallbackOtpCode = result.otp);
      _fillOtp(result.otp!);
      showTopNotice(
        context,
        'No pudimos enviar SMS. Usaremos el codigo de respaldo ${result.otp}.',
        tone: NoticeTone.warning,
      );
      return;
    }
    setState(() => _fallbackOtpCode = null);
    _showSuccess('Codigo enviado correctamente al celular del conductor.');
  }

  Future<void> _requestRegisterOtp() async {
    final phoneError = _validatePhone();
    if (phoneError != null) {
      _showInlineError(phoneError);
      return;
    }
    final nameError = _validateRealName(_registerFirstNameController.text);
    if (nameError != null) {
      _showInlineError(nameError);
      return;
    }

    final result = await ref
        .read(driverSessionProvider.notifier)
        .requestRegistrationOtp(
          _normalizedPhone(),
          _registerFirstNameController.text.trim(),
        );
    if (!mounted) {
      return;
    }
    final session = ref.read(driverSessionProvider);
    if (session.errorMessage == null &&
        session.otpRequested &&
        result != null) {
      _applyOtpFallback(result);
    }
  }

  Future<void> _submitLogin() async {
    final phoneError = _validatePhone();
    if (phoneError != null) {
      _showInlineError(phoneError);
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showInlineError('Ingresa tu contrasena.');
      return;
    }

    await ref
        .read(driverSessionProvider.notifier)
        .login(_normalizedPhone(), _passwordController.text.trim());
    if (!mounted) {
      return;
    }
    final session = ref.read(driverSessionProvider);
    if (session.loggedIn && session.errorMessage == null) {
      _showSuccess('Inicio de sesion completado.');
    }
  }

  Future<void> _submitRegister() async {
    if (_otpValue.length != 6) {
      _showInlineError('Completa el codigo de 6 digitos.');
      return;
    }
    final passwordError = _validatePassword(_registerPasswordController.text);
    if (passwordError != null) {
      _showInlineError(passwordError);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          'Confirmar registro',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1746B5),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Estas seguro de registrar el numero ${_normalizedPhone()}? Este numero se guardara para continuar con tus datos personales.',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF42517F),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF6C311),
              foregroundColor: Colors.black,
            ),
            child: const Text('Si, registrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await ref
        .read(driverSessionProvider.notifier)
        .completeRegistration(
          _otpValue,
          _registerPasswordController.text.trim(),
        );
    if (!mounted) {
      return;
    }
    final session = ref.read(driverSessionProvider);
    if (session.loggedIn && session.errorMessage == null) {
      _showSuccess('Cuenta creada. Continua con tu registro de conductor.');
    }
  }

  Future<void> _showResetPasswordDialog() async {
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
                      'Solicita un codigo OTP y luego define una nueva contrasena.',
                    ),
                    const SizedBox(height: 16),
                    _PhoneInputField(controller: _phoneController),
                    if (otpRequested) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otpController,
                        cursorColor: const Color(0xFF1650D7),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1D2D59),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(labelText: 'OTP'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPasswordController,
                        obscureText: true,
                        cursorColor: const Color(0xFF1650D7),
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1D2D59),
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Nueva contrasena',
                        ),
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
                        final result = await ref
                            .read(authRepositoryProvider)
                            .requestPasswordResetOtp(_normalizedPhone());
                        if (!context.mounted) {
                          return;
                        }
                        setDialogState(() => otpRequested = true);
                        if (!result.smsDelivered &&
                            (result.otp?.isNotEmpty ?? false)) {
                          otpController.text = result.otp!;
                          showTopNotice(
                            context,
                            'No pudimos enviar SMS, usa el codigo ${result.otp}.',
                            tone: NoticeTone.warning,
                          );
                        } else {
                          _showSuccess(
                            'OTP enviado para recuperar la contrasena.',
                          );
                        }
                      },
                      child: const Text('Enviar OTP'),
                    )
                  else
                    FilledButton(
                      onPressed: () async {
                        final passwordError = _validatePassword(
                          newPasswordController.text,
                        );
                        if (passwordError != null) {
                          _showInlineError(passwordError);
                          return;
                        }
                        await ref
                            .read(authRepositoryProvider)
                            .resetPassword(
                              phone: _normalizedPhone(),
                              otp: otpController.text.trim(),
                              password: newPasswordController.text.trim(),
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                        _showSuccess(
                          'Contrasena actualizada. Ya puedes ingresar.',
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
    final showRegisterOtp =
        _mode == _DriverAuthMode.register && session.otpRequested;

    return Material(
      color: const Color(0xFFF7FAFF),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/rapigo_driver_icon.png',
                          width: 44,
                          height: 44,
                        ),
                        const SizedBox(width: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'RAPIGO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1746B5),
                                ),
                              ),
                              TextSpan(
                                text: ' PRO',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF6BE00),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'CONDUCTOR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: const Color(0xFF7B86B2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _mode == _DriverAuthMode.login
                    ? _buildLogin(session)
                    : _buildRegister(session, showRegisterOtp: showRegisterOtp),
              ),
              if (session.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE1DE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    session.errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF9B1C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogin(DriverSession session) {
    return Column(
      key: const ValueKey('driver-login-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenido de nuevo',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1746B5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa para comenzar a recibir viajes.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6C789F),
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel('Numero de celular'),
        const SizedBox(height: 10),
        _PhoneInputField(controller: _phoneController),
        const SizedBox(height: 14),
        _SectionLabel('Contrasena'),
        const SizedBox(height: 10),
        _PasswordInputField(
          controller: _passwordController,
          hintText: 'Ingresa tu contrasena',
          obscureText: !_showLoginPassword,
          suffixLabel: _showLoginPassword ? 'Ocultar' : 'Mostrar',
          onSuffixTap: () =>
              setState(() => _showLoginPassword = !_showLoginPassword),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberSession = !_rememberSession),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D3F3)),
                  color: _rememberSession
                      ? const Color(0xFFE8F0FF)
                      : Colors.white,
                ),
                child: _rememberSession
                    ? const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF1746B5),
                        size: 18,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recordar sesion',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF42517F),
                ),
              ),
            ),
            TextButton(
              onPressed: _showResetPasswordDialog,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '¿Olvidaste tu contrasena?',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1746B5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PrimaryYellowButton(
          label: session.isLoading ? 'INICIANDO...' : 'INICIAR SESION',
          onPressed: session.isLoading ? null : _submitLogin,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFDCE4F8))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'o',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8F9AC0),
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFDCE4F8))),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              Text(
                '¿Aun no tienes cuenta?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF54648F),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref
                      .read(driverSessionProvider.notifier)
                      .cancelRegistrationOtp();
                  _clearOtp();
                  setState(() {
                    _mode = _DriverAuthMode.register;
                    _fallbackOtpCode = null;
                  });
                },
                child: Text(
                  'Registrarme como conductor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1746B5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3F7FF), Color(0xFF123EAF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(40),
              bottom: Radius.circular(22),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 34),
              Text(
                'Tu tiempo, tu viaje, tu libertad.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Con ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'Rapigo Pro',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF6D130),
                      ),
                    ),
                    TextSpan(
                      text: ', tu decides.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegister(
    DriverSession session, {
    required bool showRegisterOtp,
  }) {
    final currentStep = showRegisterOtp ? 2 : 1;
    return Column(
      key: ValueKey('driver-register-view-$currentStep'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: showRegisterOtp
                  ? () {
                      ref
                          .read(driverSessionProvider.notifier)
                          .cancelRegistrationOtp();
                      _clearOtp();
                      setState(() => _fallbackOtpCode = null);
                    }
                  : () => setState(() => _mode = _DriverAuthMode.login),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF1746B5),
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
        const SizedBox(height: 4),
        _RegisterStepper(currentStep: currentStep),
        const SizedBox(height: 18),
        if (!showRegisterOtp) ...[
          _SectionLabel('Nombre real'),
          const SizedBox(height: 10),
          _NameInputField(controller: _registerFirstNameController),
          const SizedBox(height: 16),
          _SectionLabel('Numero de celular'),
          const SizedBox(height: 10),
          _PhoneInputField(controller: _phoneController),
          const SizedBox(height: 16),
          _PrimaryYellowButton(
            label: session.isLoading ? 'CONTINUANDO...' : 'CONTINUAR',
            onPressed: session.isLoading ? null : _requestRegisterOtp,
          ),
          const SizedBox(height: 14),
          _MutedInfoRow(
            icon: Icons.shield_outlined,
            text:
                'Al continuar aceptas los terminos y condiciones de RAPIGO PRO.',
          ),
        ] else ...[
          Text(
            'Verifica tu',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1746B5),
            ),
          ),
          Text(
            'celular',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF6BE00),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Te enviamos un codigo de 6 digitos por SMS al numero:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6C789F),
            ),
          ),
          const SizedBox(height: 14),
          _DestinationPreviewCard(
            phone: _normalizedPhone(),
            onChangePhone: () {
              ref.read(driverSessionProvider.notifier).cancelRegistrationOtp();
              _clearOtp();
              setState(() => _fallbackOtpCode = null);
            },
          ),
          const SizedBox(height: 18),
          _SectionLabel('Ingresa el codigo de 6 digitos'),
          const SizedBox(height: 10),
          Row(
            children: List<Widget>.generate(
              6,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 5 ? 0 : 10),
                  child: _OtpDigitField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_fallbackOtpCode != null)
            _DevelopmentTag(
              title: 'Codigo alterno cargado',
              message:
                  'Estamos usando el codigo de respaldo $_fallbackOtpCode mientras integramos el SMS final.',
            ),
          const SizedBox(height: 10),
          _SectionLabel('Crea tu contrasena'),
          const SizedBox(height: 10),
          _PasswordInputField(
            controller: _registerPasswordController,
            hintText: 'Ingresa tu contrasena',
            obscureText: !_showRegisterPassword,
            suffixLabel: _showRegisterPassword ? 'Ocultar' : 'Mostrar',
            onSuffixTap: () =>
                setState(() => _showRegisterPassword = !_showRegisterPassword),
          ),
          const SizedBox(height: 12),
          _RegisterPasswordRulesCard(controller: _registerPasswordController),
          const SizedBox(height: 16),
          _PrimaryYellowButton(
            label: session.isLoading ? 'VERIFICANDO...' : 'VERIFICAR',
            onPressed: session.isLoading ? null : _submitRegister,
          ),
        ],
      ],
    );
  }
}

class _RegisterStepper extends StatelessWidget {
  const _RegisterStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Celular', 'Verificacion', 'Contrasena', 'Datos'];
    return Row(
      children: List<Widget>.generate(labels.length, (index) {
        final step = index + 1;
        final isActive = step <= currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF1650D7)
                            : Colors.white,
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF1650D7)
                              : const Color(0xFFD3DBF3),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isActive
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            )
                          : Text(
                              '$step',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF98A3C7),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? const Color(0xFF1746B5)
                            : const Color(0xFF98A3C7),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: step < currentStep
                        ? const Color(0xFF1650D7)
                        : const Color(0xFFD3DBF3),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DestinationPreviewCard extends StatelessWidget {
  const _DestinationPreviewCard({
    required this.phone,
    required this.onChangePhone,
  });

  final String phone;
  final VoidCallback onChangePhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.sms_rounded,
              color: Color(0xFF1650D7),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1746B5),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onChangePhone,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF1650D7),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text(
                      'Cambiar numero',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1746B5),
      ),
    );
  }
}

class _PhoneInputField extends StatelessWidget {
  const _PhoneInputField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08123EAF),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Text(
            '+591',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2D59),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFD7DDF1),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              cursorColor: const Color(0xFF1650D7),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2D59),
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                hintText: '7XX XXX XX',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFFA2ACC8),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(
              Icons.phone_in_talk_outlined,
              color: Color(0xFF1650D7),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameInputField extends StatelessWidget {
  const _NameInputField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F8)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.person_outline_rounded, color: Color(0xFF1746B5)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              cursorColor: const Color(0xFF1746B5),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D2D59),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Ej. Juan',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF95A1BD),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _PasswordInputField extends StatelessWidget {
  const _PasswordInputField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.suffixLabel,
    required this.onSuffixTap,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final String suffixLabel;
  final VoidCallback onSuffixTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08123EAF),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.lock_outline_rounded,
            color: Color(0xFF1650D7),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              cursorColor: const Color(0xFF1650D7),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2D59),
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFFA2ACC8),
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSuffixTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      color: Color(0xFF1650D7),
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      suffixLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1650D7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpDigitField extends StatelessWidget {
  const _OtpDigitField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E9F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08123EAF),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        cursorColor: const Color(0xFF1650D7),
        decoration: const InputDecoration(
          isCollapsed: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1746B5),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _RegisterPasswordRulesCard extends StatelessWidget {
  const _RegisterPasswordRulesCard({required this.controller});

  final TextEditingController controller;

  bool _hasMin(String value) => value.length >= 8;
  bool _hasLetter(String value) => RegExp(r'[A-Za-z]').hasMatch(value);
  bool _hasNumber(String value) => RegExp(r'\d').hasMatch(value);
  bool _hasNoSpaces(String value) => !RegExp(r'\s').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        final rules = [
          ('Minimo 8 caracteres', _hasMin(password)),
          ('Al menos una letra', _hasLetter(password)),
          ('Al menos un numero', _hasNumber(password)),
          ('Sin espacios', _hasNoSpaces(password)),
        ];
        final valid = rules.every((rule) => rule.$2);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: valid ? const Color(0xFFEFFBF4) : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: valid ? const Color(0xFFBBF7D0) : const Color(0xFFE2E9F8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valid ? 'Contrasena correcta' : 'A la contrasena le falta:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: valid
                      ? const Color(0xFF15803D)
                      : const Color(0xFF1650D7),
                ),
              ),
              const SizedBox(height: 8),
              for (final rule in rules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        rule.$2 ? Icons.check_circle : Icons.cancel_outlined,
                        color: rule.$2
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rule.$1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF405079),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryYellowButton extends StatelessWidget {
  const _PrimaryYellowButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: const Color(0xFFF6C311),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _MutedInfoRow extends StatelessWidget {
  const _MutedInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1650D7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6C789F),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevelopmentTag extends StatelessWidget {
  const _DevelopmentTag({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF6D873)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9D7400),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8C6A08),
            ),
          ),
        ],
      ),
    );
  }
}
