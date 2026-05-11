import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/map/offline_map.dart';
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
      ('Novedades', 'Avisos de mantenimiento o nuevas funciones en Flash Go.'),
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

class PromotionsPage extends ConsumerWidget {
  const PromotionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final progress = session.completedTripCount.clamp(0, 5).toInt();
    final hasFreeTrip = session.freeTripCredits > 0;
    final cycleProgress = hasFreeTrip ? 0 : progress;
    final progressValue = cycleProgress / 5.0;
    final nextCycleTarget = hasFreeTrip ? '0/5' : '$cycleProgress/5';

    return _DetailScaffold(
      title: 'Promociones',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          const Text(
            'PROMOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu avance',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFF4EC),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFC2410C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33F97316),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFF4EC)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasFreeTrip ? 'Ya tienes viaje gratis' : 'Te acercas a un viaje gratis',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFF4EC),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasFreeTrip
                                ? 'Tu sexto viaje es gratis y el contador ya se reinicio para el siguiente ciclo.'
                                : 'Cada 5 viajes completados desbloqueas 1 viaje gratis.',
                            style: const TextStyle(
                              color: Color(0xFFFFE3D0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Text(
                        hasFreeTrip ? 'Gratis listo' : nextCycleTarget,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFF4EC),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: hasFreeTrip ? 1 : progressValue,
                            minHeight: 10,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFFF4EC)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hasFreeTrip
                      ? 'Tienes ${session.freeTripCredits} viaje(s) gratis disponible(s) y tu siguiente ciclo comenzo en 0/5.'
                      : 'Te faltan ${5 - cycleProgress} viaje(s) para ganar el proximo gratis.',
                  style: const TextStyle(
                    color: Color(0xFFFFF4EC),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2C31)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen de promocion',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFF4EC),
                  ),
                ),
                const SizedBox(height: 12),
                _PromoMetricRow(label: 'Viajes completados del ciclo actual', value: '$cycleProgress'),
                _PromoMetricRow(label: 'Viajes gratis disponibles', value: '${session.freeTripCredits}'),
                _PromoMetricRow(label: 'Meta actual', value: nextCycleTarget),
                _PromoMetricRow(label: 'Regla del beneficio', value: '5 viajes pagados = 1 gratis'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _SettingsInfoCard(
            title: 'Como funciona',
            subtitle: 'Cada 5 viajes completados desbloqueas 1 viaje gratis para usarlo en tu siguiente pedido.',
          ),
          const _SettingsInfoCard(
            title: 'Uso del viaje premiado',
            subtitle: 'El beneficio es valido solo para el cliente registrado en Flash Go que gano la promocion. El sexto viaje se usa gratis y luego el contador vuelve a cero.',
          ),
          const _SettingsInfoCard(
            title: 'Acompanantes',
            subtitle: 'La promocion no cubre acompanantes. Si viajas con otra persona, el conductor puede realizar el cobro normal correspondiente por ese pasajero adicional.',
          ),
          const _SettingsInfoCard(
            title: 'Notificacion',
            subtitle: 'Cuando consigas el beneficio, Flash Go te avisara automaticamente en la app.',
          ),
        ],
      ),
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
    return _DetailScaffold(
      title: 'Configuraciones',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          const Text(
            'PREFERENCIAS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Color(0xFFF97316),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configuraciones',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFF4EC),
            ),
          ),
          const SizedBox(height: 18),
          const _SettingsInfoCard(
            title: 'Mapa',
            subtitle: 'Ajusta visualizacion y comportamiento del mapa.',
          ),
          const _SettingsInfoCard(
            title: 'Idioma',
            subtitle: 'Personaliza textos y formato de la aplicacion.',
          ),
          const _SettingsInfoCard(
            title: 'Cuenta',
            subtitle: 'Administra tus datos y sesiones activas.',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C31)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mapa offline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Descarga o actualiza Potosi ciudad para seguir usando el mapa cuando la señal baje.',
                    style: TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showOfflineMapSheet(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: const Text('Abrir mapa offline'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

class _SettingsInfoCard extends StatelessWidget {
  const _SettingsInfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
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

class _PromoMetricRow extends StatelessWidget {
  const _PromoMetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFD8BF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFFFF4EC),
              fontWeight: FontWeight.w800,
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
