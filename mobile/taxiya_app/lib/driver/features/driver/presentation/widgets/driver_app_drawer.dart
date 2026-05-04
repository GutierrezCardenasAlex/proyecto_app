import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverAppDrawer extends StatelessWidget {
  const DriverAppDrawer({
    super.key,
    required this.fullName,
    required this.phone,
    required this.activeItem,
    required this.onSelect,
    required this.onLogout,
    required this.onOpenProfile,
  });

  final String fullName;
  final String phone;
  final String activeItem;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final items = const [
      ('Panel de viaje', Icons.local_taxi),
      ('Historial', Icons.history),
      ('Ganancias', Icons.payments),
      ('Seguridad', Icons.shield),
      ('Centro de ayuda', Icons.help),
      ('Configuraciones', Icons.settings),
    ];

    return Drawer(
      width: 320,
      child: Container(
        color: const Color(0xFFF9F9FB),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: onOpenProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F3F5),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(Icons.person, size: 36),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E3FD),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.verified, size: 16, color: Color(0xFF001F24)),
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
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Calificacion 4.97',
                                  style: TextStyle(
                                    color: Color(0xFF006875),
                                    fontWeight: FontWeight.w800,
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
                                    'ACTIVO EN POTOSI',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Color(0xFF00616D),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  phone.isEmpty ? '+591 71111111' : phone,
                                  style: const TextStyle(color: Color(0xFF47464B)),
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
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final active = item.$1 == activeItem;
                      return Container(
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF00E3FD) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: active ? const Color(0x1A001F24) : const Color(0xFFF3F3F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.$2),
                          ),
                          title: Text(
                            item.$1,
                            style: TextStyle(
                              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                              color: active ? const Color(0xFF001F24) : const Color(0xFF000003),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(item.$1);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Color(0x1AC8C5CC)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(context);
                      onLogout();
                    },
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
