import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/admin_center/admin_center_repository.dart';

class DriverAppDrawer extends StatelessWidget {
  const DriverAppDrawer({
    super.key,
    required this.fullName,
    required this.phone,
    required this.token,
    required this.activeItem,
    required this.onSelect,
    required this.onLogout,
    required this.onOpenProfile,
  });

  final String fullName;
  final String phone;
  final String token;
  final String activeItem;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Panel de viaje', Icons.local_taxi),
      ('Viajes disponibles', Icons.assignment_rounded),
      ('Estadistica', Icons.insights_rounded),
      ('Cuenta', Icons.person_outline_rounded),
      ('Notificaciones', Icons.notifications_active_outlined),
      ('Soporte', Icons.support_agent),
      ('Configuraciones', Icons.settings),
    ];

    return Drawer(
      width: 292,
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
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: const Color(0xFF1F1F24),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onOpenProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A31),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Color(0xFFFFF4EC),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    size: 13,
                                    color: Color(0xFF0F0F10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFFFF4EC),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Calificacion 4.97',
                                  style: TextStyle(
                                    color: Color(0xFFFDBA74),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33F97316),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'ACTIVO EN POTOSI',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Color(0xFFFFC89B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  phone,
                                  style: const TextStyle(
                                    color: Color(0xFFFFDCC1),
                                    fontSize: 11,
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
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final active = item.$1 == activeItem;
                      final isNotifications = item.$1 == 'Notificaciones';
                      final isSupport = item.$1 == 'Soporte';
                      return Container(
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFF97316)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active
                                ? const Color(0xFFF97316)
                                : const Color(0xFF2D2D32),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -3,
                          ),
                          minLeadingWidth: 34,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF0F0F10)
                                  : const Color(0xFF25252B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.$2,
                              size: 18,
                              color: active
                                  ? const Color(0xFFF97316)
                                  : const Color(0xFFFFC89B),
                            ),
                          ),
                          title: Text(
                            item.$1,
                            style: TextStyle(
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                              color: active
                                  ? const Color(0xFF0F0F10)
                                  : const Color(0xFFFFF4EC),
                            ),
                          ),
                          trailing: isNotifications
                              ? _DriverInboxBadge(token: token)
                              : isSupport
                              ? _DriverSupportBadge(token: token)
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
                const Divider(color: Color(0x33F97316)),
                const SizedBox(height: 8),
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
                      minimumSize: const Size.fromHeight(38),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
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

class _DriverInboxBadge extends StatelessWidget {
  const _DriverInboxBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final repository = const AdminCenterRepository();
    return FutureBuilder<List<AdminNotificationItem>>(
      future: token.isEmpty
          ? Future.value(const <AdminNotificationItem>[])
          : repository.fetchNotifications(token),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _DriverDrawerBadge(
          count: count,
          color: const Color(0xFF22C55E),
          emptyLabel: '0',
        );
      },
    );
  }
}

class _DriverSupportBadge extends StatelessWidget {
  const _DriverSupportBadge({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final repository = const AdminCenterRepository();
    return FutureBuilder<List<SupportReportItem>>(
      future: token.isEmpty
          ? Future.value(const <SupportReportItem>[])
          : repository.fetchSupportReports(token),
      builder: (context, snapshot) {
        final openCount = (snapshot.data ?? const <SupportReportItem>[])
            .where((item) => item.status.toUpperCase() == 'ABIERTO')
            .length;
        return _DriverDrawerBadge(
          count: openCount,
          color: const Color(0xFFF97316),
          emptyLabel: 'OK',
        );
      },
    );
  }
}

class _DriverDrawerBadge extends StatelessWidget {
  const _DriverDrawerBadge({
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
        color: hasCount
            ? color.withValues(alpha: 0.14)
            : const Color(0xFF25252B),
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
