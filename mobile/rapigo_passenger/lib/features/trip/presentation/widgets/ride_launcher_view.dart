import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_brand.dart';
import '../../../auth/data/auth_repository.dart';
import '../pages/orders_development_page.dart';
import 'ride_tab.dart';

class RideLauncherView extends ConsumerWidget {
  const RideLauncherView({
    super.key,
    required this.onChooseMode,
    required this.onOpenProfile,
    required this.onOpenDestinationSearch,
  });

  final ValueChanged<RideMode> onChooseMode;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDestinationSearch;

  void _openOrders(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const OrdersDevelopmentPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final displayName = session.firstName.trim().isNotEmpty
        ? session.firstName.trim()
        : (session.fullName.trim().isNotEmpty
              ? session.fullName.trim().split(' ').first
              : 'Pasajero');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: SafeArea(
        bottom: false,
	        child: LayoutBuilder(
	          builder: (context, constraints) {
	            final compact = constraints.maxHeight < 860;
	            return Center(
	              child: FittedBox(
	                fit: BoxFit.contain,
	                alignment: Alignment.topCenter,
	                child: SizedBox(
	                  width: constraints.maxWidth,
	                  height: compact ? 820 : 870,
	                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HomeHeroHeader(
                        onOpenProfile: onOpenProfile,
                        displayName: displayName,
                      ),
	                      Transform.translate(
	                        offset: Offset(0, compact ? -16 : -22),
	                        child: Padding(
	                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _ServiceCard(
                                      title: 'Pedir Taxi',
                                      description: 'Viaja rapido y seguro',
                                      accent: AppBrand.secondaryBlue,
                                      foreground: Colors.white,
                                      icon: Icons.local_taxi_rounded,
                                      ctaLabel: 'Pedir ahora',
                                      ctaForeground: AppBrand.secondaryBlue,
                                      ctaBackground: Colors.white,
                                      onTap: () => onChooseMode(RideMode.destino),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _ServiceCard(
                                      title: 'Tomar Taxi',
                                      description: 'Encuentra taxis cercanos',
                                      accent: AppBrand.accentYellow,
                                      foreground: AppBrand.textPrimary,
                                      icon: Icons.navigation_rounded,
                                      ctaLabel: 'Conectarme',
                                      ctaForeground: Colors.white,
                                      ctaBackground: AppBrand.secondaryBlue,
                                      onTap: () => onChooseMode(RideMode.cercano),
                                    ),
                                  ),
                                ],
                              ),
	                              SizedBox(height: compact ? 10 : 12),
	                              _OrdersCard(onTap: () => _openOrders(context)),
	                              SizedBox(height: compact ? 10 : 12),
	                              const _MiniMapPreviewCard(),
	                              SizedBox(height: compact ? 10 : 12),
	                              const _BenefitsRow(),
	                              SizedBox(height: compact ? 10 : 12),
	                              _SearchLauncherCard(onTap: onOpenDestinationSearch),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeroHeader extends StatelessWidget {
  const _HomeHeroHeader({
    required this.onOpenProfile,
    required this.displayName,
  });

  final VoidCallback onOpenProfile;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0047FF), Color(0xFF0F6CBD)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -12,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: 110,
            top: 28,
            child: Container(
              width: 150,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: AppBrand.accentYellow,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RapiGo',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 8,
                    shadowColor: const Color(0x330B3CC1),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onOpenProfile,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.person_rounded,
                          color: AppBrand.secondaryBlue,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '¡Buenas noches, $displayName! 👋',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Potosí, Bolivia',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15389F).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220B2C7A),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppBrand.accentYellow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: AppBrand.textPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '120 pts',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Mi saldo',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.title,
    required this.description,
    required this.accent,
    required this.foreground,
    required this.icon,
    required this.ctaLabel,
    required this.ctaForeground,
    required this.ctaBackground,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color accent;
  final Color foreground;
  final IconData icon;
  final String ctaLabel;
  final Color ctaForeground;
  final Color ctaBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent,
                Color.lerp(accent, Colors.white, 0.08)!,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxHeight <= 132 || constraints.maxWidth <= 156;
              final iconBoxWidth = compact ? 56.0 : 76.0;
              final iconBoxHeight = compact ? 40.0 : 56.0;
              final iconSize = compact ? 24.0 : 36.0;
              final titleSize = compact ? 13.0 : 16.0;
              final bodySize = compact ? 10.5 : 13.0;
              final ctaHeight = compact ? 34.0 : 46.0;
              final ctaFontSize = compact ? 11.5 : 14.0;
              final spacingAfterIcon = compact ? 6.0 : 12.0;
              final spacingAfterTitle = compact ? 1.0 : 6.0;
              final spacingBeforeCta = compact ? 4.0 : 12.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: iconBoxWidth,
                      height: iconBoxHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: foreground, size: iconSize),
                    ),
                  ),
                  SizedBox(height: spacingAfterIcon),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: spacingAfterTitle),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: compact ? 1 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                        color: foreground.withValues(alpha: 0.88),
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: spacingBeforeCta),
                  SizedBox(
                    height: ctaHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ctaBackground,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: ctaBackground.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 9 : 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                ctaLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: ctaForeground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: ctaFontSize,
                                ),
                              ),
                            ),
                            Container(
                              width: compact ? 18 : 26,
                              height: compact ? 18 : 26,
                              decoration: BoxDecoration(
                                color: ctaForeground.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: compact ? 12 : 17,
                                color: ctaForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEFF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppBrand.secondaryBlue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos',
                      style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta el estado de tus viajes',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppBrand.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver mis pedidos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppBrand.secondaryBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppBrand.secondaryBlue,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMapPreviewCard extends StatelessWidget {
  const _MiniMapPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FAFF), Color(0xFFF1F7E9)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MiniMapPainter(),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taxis cerca de ti',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: AppBrand.textPrimary,
                      ),
                    ),
                    Text(
                      '5 disponibles',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppBrand.secondaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              top: 16,
              right: 16,
              child: _MiniMapAction(icon: Icons.my_location_rounded),
            ),
            const Positioned(
              left: 128,
              top: 72,
              child: _MiniUserDot(),
            ),
            const Positioned(
              left: 42,
              top: 96,
              child: _MiniTaxiMarker(),
            ),
            const Positioned(
              right: 58,
              top: 38,
              child: _MiniTaxiMarker(),
            ),
            const Positioned(
              right: 26,
              bottom: 30,
              child: _MiniTaxiMarker(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: _BenefitItem(
              icon: Icons.shield_outlined,
              color: AppBrand.secondaryBlue,
              title: 'Seguro',
              subtitle: 'Conductores\nverificados',
            ),
          ),
          Expanded(
            child: _BenefitItem(
              icon: Icons.bolt_rounded,
              color: AppBrand.accentYellow,
              title: 'Rapido',
              subtitle: 'Llegamos en\nminutos',
            ),
          ),
          Expanded(
            child: _BenefitItem(
              icon: Icons.support_agent_rounded,
              color: AppBrand.secondaryBlue,
              title: 'Soporte 24/7',
              subtitle: 'Estamos para\nayudarte',
            ),
          ),
          Expanded(
            child: _BenefitItem(
              icon: Icons.verified_user_outlined,
              color: AppBrand.accentYellow,
              title: 'Confiable',
              subtitle: 'Tu seguridad es\nprioridad',
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLauncherCard extends StatelessWidget {
  const _SearchLauncherCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 10,
      shadowColor: const Color(0x160F172A),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppBrand.secondaryBlue,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '¿A dónde quieres ir?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppBrand.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppBrand.accentYellow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppBrand.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ahora',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppBrand.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMapAction extends StatelessWidget {
  const _MiniMapAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppBrand.secondaryBlue, size: 24),
    );
  }
}

class _MiniUserDot extends StatelessWidget {
  const _MiniUserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppBrand.secondaryBlue.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: AppBrand.secondaryBlue,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MiniTaxiMarker extends StatelessWidget {
  const _MiniTaxiMarker();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.55,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_taxi_rounded,
          color: AppBrand.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              color: AppBrand.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              color: AppBrand.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFD8E1EF)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPaintThin = Paint()
      ..color = const Color(0xFFE6EDF7)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.58),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, 0),
      Offset(size.width * 0.7, size.height),
      roadPaintThin,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, 0),
      Offset(size.width * 0.4, size.height),
      roadPaintThin,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.76),
      Offset(size.width * 0.86, size.height * 0.15),
      roadPaintThin,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
