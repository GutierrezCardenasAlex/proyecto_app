import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/admin_center/admin_center_repository.dart';
import '../../../../core/config/app_brand.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.fullName,
    required this.phone,
    required this.token,
    required this.onLogout,
    required this.activeItem,
    required this.onSelect,
    required this.onOpenProfile,
    required this.promoProgress,
    required this.totalTrips,
    required this.freeTripCredits,
    required this.promoEnabled,
    required this.promoCycleLength,
  });

  final String fullName;
  final String phone;
  final String token;
  final VoidCallback onLogout;
  final String activeItem;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenProfile;
  final int promoProgress;
  final int totalTrips;
  final int freeTripCredits;
  final bool promoEnabled;
  final int promoCycleLength;

  @override
  Widget build(BuildContext context) {
    final safeCycleLength = promoCycleLength <= 0 ? 5 : promoCycleLength;
    final normalizedProgress = promoProgress.clamp(0, safeCycleLength).toInt();
    final cycleProgress = freeTripCredits > 0 ? 0 : normalizedProgress;
    final progressValue = cycleProgress / safeCycleLength;
    final promoCaption = !promoEnabled
        ? 'La promocion esta pausada por ahora.'
        : freeTripCredits > 0
            ? 'Tu siguiente viaje ya es gratis.'
            : '$cycleProgress de $safeCycleLength viajes para desbloquear tu proximo beneficio.';
    final items = const [
      ('Inicio', Icons.home_rounded),
      ('Tus viajes', Icons.history_rounded),
      ('Cuenta', Icons.person_outline_rounded),
      ('Promociones', Icons.sell_rounded),
      ('Notificaciones', Icons.notifications_none_rounded),
      ('Soporte', Icons.support_agent_rounded),
      ('Configuraciones', Icons.settings_outlined),
    ];

    return Drawer(
      width: 336,
      child: SafeArea(
        child: Container(
          color: const Color(0xFFF5F5F7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cuenta',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppBrand.textPrimary,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: onOpenProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF0F6CBD), Color(0xFF38BDF8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppBrand.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        color: AppBrand.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _MiniPill(icon: Icons.verified_rounded, label: 'Cliente verificado'),
                              _MiniPill(icon: Icons.star_rounded, label: 'Cuenta activa'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100F172A),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Viajes y beneficios',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppBrand.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (freeTripCredits > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$freeTripCredits gratis',
                                style: const TextStyle(
                                  color: AppBrand.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        promoCaption,
                        style: const TextStyle(
                          color: AppBrand.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppBrand.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBubble(
                              label: 'Viajes',
                              value: '$totalTrips',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatBubble(
                              label: 'Progreso',
                              value: '$cycleProgress/$safeCycleLength',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickDrawerAction(
                          icon: Icons.history_rounded,
                          label: 'Viajes',
                          onTap: () {
                            Navigator.pop(context);
                            onSelect('Tus viajes');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickDrawerAction(
                          icon: Icons.support_agent_rounded,
                          label: 'Soporte',
                          onTap: () {
                            Navigator.pop(context);
                            onSelect('Soporte');
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickDrawerAction(
                          icon: Icons.settings_rounded,
                          label: 'Config.',
                          onTap: () {
                            Navigator.pop(context);
                            onSelect('Configuraciones');
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Accesos',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppBrand.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final (label, icon) = items[index];
                      final selected = activeItem == label;
                      return _DrawerTile(
                        label: label,
                        icon: icon,
                        selected: selected,
                        trailing: switch (label) {
                          'Notificaciones' => _InboxBadge(token: token),
                          'Soporte' => _SupportBadge(token: token),
                          _ => null,
                        },
                        onTap: () {
                          Navigator.pop(context);
                          onSelect(label);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppBrand.danger,
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0x66FFFFFF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? AppBrand.surfaceSoft : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppBrand.primaryBlue : AppBrand.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right_rounded, color: AppBrand.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppBrand.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppBrand.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppBrand.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

class _QuickDrawerAction extends StatelessWidget {
  const _QuickDrawerAction({
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
      color: AppBrand.surfaceSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppBrand.primaryBlue),
              const SizedBox(height: 8),
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
        final count = snapshot.data?.where((item) => item.status.toUpperCase() != 'CERRADO').length ?? 0;
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
