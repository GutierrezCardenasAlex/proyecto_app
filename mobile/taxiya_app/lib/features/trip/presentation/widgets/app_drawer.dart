import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/admin_center/admin_center_repository.dart';

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
    final progressValue = safeCycleLength == 0 ? 0.0 : cycleProgress / safeCycleLength;
    final promoCaption = !promoEnabled
        ? 'La central pauso esta promocion por ahora.'
        : freeTripCredits > 0
            ? 'Tu siguiente viaje ya es gratis y el ciclo actual volvio a 0/$safeCycleLength.'
            : '$cycleProgress/$safeCycleLength para tu proximo viaje gratis';
    final items = const [
      ('Inicio', Icons.home_rounded),
      ('Tus viajes', Icons.history),
      ('Cuenta', Icons.person_outline_rounded),
      ('Promociones', Icons.sell),
      ('Notificaciones', Icons.notifications_active_outlined),
      ('Soporte', Icons.support_agent),
      ('Configuraciones', Icons.settings),
    ];

    return Drawer(
      width: 320,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111214), Color(0xFF1B1B1F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: const Color(0xFF1F1F24),
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: onOpenProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A31),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(Icons.person, size: 36, color: Color(0xFFFFF4EC)),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.verified, size: 16, color: Color(0xFF0F0F10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF4EC),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (index) => const Padding(
                                        padding: EdgeInsets.only(right: 2),
                                        child: Icon(
                                          Icons.star_rounded,
                                          size: 16,
                                          color: Color(0xFFFDBA74),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      '4.95',
                                      style: TextStyle(
                                        color: Color(0xFFFDBA74),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17181B),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x26F97316)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0x33F97316),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF97316)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  promoEnabled ? 'Promocion activa' : 'Promocion pausada',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF4EC),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  promoCaption,
                                  style: const TextStyle(
                                    color: Color(0xFFFFD8BF),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: freeTripCredits > 0
                                  ? const Color(0x1F22C55E)
                                  : const Color(0xFF0F0F10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                              child: Text(
                              freeTripCredits > 0 ? 'Gratis' : '$cycleProgress/5',
                              style: TextStyle(
                                color: freeTripCredits > 0
                                    ? const Color(0xFF86EFAC)
                                    : promoEnabled
                                        ? const Color(0xFFF97316)
                                        : const Color(0xFFFFD8BF),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: promoEnabled ? (freeTripCredits > 0 ? 1 : progressValue) : 0,
                          backgroundColor: const Color(0xFF25252B),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            !promoEnabled
                                ? const Color(0xFF52525B)
                                : freeTripCredits > 0
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF97316),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.route_rounded, size: 16, color: Color(0xFFFFD8BF)),
                          const SizedBox(width: 8),
                          Text(
                            '$totalTrips viajes completados en total',
                            style: const TextStyle(
                              color: Color(0xFFFFD8BF),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final active = item.$1 == activeItem;
                      final isPromotions = item.$1 == 'Promociones';
                      final isNotifications = item.$1 == 'Notificaciones';
                      final isSupport = item.$1 == 'Soporte';
                      return Container(
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFFF97316) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? const Color(0xFFF97316) : const Color(0xFF2D2D32),
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: active ? const Color(0xFF0F0F10) : const Color(0xFF25252B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.$2,
                              size: 22,
                              color: active ? const Color(0xFFF97316) : const Color(0xFFFFC89B),
                            ),
                          ),
                          title: Text(
                            item.$1,
                            style: TextStyle(
                              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                              color: active ? const Color(0xFF0F0F10) : const Color(0xFFFFF4EC),
                            ),
                          ),
                          trailing: isPromotions
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0x220F0F10)
                                        : !promoEnabled
                                            ? const Color(0xFF25252B)
                                            : freeTripCredits > 0
                                            ? const Color(0x1F22C55E)
                                            : const Color(0xFF25252B),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    !promoEnabled
                                        ? 'Pausada'
                                        : freeTripCredits > 0
                                            ? 'Gratis'
                                            : '$cycleProgress/$safeCycleLength',
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFF0F0F10)
                                          : !promoEnabled
                                              ? const Color(0xFFFFD8BF)
                                              : freeTripCredits > 0
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFFF97316),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              : isNotifications
                                  ? _InboxBadge(token: token)
                                  : isSupport
                                      ? _SupportBadge(token: token)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(item.$1);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onLogout();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    icon: const Icon(Icons.logout),
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

class _InboxBadge extends StatelessWidget {
  const _InboxBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final repository = const AdminCenterRepository();
    return FutureBuilder<List<AdminNotificationItem>>(
      future: token.isEmpty ? Future.value(const <AdminNotificationItem>[]) : repository.fetchNotifications(token),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _DrawerCountBadge(
          count: count,
          color: const Color(0xFF22C55E),
          emptyLabel: '0',
        );
      },
    );
  }
}

class _SupportBadge extends StatelessWidget {
  const _SupportBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final repository = const AdminCenterRepository();
    return FutureBuilder<List<SupportReportItem>>(
      future: token.isEmpty ? Future.value(const <SupportReportItem>[]) : repository.fetchSupportReports(token),
      builder: (context, snapshot) {
        final openCount = (snapshot.data ?? const <SupportReportItem>[])
            .where((item) => item.status.toUpperCase() == 'ABIERTO')
            .length;
        return _DrawerCountBadge(
          count: openCount,
          color: const Color(0xFFF97316),
          emptyLabel: 'OK',
        );
      },
    );
  }
}

class _DrawerCountBadge extends StatelessWidget {
  const _DrawerCountBadge({
    required this.count,
    required this.color,
    required this.emptyLabel,
  });

  final int count;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final hasCount = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasCount ? color.withValues(alpha: 0.14) : const Color(0xFF25252B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hasCount ? '$count' : emptyLabel,
        style: TextStyle(
          color: hasCount ? color : const Color(0xFFFFD8BF),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
