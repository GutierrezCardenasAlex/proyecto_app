import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/ui/top_notice.dart';
import '../../../auth/data/auth_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _nameController = TextEditingController(text: session.fullName);
    _phoneController = TextEditingController(text: session.phone);
    _emailController = TextEditingController(text: session.email);
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2C2C31)),
            ),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A31),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.person, size: 42, color: Color(0xFFFFF4EC)),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Nombre completo'),
                const SizedBox(height: 8),
                _SettingsField(controller: _nameController, icon: Icons.badge_outlined),
                const SizedBox(height: 16),
                const _FieldLabel('Telefono'),
                const SizedBox(height: 8),
                _SettingsField(controller: _phoneController, icon: Icons.phone_outlined),
                const SizedBox(height: 16),
                const _FieldLabel('Correo'),
                const SizedBox(height: 8),
                _SettingsField(controller: _emailController, icon: Icons.mail_outline),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      showTopNotice(
                        context,
                        'Actualizaste tus datos visuales correctamente.',
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: const Color(0xFF0F0F10),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
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
        ('Promociones', 'Controla cupones, descuentos y campanas activas.'),
        ('Novedades', 'Avisos de mantenimiento o nuevas funciones en Taxi Ya.'),
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
        ('Efectivo', 'Configura como quieres manejar viajes en efectivo.'),
        ('Tarjetas', 'Visualiza las tarjetas o cuentas que quieras registrar.'),
        ('Comprobantes', 'Revisa tus movimientos y pagos recientes.'),
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
      eyebrow: 'Promos',
      items: [
        ('Cupones', 'Consulta descuentos activos para tus proximos viajes.'),
        ('Beneficios', 'Revisa ventajas especiales para clientes frecuentes.'),
        ('Invitaciones', 'Comparte la app y desbloquea nuevas promociones.'),
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
      title: 'Centro de ayuda',
      eyebrow: 'Ayuda',
      items: [
        ('Soporte', 'Contacta a soporte para resolver dudas o reportar un problema.'),
        ('Viajes', 'Consulta informacion sobre pedidos, estados y cobros.'),
        ('Cuenta', 'Recibe ayuda con acceso, perfil y seguridad.'),
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFF4EC),
            ),
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C31)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A31),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: Color(0xFFF97316)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFFFFF4EC),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: Color(0xFFFFC89B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
      backgroundColor: const Color(0xFF111214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111214),
        foregroundColor: const Color(0xFFFFF4EC),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFF4EC),
          ),
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
        text,
        style: const TextStyle(
          color: Color(0xFFFFC89B),
          fontWeight: FontWeight.w800,
          fontSize: 12,
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
        prefixIcon: Icon(icon, color: const Color(0xFFFFC89B)),
        filled: true,
        fillColor: const Color(0xFF25252B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF303035)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
        ),
      ),
      style: const TextStyle(color: Color(0xFFFFF4EC)),
    );
  }
}
