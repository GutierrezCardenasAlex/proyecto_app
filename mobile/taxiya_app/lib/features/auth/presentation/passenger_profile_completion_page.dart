import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/ui/top_notice.dart';
import '../data/auth_repository.dart';

class PassengerProfileCompletionPage extends ConsumerStatefulWidget {
  const PassengerProfileCompletionPage({super.key});

  @override
  ConsumerState<PassengerProfileCompletionPage> createState() => _PassengerProfileCompletionPageState();
}

class _PassengerProfileCompletionPageState extends ConsumerState<PassengerProfileCompletionPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _firstNameController = TextEditingController(text: session.firstName);
    _lastNameController = TextEditingController(text: session.lastName);
    _emailController = TextEditingController(text: session.email);
    _addressController = TextEditingController(text: session.address);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validateFields() {
    if (_firstNameController.text.trim().isEmpty) {
      return 'El campo nombre no se lleno.';
    }
    if (_lastNameController.text.trim().isEmpty) {
      return 'El campo apellido no se lleno.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000003),
                      blurRadius: 32,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completa tu perfil',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F0F10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu celular ya esta verificado. Ahora guardemos tus datos para mostrar tu nombre en la cuenta.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _GuideLine('Aqui escribe tu nombre real para que aparezca en tu perfil y en soporte.'),
                    const SizedBox(height: 8),
                    _Field(label: 'Nombre', controller: _firstNameController),
                    const SizedBox(height: 16),
                    const _GuideLine('Aqui escribe tu apellido real para completar correctamente tu cuenta.'),
                    const SizedBox(height: 8),
                    _Field(label: 'Apellido', controller: _lastNameController),
                    const SizedBox(height: 16),
                    const _GuideLine('Aqui puedes poner tu correo para contacto y recuperacion futura.'),
                    const SizedBox(height: 8),
                    _Field(label: 'Correo', controller: _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    const _GuideLine('Aqui escribe una direccion de referencia para tener mejor contexto de tu cuenta.'),
                    const SizedBox(height: 8),
                    _Field(label: 'Direccion', controller: _addressController),
                    if (session.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        session.errorMessage!,
                        style: const TextStyle(color: Color(0xFF93000A), fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: session.isLoading
                            ? null
                            : () async {
                                final validationError = _validateFields();
                                if (validationError != null) {
                                  showTopNotice(
                                    context,
                                    validationError,
                                    backgroundColor: const Color(0xFF93000A),
                                    foregroundColor: Colors.white,
                                  );
                                  return;
                                }
                                await ref.read(sessionProvider.notifier).completeProfile(
                                      firstName: _firstNameController.text.trim(),
                                      lastName: _lastNameController.text.trim(),
                                      email: _emailController.text.trim(),
                                      address: _addressController.text.trim(),
                                    );
                                if (!context.mounted) {
                                  return;
                                }
                                final updated = ref.read(sessionProvider);
                                if (updated.errorMessage == null && updated.profileCompleted) {
                                  showTopNotice(
                                    context,
                                    'Actualizaste tus datos correctamente.',
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: const Color(0xFF0F0F10),
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          backgroundColor: const Color(0xFFC2410C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          session.isLoading ? 'Guardando...' : 'Guardar y continuar',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF3F3F5),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine(this.text);

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
