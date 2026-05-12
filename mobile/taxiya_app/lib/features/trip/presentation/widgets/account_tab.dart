import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return PageShell(
      eyebrow: 'Account',
      title: 'Perfil',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      trailing: IconButton.filledTonal(
        onPressed: onOpenProfile,
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1F),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF2C2C31)),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A31),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, size: 36, color: Color(0xFFFFF4EC)),
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
                          color: const Color(0xFFFFF4EC),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: 17,
                                color: Color(0xFFFDBA74),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
          const SizedBox(height: 18),
          SimpleMenuTile(
            onTap: onOpenNotifications,
            icon: Icons.notifications_active_outlined,
            title: 'Notificaciones',
            subtitle: 'Administra avisos, promociones y alertas del viaje.',
          ),
          const SizedBox(height: 14),
          SimpleMenuTile(
            onTap: onOpenSettings,
            icon: Icons.settings_outlined,
            title: 'Descarga de mapa',
            subtitle: 'Guarda Potosi ciudad para usar el mapa aun con señal baja.',
          ),
          const SizedBox(height: 14),
          SimpleMenuTile(
            onTap: onOpenSupport,
            icon: Icons.support_agent,
            title: 'Soporte',
            subtitle: 'Reporta fallas de la app y sigue tus casos con central.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
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
    );
  }
}
