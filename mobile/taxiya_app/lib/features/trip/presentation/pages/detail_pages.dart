import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/data/auth_repository.dart';
import '../widgets/ui_kit.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final TextEditingController _emailController = TextEditingController(text: 'usuario@taxiya.bo');

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _nameController = TextEditingController(text: session.fullName);
    _phoneController = TextEditingController(text: session.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
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
                  child: const Icon(Icons.person, size: 42),
                ),
                const SizedBox(height: 20),
                _FieldLabel('Nombre completo'),
                const SizedBox(height: 8),
                _SettingsField(controller: _nameController, icon: Icons.badge_outlined),
                const SizedBox(height: 16),
                _FieldLabel('Telefono'),
                const SizedBox(height: 8),
                _SettingsField(controller: _phoneController, icon: Icons.phone_outlined),
                const SizedBox(height: 16),
                _FieldLabel('Correo'),
                const SizedBox(height: 8),
                _SettingsField(controller: _emailController, icon: Icons.mail_outline),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Edicion visual lista. Si quieres, el siguiente paso es persistir estos cambios en backend.')),
                      );
                    },
                    child: const Text('Guardar cambios'),
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

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Notificaciones',
      eyebrow: 'Alertas',
      items: [
        ('Viajes', 'Recibe actualizaciones de asignacion, llegada y finalizacion del taxi.'),
        ('Promociones', 'Controla cupones, descuentos y campañas activas.'),
        ('Novedades', 'Avisos de mantenimiento o nuevas funciones en Taxi Ya.'),
      ],
    );
  }
}

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Seguridad',
      eyebrow: 'Seguridad',
      items: [
        ('Verificacion OTP', 'Tu acceso sigue protegido por codigo OTP al cerrar sesion.'),
        ('Viaje seguro', 'Comparte ruta y revisa datos del conductor antes de subir.'),
        ('Zona operativa', 'La plataforma valida que el servicio se use solo dentro de Potosi.'),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Configuraciones',
      eyebrow: 'Preferencias',
      items: [
        ('Mapa', 'Ajusta visualizacion y comportamiento del mapa.'),
        ('Idioma', 'Personaliza textos y formato de la aplicacion.'),
        ('Cuenta', 'Administra tus datos y sesiones activas.'),
      ],
    );
  }
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Soporte',
      eyebrow: 'Ayuda',
      items: [
        ('Centro de ayuda', 'Respuestas rapidas para pagos, viajes y conductores.'),
        ('Atencion directa', 'Contacta soporte si una solicitud queda atascada.'),
        ('Emergencias', 'Canales de asistencia en incidentes de seguridad.'),
      ],
    );
  }
}

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Metodos de pago',
      eyebrow: 'Pagos',
      items: [
        ('Efectivo', 'Disponible por defecto para viajes dentro de Potosi.'),
        ('Tarjetas', 'Prepara tarjetas para una siguiente etapa del producto.'),
        ('Resumen', 'Consulta cobros y comprobantes recientes.'),
      ],
    );
  }
}

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoPage(
      title: 'Promociones',
      eyebrow: 'Promociones',
      items: [
        ('Cupones', 'Descuentos por primer viaje y campañas activas.'),
        ('Referidos', 'Invita usuarios y gana saldo promocional.'),
        ('Eventos', 'Ofertas especiales para alta demanda o dias festivos.'),
      ],
    );
  }
}

class _SimpleInfoPage extends StatelessWidget {
  const _SimpleInfoPage({
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
      child: PageShell(
        eyebrow: eyebrow,
        title: title,
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SimpleMenuTile(
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: Color(0xFF77767C),
        ),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.controller,
    required this.icon,
  });

  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF3F3F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
