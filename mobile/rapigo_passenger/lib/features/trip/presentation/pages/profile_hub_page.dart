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
    final cycleLength = session.promoCycleLength <= 0
        ? 5
        : session.promoCycleLength;
    final progress = session.promoProgressCount.clamp(0, cycleLength).toInt();
    final hasFreeTrip = session.freeTripCredits > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cuenta',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppBrand.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AccountIdentity(
                    name: session.fullName.trim().isEmpty
                        ? 'Pasajero'
                        : session.fullName.trim(),
                    phone: session.phone,
                    onEdit: () => _openPage(context, const ProfilePage()),
                  ),
                  if (session.promoEnabled) ...[
                    const SizedBox(height: 20),
                    _BenefitsCard(
                      progress: progress,
                      cycleLength: cycleLength,
                      credits: session.freeTripCredits,
                      hasFreeTrip: hasFreeTrip,
                      onTap: () => _openPage(context, const PromotionsPage()),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _AccountSection(
                    title: 'Tu actividad',
                    children: [
                      _AccountMenuTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Mis viajes',
                        subtitle:
                            '${session.completedTripCount} viajes completados',
                        onTap: () {
                          onGoTrips();
                          Navigator.of(context).pop();
                        },
                      ),
                      _AccountMenuTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Avisos y novedades',
                        trailing: _InboxBadge(token: session.token),
                        onTap: () =>
                            _openPage(context, const NotificationsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _AccountSection(
                    title: 'Preferencias y ayuda',
                    children: [
                      _AccountMenuTile(
                        icon: Icons.tune_rounded,
                        title: 'Configuración',
                        subtitle: 'Preferencias de la aplicación',
                        onTap: () => _openPage(context, const SettingsPage()),
                      ),
                      _AccountMenuTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Soporte',
                        subtitle: 'Ayuda y seguimiento de reportes',
                        trailing: _SupportBadge(token: session.token),
                        onTap: () => _openPage(context, const SupportPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppBrand.danger,
                      side: const BorderSide(color: Color(0xFFE8EBF2)),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Cerrar sesión'),
                  ),
                  const SizedBox(height: 20),
                  const _AppVersionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({
    required this.name,
    required this.phone,
    required this.onEdit,
  });

  final String name;
  final String phone;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 38,
              color: AppBrand.secondaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppBrand.textPrimary,
              fontSize: 24,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              phone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppBrand.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onEdit,
            style: FilledButton.styleFrom(
              backgroundColor: AppBrand.secondaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar perfil'),
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({
    required this.progress,
    required this.cycleLength,
    required this.credits,
    required this.hasFreeTrip,
    required this.onTap,
  });

  final int progress;
  final int cycleLength;
  final int credits;
  final bool hasFreeTrip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrand.secondaryBlue,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.redeem_rounded,
                    color: AppBrand.accentYellow,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus beneficios',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                hasFreeTrip
                    ? (credits == 1
                          ? 'Tienes un viaje gratis disponible'
                          : 'Tienes $credits viajes gratis disponibles')
                    : '$progress de $cycleLength viajes para tu próximo beneficio',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: hasFreeTrip ? 1 : progress / cycleLength,
                minHeight: 6,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: Colors.white24,
                color: AppBrand.accentYellow,
                semanticsLabel: 'Progreso de beneficios',
                semanticsValue: hasFreeTrip
                    ? 'Beneficio disponible'
                    : '$progress de $cycleLength viajes',
              ),
              const SizedBox(height: 14),
              const Text(
                'Ver promociones y beneficios',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppBrand.textPrimary,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE8EBF2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: 68,
                    endIndent: 18,
                    color: Color(0xFFEEF0F5),
                  ),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: AppBrand.secondaryBlue, size: 24),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppBrand.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppBrand.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppBrand.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();

  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Text(
          info == null
              ? 'Rápigo Pasajero'
              : 'Rápigo Pasajero · Versión ${info.version}+${info.buildNumber}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppBrand.textSecondary,
            fontSize: 11,
            height: 1.5,
          ),
        );
      },
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
