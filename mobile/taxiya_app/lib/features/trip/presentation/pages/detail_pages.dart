import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/admin_center/admin_center_repository.dart';
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

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final repository = const AdminCenterRepository();

    return _DetailScaffold(
      title: 'Notificaciones',
      child: FutureBuilder<List<AdminNotificationItem>>(
        future: session.token.isEmpty ? Future.value(const <AdminNotificationItem>[]) : repository.fetchNotifications(session.token),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: CircularProgressIndicator(),
            ));
          }

          final items = snapshot.data ?? const <AdminNotificationItem>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              const Text(
                'BANDEJA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFF97316)),
              ),
              const SizedBox(height: 8),
              Text(
                'Notificaciones',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFF4EC),
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const _SettingsInfoCard(
                  title: 'Sin avisos nuevos',
                  subtitle: 'Cuando central te envie una notificacion o cambie algo importante, aparecera aqui.',
                ),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _NotificationCard(
                    kind: item.kind,
                    title: item.title,
                    message: item.message,
                    createdAt: item.createdAt,
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
    final safeCycleLength = session.promoCycleLength <= 0 ? 5 : session.promoCycleLength;
    final progress = session.promoProgressCount.clamp(0, safeCycleLength).toInt();
    final hasFreeTrip = session.freeTripCredits > 0;
    final promoEnabled = session.promoEnabled;
    final cycleProgress = hasFreeTrip ? 0 : progress;
    final progressValue = safeCycleLength == 0 ? 0.0 : cycleProgress / safeCycleLength;
    final nextCycleTarget = hasFreeTrip ? '0/$safeCycleLength' : '$cycleProgress/$safeCycleLength';
    final totalTrips = session.completedTripCount;

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
                            !promoEnabled
                                ? 'Promocion pausada por central'
                                : hasFreeTrip
                                    ? 'Ya tienes viaje gratis'
                                    : 'Te acercas a un viaje gratis',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFF4EC),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !promoEnabled
                                ? 'La promo esta desactivada por ahora. Tu historial de viajes se sigue guardando normal.'
                                : hasFreeTrip
                                    ? 'Tu viaje gratis ya esta listo y el nuevo ciclo comenzo desde 0/$safeCycleLength.'
                                    : 'Cada $safeCycleLength viajes pagados desbloqueas 1 viaje gratis.',
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
                        !promoEnabled ? 'Pausada' : hasFreeTrip ? 'Gratis listo' : nextCycleTarget,
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
                            value: promoEnabled ? (hasFreeTrip ? 1 : progressValue) : 0,
                            minHeight: 10,
                            backgroundColor: const Color(0x33FFFFFF),
                            valueColor: AlwaysStoppedAnimation(
                              promoEnabled ? const Color(0xFFFFF4EC) : const Color(0xFFFFE3D0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  !promoEnabled
                      ? 'Cuando la central reactive la promo, tu progreso volvera a mostrarse aqui.'
                      : hasFreeTrip
                          ? 'Tienes ${session.freeTripCredits} viaje(s) gratis disponible(s) y tu siguiente ciclo comenzo en 0/$safeCycleLength.'
                          : 'Te faltan ${safeCycleLength - cycleProgress} viaje(s) para ganar el proximo gratis.',
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
                _PromoMetricRow(label: 'Viajes completados en total', value: '$totalTrips'),
                _PromoMetricRow(label: 'Avance del ciclo actual', value: nextCycleTarget),
                _PromoMetricRow(label: 'Viajes gratis disponibles', value: '${session.freeTripCredits}'),
                _PromoMetricRow(label: 'Estado de la promo', value: promoEnabled ? 'Activa' : 'Pausada'),
                _PromoMetricRow(label: 'Regla del beneficio', value: '$safeCycleLength viajes pagados = 1 gratis'),
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
            subtitle: 'El beneficio es valido solo para el cliente registrado en Flash Go que gano la promocion. Cuando usas el viaje gratis, el ciclo vuelve a 0/5 y el conteo total sigue acumulando normal.',
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

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _messageController = TextEditingController();
  String _category = 'Falla de app';
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final repository = const AdminCenterRepository();

    return _DetailScaffold(
      title: 'Soporte',
      child: FutureBuilder<List<SupportReportItem>>(
        future: session.token.isEmpty ? Future.value(const <SupportReportItem>[]) : repository.fetchSupportReports(session.token),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <SupportReportItem>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              const Text(
                'SOPORTE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFFF97316)),
              ),
              const SizedBox(height: 8),
              Text(
                'Reporta un problema',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFF4EC),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C31)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: const Color(0xFF1B1B1F),
                      style: const TextStyle(color: Color(0xFFFFF4EC), fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Tipo de reporte',
                        labelStyle: const TextStyle(color: Color(0xFFFFC89B)),
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
                      items: const [
                        DropdownMenuItem(value: 'Falla de app', child: Text('Falla de app', style: TextStyle(color: Color(0xFFFFF4EC)))),
                        DropdownMenuItem(value: 'Problema con viaje', child: Text('Problema con viaje', style: TextStyle(color: Color(0xFFFFF4EC)))),
                        DropdownMenuItem(value: 'Cuenta o acceso', child: Text('Cuenta o acceso', style: TextStyle(color: Color(0xFFFFF4EC)))),
                        DropdownMenuItem(value: 'Mapa o GPS', child: Text('Mapa o GPS', style: TextStyle(color: Color(0xFFFFF4EC)))),
                      ],
                      onChanged: (value) => setState(() => _category = value ?? 'Falla de app'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      style: const TextStyle(color: Color(0xFFFFF4EC)),
                      decoration: InputDecoration(
                        labelText: 'Cuéntanos qué pasó',
                        hintText: 'Describe la falla, cuándo ocurrió y qué estabas haciendo.',
                        hintStyle: const TextStyle(color: Color(0xFFB9A79A)),
                        labelStyle: const TextStyle(color: Color(0xFFFFC89B)),
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
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending
                            ? null
                            : () async {
                                if (_messageController.text.trim().length < 8) {
                                  showTopNotice(
                                    context,
                                    'Escribe un detalle un poco más completo para soporte.',
                                    backgroundColor: const Color(0xFF93000A),
                                  );
                                  return;
                                }
                                setState(() => _sending = true);
                                try {
                                  await repository.submitSupportReport(
                                    token: session.token,
                                    category: _category,
                                    message: _messageController.text.trim(),
                                  );
                                  _messageController.clear();
                                  if (!context.mounted) return;
                                  setState(() {});
                                  showTopNotice(
                                    context,
                                    'Reporte enviado a central correctamente.',
                                    backgroundColor: const Color(0xFFF97316),
                                    foregroundColor: const Color(0xFF0F0F10),
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  showTopNotice(
                                    context,
                                    error.toString().replaceFirst('Exception: ', ''),
                                    backgroundColor: const Color(0xFF93000A),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _sending = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Enviando...' : 'Enviar reporte'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Tus reportes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFF4EC),
                ),
              ),
              const SizedBox(height: 12),
              if (reports.isEmpty)
                const _SettingsInfoCard(
                  title: 'Aún no enviaste reportes',
                  subtitle: 'Cuando mandes un reporte desde aquí, central podrá verlo con tus datos y darle seguimiento.',
                ),
              ...reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _SettingsInfoCard(
                    title: '${report.category} · ${report.status}',
                    subtitle: '${report.message}\n\n${_formatShortDate(report.createdAt)}',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatShortDate(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) {
    return raw;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String kind;
  final String title;
  final String message;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    final visual = _notificationVisual(kind);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: visual.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: visual.backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(visual.icon, color: visual.accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFF4EC),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: visual.backgroundColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    visual.label,
                    style: TextStyle(
                      color: visual.accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFD8BF),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25252B),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatShortDate(createdAt),
                    style: const TextStyle(
                      color: Color(0xFFFFC89B),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
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

({Color accentColor, Color backgroundColor, Color borderColor, IconData icon, String label}) _notificationVisual(String kind) {
  switch (kind.toLowerCase()) {
    case 'importante':
      return (
        accentColor: const Color(0xFFEF4444),
        backgroundColor: const Color(0x22EF4444),
        borderColor: const Color(0x44EF4444),
        icon: Icons.priority_high_rounded,
        label: 'IMPORTANTE',
      );
    case 'sistema':
      return (
        accentColor: const Color(0xFF38BDF8),
        backgroundColor: const Color(0x2238BDF8),
        borderColor: const Color(0x4438BDF8),
        icon: Icons.settings_suggest_rounded,
        label: 'SISTEMA',
      );
    default:
      return (
        accentColor: const Color(0xFFF97316),
        backgroundColor: const Color(0x33F97316),
        borderColor: const Color(0xFF2C2C31),
        icon: Icons.notifications_active_outlined,
        label: 'NUEVO',
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
