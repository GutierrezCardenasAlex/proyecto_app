part of '../driver_home_page.dart';

class DriverOrdersTab extends StatelessWidget {
  const DriverOrdersTab({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DriverPageShell(
      eyebrow: 'Pedidos',
      title: 'Centro de pedidos',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1730), Color(0xFF102449)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0x332979FF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0x19FACC15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x55FACC15)),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFFFACC15),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Esta etapa esta en desarrollo',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Muy pronto el modulo de pedidos estara disponible dentro de RAPIGO PRO.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFDCE6F2),
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
