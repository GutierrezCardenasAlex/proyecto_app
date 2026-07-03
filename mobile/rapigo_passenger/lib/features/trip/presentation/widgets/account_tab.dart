import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
import '../../../auth/data/auth_repository.dart';
import 'ui_kit.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({
    super.key,
    this.onBack,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    required this.onOpenSupport,
  });

  final VoidCallback? onBack;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final completionItems = <bool>[
      session.firstName.trim().isNotEmpty && session.lastName.trim().isNotEmpty,
      session.email.trim().isNotEmpty,
      true,
    ];
    final completedCount = completionItems.where((item) => item).length;

    return PageShell(
      eyebrow: 'Cuenta',
      title: 'Perfil',
      leading: onBack == null
          ? null
          : IconButton.filled(
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: AppBrand.surface,
                foregroundColor: AppBrand.textPrimary,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      trailing: IconButton.filled(
        onPressed: onOpenProfile,
        style: IconButton.styleFrom(
          backgroundColor: AppBrand.primaryBlue,
          foregroundColor: Colors.white,
        ),
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppBrand.surface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F6CBD), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220F6CBD),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded, size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  session.fullName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.phone,
                  style: const TextStyle(
                    color: AppBrand.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(
                      5,
                      (index) => const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '4.95',
                      style: TextStyle(
                        color: AppBrand.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.history_rounded,
                  label: 'Historial',
                  onTap: onOpenNotifications,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.support_agent_rounded,
                  label: 'Asistencia',
                  onTap: onOpenSupport,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.place_rounded,
                  label: 'Direcciones',
                  onTap: onOpenProfile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.settings_rounded,
                  label: 'Config.',
                  onTap: onOpenSettings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F6CBD), Color(0xFF38BDF8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220F6CBD),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        completedCount == 3 ? 'Perfil verificado' : 'COMPLETA TU PERFIL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$completedCount de 3',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: completedCount / 3,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFACC15)),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfileCheck(label: 'Nombre', done: completionItems[0]),
                    _ProfileCheck(label: 'Correo', done: completionItems[1]),
                    _ProfileCheck(label: 'Foto', done: completionItems[2]),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onOpenProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppBrand.primaryBlue,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(completedCount == 3 ? 'Ver perfil' : 'Confirmar mis datos'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Preferencias'),
          const SizedBox(height: 10),
          _AccountOption(
            icon: Icons.sell_rounded,
            title: 'Descuentos y regalos',
            subtitle: 'Usa codigos promocionales y revisa beneficios activos.',
            badge: 'Promo',
            onTap: onOpenNotifications,
          ),
          const SizedBox(height: 10),
          _AccountOption(
            icon: Icons.payments_rounded,
            title: 'Metodos de pago',
            subtitle: 'Actualmente tu cuenta esta lista para cobrar en efectivo.',
            badge: 'Efectivo',
            onTap: onOpenSettings,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppBrand.textPrimary,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Genera ganancias como conductor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Invita a otra persona o postulate para conducir en RAPIGO PRO.',
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onOpenSupport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                  child: const Text('Conocer mas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('Mas opciones'),
          const SizedBox(height: 10),
          _AccountOption(
            icon: Icons.map_outlined,
            title: 'Mejora los mapas',
            subtitle: 'Ayudanos a pulir puntos de referencia y ubicaciones utiles.',
            onTap: onOpenSupport,
          ),
          const SizedBox(height: 10),
          _AccountOption(
            icon: Icons.security_rounded,
            title: 'Seguridad',
            subtitle: 'Consulta recomendaciones y acciones de proteccion en viaje.',
            onTap: onOpenSupport,
          ),
          const SizedBox(height: 10),
          _AccountOption(
            icon: Icons.info_outline_rounded,
            title: 'Informacion de viajes cancelados',
            subtitle: 'Revisa como se calculan cancelaciones y tiempos de espera.',
            onTap: onOpenNotifications,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppBrand.primaryBlue),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppBrand.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCheck extends StatelessWidget {
  const _ProfileCheck({
    required this.label,
    required this.done,
  });

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? const Color(0xFF86EFAC) : Colors.white70,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppBrand.textPrimary,
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppBrand.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AppBrand.primaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: AppBrand.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppBrand.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
