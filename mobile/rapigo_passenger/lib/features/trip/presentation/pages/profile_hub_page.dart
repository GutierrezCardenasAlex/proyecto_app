import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/admin_center/admin_center_repository.dart';
import '../../../../core/config/app_brand.dart';
import '../../../auth/data/auth_repository.dart';
import 'detail_pages.dart';

class ProfileHubPage extends ConsumerWidget {
  const ProfileHubPage({
    super.key,
    required this.onGoHome,
    required this.onGoTrips,
    required this.onLogout,
  });

  final VoidCallback onGoHome;
  final VoidCallback onGoTrips;
  final VoidCallback onLogout;

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final safeCycleLength = session.promoCycleLength <= 0
        ? 5
        : session.promoCycleLength;
    final normalizedProgress = session.promoProgressCount
        .clamp(0, safeCycleLength)
        .toInt();
    final cycleProgress = session.freeTripCredits > 0 ? 0 : normalizedProgress;
    final progressValue = cycleProgress / safeCycleLength;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppBrand.textPrimary,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuenta',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppBrand.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Tu perfil y accesos de RAPIGO',
                              style: TextStyle(
                                color: AppBrand.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 82,
                              height: 82,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0F6CBD),
                                    Color(0xFF38BDF8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.fullName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
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
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: const [
                                      _ProfilePill(
                                        icon: Icons.verified_rounded,
                                        label: 'Verificado',
                                      ),
                                      _ProfilePill(
                                        icon: Icons.star_rounded,
                                        label: 'Cuenta activa',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F6CBD), Color(0xFF38BDF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
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
                                session.freeTripCredits > 0
                                    ? 'Tu viaje gratis ya esta listo'
                                    : 'Viajes y beneficios',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${session.completedTripCount} viajes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          session.freeTripCredits > 0
                              ? 'Tu siguiente viaje ya puede salir gratis.'
                              : '$cycleProgress de $safeCycleLength viajes para desbloquear tu siguiente beneficio.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progressValue.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFACC15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.home_rounded,
                          label: 'Inicio',
                          onTap: () {
                            onGoHome();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.history_rounded,
                          label: 'Tus viajes',
                          onTap: () {
                            onGoTrips();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAccessCard(
                          icon: Icons.edit_outlined,
                          label: 'Editar',
                          onTap: () {
                            _openPage(context, const ProfilePage());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuTile(
                          icon: Icons.edit_outlined,
                          title: 'Editar perfil',
                          subtitle:
                              'Nombre, telefono, correo y datos visuales.',
                          onTap: () => _openPage(context, const ProfilePage()),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.sell_rounded,
                          title: 'Promociones',
                          subtitle:
                              'Beneficios, descuentos y regalos disponibles.',
                          onTap: () =>
                              _openPage(context, const PromotionsPage()),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notificaciones',
                          subtitle: 'Mensajes, avisos y novedades recientes.',
                          trailing: _InboxBadge(token: session.token),
                          onTap: () =>
                              _openPage(context, const NotificationsPage()),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.support_agent_rounded,
                          title: 'Soporte',
                          subtitle: 'Ayuda, reportes y asistencia.',
                          trailing: _SupportBadge(token: session.token),
                          onTap: () => _openPage(context, const SupportPage()),
                        ),
                        const SizedBox(height: 8),
                        _ProfileMenuTile(
                          icon: Icons.settings_rounded,
                          title: 'Configuraciones',
                          subtitle: 'Preferencias, mapas y ajustes de la app.',
                          onTap: () => _openPage(context, const SettingsPage()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _AppVersionCard(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onLogout();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppBrand.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesion'),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? 'Cargando version...'
            : 'Version ${info.version}+${info.buildNumber}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEFF6FF),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppBrand.primaryBlue,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RAPIGO Pasajero',
                      style: TextStyle(
                        color: AppBrand.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      version,
                      style: const TextStyle(
                        color: AppBrand.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
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
                  fontWeight: FontWeight.w800,
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

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.surfaceSoft,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
              if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppBrand.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppBrand.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppBrand.primaryBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppBrand.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxBadge extends StatelessWidget {
  const _InboxBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminNotificationItem>>(
      future: const AdminCenterRepository().fetchNotifications(token),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }
        return _CountBadge(count: count);
      },
    );
  }
}

class _SupportBadge extends StatelessWidget {
  const _SupportBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportReportItem>>(
      future: const AdminCenterRepository().fetchSupportReports(token),
      builder: (context, snapshot) {
        final count =
            snapshot.data
                ?.where((item) => item.status.toUpperCase() != 'CERRADO')
                .length ??
            0;
        if (count <= 0) {
          return const SizedBox.shrink();
        }
        return _CountBadge(count: count);
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppBrand.primaryBlue,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
