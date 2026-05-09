import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.fullName,
    required this.phone,
    required this.onLogout,
    required this.activeItem,
    required this.onSelect,
    required this.onOpenProfile,
    required this.promoProgress,
    required this.freeTripCredits,
  });

  final String fullName;
  final String phone;
  final VoidCallback onLogout;
  final String activeItem;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenProfile;
  final int promoProgress;
  final int freeTripCredits;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = promoProgress.clamp(0, 5).toInt();
    final progressValue = normalizedProgress / 5.0;
    final promoCaption = freeTripCredits > 0
        ? '$freeTripCredits viaje gratis disponible'
        : '$normalizedProgress/5 para tu proximo viaje gratis';
    final items = const [
      ('Inicio', Icons.home_rounded),
      ('Tus viajes', Icons.history),
      ('Cuenta', Icons.person_outline_rounded),
      ('Metodos de pago', Icons.payments),
      ('Promociones', Icons.sell),
      ('Seguridad', Icons.shield),
      ('Centro de ayuda', Icons.help),
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
                                const Text(
                                  'Calificacion 4.95',
                                  style: TextStyle(
                                    color: Color(0xFFFDBA74),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33F97316),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'MIEMBRO FLASH GO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Color(0xFFFFC89B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  phone,
                                  style: const TextStyle(color: Color(0xFFFFDCC1)),
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
                                  'Promocion activa',
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
                              freeTripCredits > 0 ? 'Gratis' : '$normalizedProgress/5',
                              style: TextStyle(
                                color: freeTripCredits > 0
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFF97316),
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
                          value: freeTripCredits > 0 ? 1 : progressValue,
                          backgroundColor: const Color(0xFF25252B),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            freeTripCredits > 0 ? const Color(0xFF22C55E) : const Color(0xFFF97316),
                          ),
                        ),
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
                                        : freeTripCredits > 0
                                            ? const Color(0x1F22C55E)
                                            : const Color(0xFF25252B),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    freeTripCredits > 0 ? 'Gratis' : '$normalizedProgress/5',
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFF0F0F10)
                                          : freeTripCredits > 0
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFFF97316),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
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
                const SizedBox(height: 10),
                const Text(
                  'LEGAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: Color(0xFFFFC89B),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Politica de privacidad', style: TextStyle(color: Color(0xFFFFDCC1))),
                const SizedBox(height: 6),
                const Text('Terminos del servicio', style: TextStyle(color: Color(0xFFFFDCC1))),
                const SizedBox(height: 16),
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
