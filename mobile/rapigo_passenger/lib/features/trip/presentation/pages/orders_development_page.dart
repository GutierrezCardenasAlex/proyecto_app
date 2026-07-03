import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';

class OrdersDevelopmentPage extends StatelessWidget {
  const OrdersDevelopmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7F0FF),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFDCEBFF),
                      Color(0xFFFFF4BF),
                      Color(0xFFE4EEFF),
                    ],
                    stops: [0, 0.52, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: const Color(0xFF1D4ED8),
                        shape: const CircleBorder(),
                        elevation: 10,
                        shadowColor: const Color(0x331D4ED8),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: const SizedBox(
                            width: 54,
                            height: 54,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Pedidos',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppBrand.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.4, -0.45),
                        radius: 1.45,
                        colors: [
                          const Color(0xFFEAF2FF),
                          const Color(0xFFFFF7D6),
                          Colors.white.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.14),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEAF2FF), Color(0xFFFFF7D6)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: AppBrand.primaryBlue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Vista de pedidos en desarrollo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppBrand.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Muy pronto vas a poder ver aquí tus pedidos, su estado y todo el seguimiento desde una pantalla dedicada.',
                          style: TextStyle(
                            color: AppBrand.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7D6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFFFACC15,
                              ).withValues(alpha: 0.38),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.construction_rounded,
                                color: Color(0xFFB45309),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Estamos trabajando en ello.',
                                  style: TextStyle(
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
