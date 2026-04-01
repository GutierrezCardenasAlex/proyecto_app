import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/driver_ui_kit.dart';

class DriverProfilePage extends StatelessWidget {
  const DriverProfilePage({super.key, required this.phone, required this.fullName});

  final String phone;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: 'Perfil del conductor',
      child: DriverPageShell(
        eyebrow: 'Cuenta',
        title: 'Perfil',
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.person, size: 44),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    fullName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phone.isEmpty ? '+591 71111111' : phone,
                    style: const TextStyle(
                      color: Color(0xFF47464B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x1A00E3FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'DOCUMENTOS VERIFICADOS',
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
    );
  }
}

class DriverSettingsPage extends StatelessWidget {
  const DriverSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Configuraciones',
      eyebrow: 'Preferencias',
      items: [
        ('Navegacion', 'Ajusta el comportamiento del mapa y seguimiento de ruta.'),
        ('Alertas', 'Controla sonido y avisos de nuevos viajes.'),
        ('Cuenta', 'Revisa tus datos, vehiculo y documentos.'),
      ],
    );
  }
}

class DriverSecurityPage extends StatelessWidget {
  const DriverSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Seguridad',
      eyebrow: 'Seguridad',
      items: [
        ('Sesion OTP', 'Tu acceso como conductor se valida con OTP.'),
        ('Ruta segura', 'Comparte tu posicion con panel y pasajero en tiempo real.'),
        ('Cobertura', 'La app valida operacion solo dentro de Potosi.'),
      ],
    );
  }
}

class DriverHelpPage extends StatelessWidget {
  const DriverHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Centro de ayuda',
      eyebrow: 'Ayuda',
      items: [
        ('Soporte', 'Canales de ayuda para incidencias de viajes o pagos.'),
        ('Preguntas frecuentes', 'Respuestas para disponibilidad, GPS y aceptacion.'),
        ('Emergencias', 'Opciones de asistencia en incidentes.'),
      ],
    );
  }
}

class DriverEarningsPage extends StatelessWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleDriverPage(
      title: 'Ganancias',
      eyebrow: 'Ingresos',
      items: [
        ('Hoy', 'Visualiza viajes completados y efectivo estimado del dia.'),
        ('Semana', 'Resumen semanal de actividad del conductor.'),
        ('Liquidacion', 'Comprobantes y cierres operativos.'),
      ],
    );
  }
}

class _SimpleDriverPage extends StatelessWidget {
  const _SimpleDriverPage({
    required this.title,
    required this.eyebrow,
    required this.items,
  });

  final String title;
  final String eyebrow;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: title,
      child: DriverPageShell(
        eyebrow: eyebrow,
        title: title,
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DriverMenuTile(
                    icon: Icons.check_circle_outline,
                    title: item.$1,
                    subtitle: item.$2,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: child,
    );
  }
}
