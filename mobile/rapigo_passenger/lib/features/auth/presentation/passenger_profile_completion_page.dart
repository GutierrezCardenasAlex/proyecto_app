import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
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
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 30,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F6CBD), Color(0xFF38BDF8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Completa tu perfil',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu celular ya esta verificado. Ahora guardemos tus datos para mostrar tu nombre en la cuenta y mejorar la asistencia.',
                      style: TextStyle(
                        color: AppBrand.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppBrand.surfaceSoft,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.verified_user_rounded, color: AppBrand.primaryBlue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Paso 1 de 1. Confirma tus datos basicos y entra a la experiencia completa de RAPIGO.',
                              style: TextStyle(
                                color: AppBrand.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Field(label: 'Nombre', controller: _firstNameController),
                    const SizedBox(height: 14),
                    _Field(label: 'Apellido', controller: _lastNameController),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Correo electronico',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      label: 'Direccion o referencia',
                      controller: _addressController,
                      maxLines: 2,
                    ),
                    if (session.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          session.errorMessage!,
                          style: const TextStyle(
                            color: AppBrand.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: session.isLoading
                          ? null
                          : () async {
                              final error = _validateFields();
                              if (error != null) {
                                showTopNotice(context, error, tone: NoticeTone.error);
                                return;
                              }
                              await ref.read(sessionProvider.notifier).completeProfile(
                                    firstName: _firstNameController.text.trim(),
                                    lastName: _lastNameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    address: _addressController.text.trim(),
                                  );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: AppBrand.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(session.isLoading ? 'Guardando...' : 'Guardar y continuar'),
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
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppBrand.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppBrand.surfaceSoft,
            hintText: label,
          ),
        ),
      ],
    );
  }
}
