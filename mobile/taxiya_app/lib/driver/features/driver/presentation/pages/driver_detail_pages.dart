import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/data/auth_repository.dart';
import '../widgets/driver_ui_kit.dart';

class DriverProfilePage extends ConsumerStatefulWidget {
  const DriverProfilePage({super.key});

  @override
  ConsumerState<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends ConsumerState<DriverProfilePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _licenseController;
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _colorController;
  late final TextEditingController _yearController;
  String _vehicleType = 'taxi';
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    final session = ref.read(driverSessionProvider);
    _firstNameController = TextEditingController(text: session.firstName);
    _lastNameController = TextEditingController(text: session.lastName);
    _emailController = TextEditingController(text: session.email);
    _addressController = TextEditingController(text: session.address);
    _licenseController = TextEditingController();
    _plateController = TextEditingController();
    _brandController = TextEditingController();
    _modelController = TextEditingController();
    _colorController = TextEditingController();
    _yearController = TextEditingController();
    _vehicleType = session.vehicleType;
    Future<void>.microtask(_loadProfile);
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

  Future<void> _loadProfile() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.token.isEmpty || session.userId.isEmpty) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
      return;
    }

    try {
      final details = await ref.read(authRepositoryProvider).fetchDriverProfile(
            token: session.token,
            userId: session.userId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseController.text = details.licenseNumber;
        _plateController.text = details.plate;
        _brandController.text = details.brand;
        _modelController.text = details.model;
        _colorController.text = details.color;
        _yearController.text = details.year?.toString() ?? '';
        _vehicleType = details.vehicleType.isEmpty ? _vehicleType : details.vehicleType;
        _isFetching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(driverSessionProvider);
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty ||
        _brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _colorController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Completa todos los datos obligatorios del conductor y del vehiculo.')),
      );
      return;
    }

    await ref.read(driverSessionProvider.notifier).completeProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          vehicleType: _vehicleType,
          plate: _plateController.text.trim().toUpperCase(),
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          color: _colorController.text.trim(),
          year: int.tryParse(_yearController.text.trim()),
        );

    if (!mounted) {
      return;
    }

    final updatedSession = ref.read(driverSessionProvider);
    if (updatedSession.errorMessage != null && updatedSession.errorMessage!.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(updatedSession.errorMessage!)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Perfil del conductor actualizado correctamente.')),
    );

    if (updatedSession.vehicleType != _vehicleType) {
      setState(() => _vehicleType = updatedSession.vehicleType);
    }

    if (session.userId == updatedSession.userId) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);

    return _DetailScaffold(
      title: 'Perfil del conductor',
      child: DriverPageShell(
        eyebrow: 'Cuenta',
        title: 'Perfil',
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.person, size: 44),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    session.fullName.isEmpty ? 'Conductor Taxi Ya' : session.fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.phone,
                    style: const TextStyle(
                      color: Color(0xFF47464B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x1A00E3FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'DATOS EDITABLES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Color(0xFF00616D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: _isFetching
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        _ProfileField(label: 'Nombre', controller: _firstNameController),
                        _ProfileField(label: 'Apellido', controller: _lastNameController),
                        _ProfileField(
                          label: 'Correo',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _ProfileField(
                          label: 'Direccion',
                          controller: _addressController,
                          maxLines: 2,
                        ),
                        _ProfileField(label: 'Licencia', controller: _licenseController),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tipo de vehiculo',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF47464B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'taxi',
                              icon: Icon(Icons.directions_car_filled_rounded),
                              label: Text('Taxi'),
                            ),
                            ButtonSegment<String>(
                              value: 'moto',
                              icon: Icon(Icons.two_wheeler_rounded),
                              label: Text('Moto'),
                            ),
                          ],
                          selected: {_vehicleType},
                          onSelectionChanged: (selection) {
                            setState(() => _vehicleType = selection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        _ProfileField(
                          label: 'Placa',
                          controller: _plateController,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        _ProfileField(label: 'Marca', controller: _brandController),
                        _ProfileField(label: 'Modelo', controller: _modelController),
                        _ProfileField(label: 'Color', controller: _colorController),
                        _ProfileField(
                          label: 'Ano',
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: session.isLoading ? null : _saveProfile,
                            icon: session.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(session.isLoading ? 'Guardando...' : 'Guardar cambios'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverSettingsPage extends StatelessWidget {
  const DriverSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Configuraciones',
      eyebrow: 'Preferencias',
      items: [
        ('Navegacion', 'Ajusta el comportamiento del mapa y seguimiento de ruta.'),
        ('Alertas', 'Controla sonido y avisos de nuevos viajes.'),
        ('Cuenta', 'Revisa tus datos, vehiculo y documentos.'),
      ],
    );
  }
}

class DriverSecurityPage extends StatelessWidget {
  const DriverSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Seguridad',
      eyebrow: 'Seguridad',
      items: [
        ('Sesion OTP', 'Tu acceso como conductor se valida con OTP.'),
        ('Ruta segura', 'Comparte tu posicion con panel y pasajero en tiempo real.'),
        ('Cobertura', 'La app valida operacion solo dentro de Potosi.'),
      ],
    );
  }
}

class DriverHelpPage extends StatelessWidget {
  const DriverHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Centro de ayuda',
      eyebrow: 'Ayuda',
      items: [
        ('Soporte', 'Canales de ayuda para incidencias de viajes o pagos.'),
        ('Preguntas frecuentes', 'Respuestas para disponibilidad, GPS y aceptacion.'),
        ('Emergencias', 'Opciones de asistencia en incidentes.'),
      ],
    );
  }
}

class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Ganancias',
      eyebrow: 'Ingresos',
      items: [
        ('Hoy', 'Visualiza viajes completados y efectivo estimado del dia.'),
        ('Semana', 'Resumen semanal de actividad del conductor.'),
        ('Liquidacion', 'Comprobantes y cierres operativos.'),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF7F7F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SimpleDriverPage extends StatelessWidget {
  const _SimpleDriverPage({
    required this.title,
    required this.eyebrow,
    required this.items,
  });

  final String title;
  final String eyebrow;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: title,
      child: DriverPageShell(
        eyebrow: eyebrow,
        title: title,
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DriverMenuTile(
                    icon: Icons.check_circle_outline,
                    title: item.$1,
                    subtitle: item.$2,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: child,
    );
  }
}
