import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/auth_repository.dart';

class DriverProfileCompletionPage extends ConsumerStatefulWidget {
  const DriverProfileCompletionPage({super.key});

  @override
  ConsumerState<DriverProfileCompletionPage> createState() => _DriverProfileCompletionPageState();
}

class _DriverProfileCompletionPageState extends ConsumerState<DriverProfileCompletionPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  String _vehicleType = 'taxi';

  @override
  void initState() {
    super.initState();
    final session = ref.read(driverSessionProvider);
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
    _licenseController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
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
                      'Antes de operar necesitamos tus datos personales y del vehiculo.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _Field(label: 'Nombre', controller: _firstNameController),
                    const SizedBox(height: 14),
                    _Field(label: 'Apellido', controller: _lastNameController),
                    const SizedBox(height: 14),
                    _Field(label: 'Correo', controller: _emailController, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _Field(label: 'Direccion', controller: _addressController),
                    const SizedBox(height: 14),
                    _Field(label: 'Licencia', controller: _licenseController),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de vehiculo',
                        filled: true,
                        fillColor: Color(0xFFF3F3F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'taxi', child: Text('Taxi')),
                        DropdownMenuItem(value: 'moto', child: Text('Moto')),
                      ],
                      onChanged: (value) => setState(() => _vehicleType = value ?? 'taxi'),
                    ),
                    const SizedBox(height: 14),
                    _Field(label: 'Placa', controller: _plateController),
                    const SizedBox(height: 14),
                    _Field(label: 'Marca', controller: _brandController),
                    const SizedBox(height: 14),
                    _Field(label: 'Modelo', controller: _modelController),
                    const SizedBox(height: 14),
                    _Field(label: 'Color', controller: _colorController),
                    const SizedBox(height: 14),
                    _Field(label: 'Anio', controller: _yearController, keyboardType: TextInputType.number),
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
                            : () => ref.read(driverSessionProvider.notifier).completeProfile(
                                  firstName: _firstNameController.text.trim(),
                                  lastName: _lastNameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  address: _addressController.text.trim(),
                                  licenseNumber: _licenseController.text.trim(),
                                  vehicleType: _vehicleType,
                                  plate: _plateController.text.trim(),
                                  brand: _brandController.text.trim(),
                                  model: _modelController.text.trim(),
                                  color: _colorController.text.trim(),
                                  year: int.tryParse(_yearController.text.trim()),
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
