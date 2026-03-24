import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/data/auth_repository.dart';
import 'ui_kit.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({
    super.key,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenSecurity,
    required this.onOpenSettings,
    required this.onOpenSupport,
  });

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSecurity;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return PageShell(
      eyebrow: 'Account',
      title: 'Perfil',
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.person, size: 36, color: Color(0xFF000003)),
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
                          color: const Color(0xFF000003),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        session.phone,
                        style: const TextStyle(
                          color: Color(0xFF47464B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1A00E3FD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'POTOSI · ACTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Color(0xFF00616D),
                          ),
                        ),
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
            onTap: onOpenSecurity,
            icon: Icons.lock_outline,
            title: 'Seguridad',
            subtitle: 'Revision de sesiones, OTP y proteccion de cuenta.',
          ),
          const SizedBox(height: 14),
          SimpleMenuTile(
            onTap: onOpenSettings,
            icon: Icons.settings_outlined,
            title: 'Configuraciones',
            subtitle: 'Preferencias de idioma, mapa y experiencia de viaje.',
          ),
          const SizedBox(height: 14),
          SimpleMenuTile(
            onTap: onOpenSupport,
            icon: Icons.support_agent,
            title: 'Soporte',
            subtitle: 'Contacta ayuda y revisa preguntas frecuentes.',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
            ),
          ),
        ],
      ),
    );
  }
}
