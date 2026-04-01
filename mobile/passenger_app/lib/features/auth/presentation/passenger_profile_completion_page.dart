import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
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
                    _Field(label: 'Nombre', controller: _firstNameController),
                    const SizedBox(height: 16),
                    _Field(label: 'Apellido', controller: _lastNameController),
                    const SizedBox(height: 16),
                    _Field(label: 'Correo', controller: _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
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
                            : () => ref.read(sessionProvider.notifier).completeProfile(
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  address: _addressController.text.trim(),
                                ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          backgroundColor: const Color(0xFF006875),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
