import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/admin_center/admin_center_repository.dart';
import '../../../../core/config/app_brand.dart';
import '../widgets/account_ui.dart';
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
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 42,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Nombre completo'),
                const SizedBox(height: 8),
                _SettingsField(
                  controller: _nameController,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Telefono'),
                const SizedBox(height: 8),
                _SettingsField(
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Correo'),
                const SizedBox(height: 8),
                _SettingsField(
                  controller: _emailController,
                  icon: Icons.mail_outline,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      showTopNotice(
                        context,
                        'Actualizaste tus datos visuales correctamente.',
                        backgroundColor: const Color(0xFF0F6CBD),
                        foregroundColor: const Color(0xFFFFFFFF),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6CBD),
                      foregroundColor: const Color(0xFFFFFFFF),
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

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  Future<List<AdminNotificationItem>>? _notifications;
  String? _token;

  Future<void> _reload() async {
    final future = const AdminCenterRepository().fetchNotifications(_token!);
    setState(() => _notifications = future);
    try {
      await future;
    } catch (_) {
      /* Rendered by FutureBuilder. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(sessionProvider).token;
    if (_token != token) {
      _token = token;
      _notifications = token.isEmpty
          ? Future.value(const <AdminNotificationItem>[])
          : const AdminCenterRepository().fetchNotifications(token);
    }
    return _DetailScaffold(
      title: 'Notificaciones',
      child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<AdminNotificationItem>>(
          future: _notifications,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <AdminNotificationItem>[];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const AccountIntro(
                  icon: Icons.notifications_none_rounded,
                  title: 'Todo al día',
                  description:
                      'Los avisos de tus viajes y las novedades de Rápigo, en un solo lugar.',
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  AccountStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'No pudimos cargar tus avisos',
                    description: 'Revisa tu conexión e inténtalo de nuevo.',
                    onRetry: _reload,
                  )
                else if (items.isEmpty)
                  const AccountStateCard(
                    icon: Icons.notifications_off_outlined,
                    title: 'No tienes notificaciones',
                    description:
                        'Cuando recibas un aviso, lo encontrarás aquí.',
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
    // Re-check the flag here as central can disable it while this page is open.
    if (!session.promoEnabled) {
      return const _DetailScaffold(
        title: 'Promociones',
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AccountStateCard(
            icon: Icons.redeem_outlined,
            title: 'No hay promociones activas',
            description:
                'Los beneficios volverán a aparecer cuando estén disponibles.',
          ),
        ),
      );
    }
    final cycle = session.promoCycleLength > 0 ? session.promoCycleLength : 5;
    final progress = session.promoProgressCount.clamp(0, cycle);
    final credits = session.freeTripCredits;
    return _DetailScaffold(
      title: 'Promociones',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const AccountIntro(
            icon: Icons.redeem_rounded,
            title: 'Viajar tiene recompensa',
            description:
                'Consulta tu progreso y los beneficios disponibles para tu cuenta.',
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppBrand.secondaryBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROMOCIÓN ACTIVA',
                  style: TextStyle(
                    color: AppBrand.accentYellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  credits > 0
                      ? '$credits ${credits == 1 ? 'viaje gratis' : 'viajes gratis'}'
                      : '$progress de $cycle viajes',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  credits > 0
                      ? 'Tu beneficio está disponible para tu próximo viaje.'
                      : 'Completa ${cycle - progress} viajes más para alcanzar tu beneficio.',
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: credits > 0 ? 1 : progress / cycle,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: AppBrand.accentYellow,
                  backgroundColor: Colors.white24,
                  semanticsLabel: 'Progreso de promoción',
                  semanticsValue: credits > 0
                      ? 'Beneficio disponible'
                      : '$progress de $cycle',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SettingsInfoCard(
            title: 'Cómo funciona',
            subtitle:
                'Cada $cycle viajes pagados completados desbloqueas un viaje gratis. Tu historial total se conserva.',
          ),
          const SizedBox(height: 12),
          const _SettingsInfoCard(
            title: 'Un beneficio para ti',
            subtitle:
                'El viaje gratis corresponde al titular de la cuenta que obtuvo la promoción. Los acompañantes no están incluidos.',
          ),
          const SizedBox(height: 12),
          const _SettingsInfoCard(
            title: 'Te avisamos cuando esté listo',
            subtitle:
                'Recibirás un aviso en la app cuando alcances tu beneficio.',
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
        (
          'Verificacion OTP',
          'Tu acceso sigue protegido por codigo OTP al cerrar sesion.',
        ),
        (
          'Viaje seguro',
          'Comparte ruta y revisa datos del conductor antes de subir.',
        ),
        (
          'Zona operativa',
          'La plataforma valida que el servicio se use solo dentro de Potosi.',
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: 'Configuración',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const AccountIntro(
          icon: Icons.tune_rounded,
          title: 'Prepara tu próximo viaje',
          description: 'Gestiona los mapas que utilizas en la aplicación.',
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8EBF2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 36,
                color: AppBrand.secondaryBlue,
              ),
              const SizedBox(height: 20),
              Text(
                'Potosí sin conexión',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppBrand.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Descarga el mapa de la ciudad o actualiza tu copia para consultarlo cuando la señal sea débil.',
                style: TextStyle(color: AppBrand.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showOfflineMapSheet(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppBrand.secondaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Gestionar mapa'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SettingsInfoCard(
          title: 'Antes de salir',
          subtitle:
              'Descarga el mapa con conexión a internet. Solicitar viajes y recibir actualizaciones requiere conexión.',
        ),
      ],
    ),
  );
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
  Future<List<SupportReportItem>>? _reports;
  String? _reportsToken;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final repository = const AdminCenterRepository();
    if (_reportsToken != session.token) {
      _reportsToken = session.token;
      _reports = session.token.isEmpty
          ? Future.value(const <SupportReportItem>[])
          : repository.fetchSupportReports(session.token);
    }

    return _DetailScaffold(
      title: 'Soporte',
      child: FutureBuilder<List<SupportReportItem>>(
        future: _reports,
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <SupportReportItem>[];
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const AccountIntro(
                icon: Icons.support_agent_rounded,
                title: 'Estamos para ayudarte',
                description:
                    'Cuéntanos lo ocurrido y consulta el estado de tus reportes aquí.',
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      dropdownColor: const Color(0xFFFFFFFF),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tipo de reporte',
                        labelStyle: const TextStyle(color: Color(0xFF0F6CBD)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F6CBD),
                            width: 1.4,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Falla de app',
                          child: Text(
                            'Falla de app',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Problema con viaje',
                          child: Text(
                            'Problema con viaje',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Cuenta o acceso',
                          child: Text(
                            'Cuenta o acceso',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Mapa o GPS',
                          child: Text(
                            'Mapa o GPS',
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _category = value ?? 'Falla de app'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Cuéntanos qué pasó',
                        hintText:
                            'Describe la falla, cuándo ocurrió y qué estabas haciendo.',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        labelStyle: const TextStyle(color: Color(0xFF0F6CBD)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF0F6CBD),
                            width: 1.4,
                          ),
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
                                    tone: NoticeTone.error,
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
                                  if (!context.mounted) return;
                                  _messageController.clear();
                                  setState(() {
                                    _reports = repository.fetchSupportReports(
                                      session.token,
                                    );
                                  });
                                  showTopNotice(
                                    context,
                                    'Reporte enviado a central correctamente.',
                                    tone: NoticeTone.success,
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  showTopNotice(
                                    context,
                                    error.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                    tone: NoticeTone.error,
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _sending = false);
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppBrand.secondaryBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(
                          _sending ? 'Enviando...' : 'Enviar reporte',
                        ),
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
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                AccountStateCard(
                  icon: Icons.cloud_off_rounded,
                  title: 'No pudimos cargar tus reportes',
                  description:
                      'Puedes reintentar sin perder lo que escribiste.',
                  onRetry: () => setState(() {
                    _reports = repository.fetchSupportReports(session.token);
                  }),
                )
              else if (reports.isEmpty)
                const _SettingsInfoCard(
                  title: 'Aún no enviaste reportes',
                  subtitle:
                      'Cuando mandes un reporte desde aquí, central podrá verlo con tus datos y darle seguimiento.',
                ),
              ...reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _SettingsInfoCard(
                    title: '${report.category} · ${report.status}',
                    subtitle:
                        '${report.message}\n\n${_formatShortDate(report.createdAt)}',
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
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: visual.borderColor),
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
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatShortDate(createdAt),
                    style: const TextStyle(
                      color: Color(0xFF0F6CBD),
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

({
  Color accentColor,
  Color backgroundColor,
  Color borderColor,
  IconData icon,
  String label,
})
_notificationVisual(String kind) {
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
        accentColor: const Color(0xFF0F6CBD),
        backgroundColor: const Color(0x220F6CBD),
        borderColor: const Color(0xFFE5E7EB),
        icon: Icons.notifications_active_outlined,
        label: 'AVISO',
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
              color: Color(0xFF0F6CBD),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF0F6CBD),
                      ),
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
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              color: Color(0xFF0F6CBD),
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
  const _SettingsInfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF0F6CBD),
              ),
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
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
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

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AccountPageShell(title: title, child: child);
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
          color: Color(0xFF0F6CBD),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({required this.controller, required this.icon});

  final TextEditingController controller;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF0F6CBD)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF0F6CBD), width: 1.4),
        ),
      ),
      style: const TextStyle(color: Color(0xFF0F172A)),
    );
  }
}
