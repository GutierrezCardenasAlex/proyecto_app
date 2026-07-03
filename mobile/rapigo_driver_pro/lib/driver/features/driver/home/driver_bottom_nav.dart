part of 'driver_home_page.dart';

class DriverBottomNav extends StatelessWidget {
  const DriverBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_rounded, 'Inicio'),
      (Icons.bar_chart_rounded, 'Ganancias'),
      (Icons.local_taxi_rounded, 'Viajes'),
      (Icons.inventory_2_rounded, 'Pedidos'),
      (Icons.person_rounded, 'Perfil'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF081120), Color(0xFF020617)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF1A3A66)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F6CBD).withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onTap(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0x22FACC15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? const Color(0x66FACC15)
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(
                          item.$1,
                          color: selected
                              ? const Color(0xFFFACC15)
                              : const Color(0xFFE2E8F0),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$2,
                        style: GoogleFonts.plusJakartaSans(
                          color: selected
                              ? const Color(0xFFFACC15)
                              : const Color(0xFFDCE6F2),
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
