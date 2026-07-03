import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_request.dart';
import 'ui_kit.dart';

class ActivityTab extends ConsumerWidget {
  const ActivityTab({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final tripState = ref.watch(tripProvider);

    return PageShell(
      eyebrow: 'Historial',
      title: 'Tus viajes',
      leading: onBack == null
          ? null
          : IconButton.filledTonal(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
      child: Column(
        children: [
          if (tripState.history.isEmpty)
            const EmptyCard(
              title: 'Sin historial aun',
              subtitle: 'Tus viajes confirmados apareceran aqui cuando empieces a moverte por Potosi.',
            )
          else
            ...tripState.history.map((trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _JourneyCard(
                    trip: trip,
                    passengerName: session.fullName,
                    token: session.token,
                  ),
                )),
        ],
      ),
    );
  }
}

class _JourneyCard extends ConsumerWidget {
  const _JourneyCard({
    required this.trip,
    required this.passengerName,
    required this.token,
  });

  final TripHistoryItem trip;
  final String passengerName;
  final String token;

  Color get _statusColor {
    return switch (trip.status) {
      'requested' || 'searching' || 'accepted' || 'arriving' => const Color(0xFFF97316),
      'at_pickup' => const Color(0xFF22C55E),
      'in_progress' => const Color(0xFF0EA5E9),
      'completed' => const Color(0xFF9CA3AF),
      'cancelled' => const Color(0xFFEF4444),
      _ => const Color(0xFFF97316),
    };
  }

  String get _statusLabel {
    return switch (trip.status) {
      'requested' => 'Solicitado',
      'searching' => 'Buscando',
      'accepted' => 'Aceptado',
      'arriving' => 'En camino',
      'at_pickup' => 'Llego',
      'in_progress' => 'En curso',
      'completed' => 'Finalizado',
      'cancelled' => 'Cancelado',
      _ => trip.status,
    };
  }

  IconData get _vehicleIcon {
    return (trip.vehicleType ?? '').toLowerCase() == 'moto'
        ? Icons.two_wheeler_rounded
        : Icons.local_taxi_rounded;
  }

  bool get _canChat {
    final phone = (trip.driverPhone ?? '').trim();
    return phone.isNotEmpty &&
        const {'accepted', 'arriving', 'at_pickup', 'in_progress'}.contains(trip.status);
  }

  bool get _canCancel {
    return const {'requested', 'searching', 'accepted', 'arriving', 'at_pickup'}.contains(trip.status);
  }

  String get _promoLabel => trip.status == 'completed' ? 'Viaje gratis aplicado' : 'Viaje promocional activo';

  String? _normalizeWhatsAppPhone(String? rawPhone) {
    final digits = (rawPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('591')) {
      return digits;
    }
    return '591$digits';
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final normalizedPhone = _normalizeWhatsAppPhone(trip.driverPhone);
    if (normalizedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay numero valido del conductor para WhatsApp.')),
      );
      return;
    }
    final driverName = (trip.driverName ?? '').trim().isEmpty ? 'conductor' : trip.driverName!.trim();
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent('Hola $driverName, te escribo por mi viaje de RAPIGO.')}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp en este momento.')),
      );
    }
  }

  Future<void> _cancelTrip(BuildContext context, WidgetRef ref) async {
    await ref.read(tripProvider.notifier).updateTripStatus(
          token: token,
          tripId: trip.id,
          status: 'cancelled',
        );
    if (context.mounted) {
      final error = ref.read(tripProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == null ? 'Viaje cancelado.' : error.replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  void _showDetails(BuildContext context) {
    final driverName = (trip.driverName ?? '').trim();
    final driverPhone = (trip.driverPhone ?? '').trim();
    final vehicleLabel = (trip.vehicleLabel ?? '').trim();
    final vehiclePlate = (trip.vehiclePlate ?? '').trim();
    final vehicleColor = (trip.vehicleColor ?? '').trim();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF121214),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0x55F97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Detalle del viaje',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFF4EC),
                      ),
                    ),
                    if (trip.isPromotional) ...[
                      const SizedBox(height: 12),
                      _HistoryBadge(
                        icon: Icons.card_giftcard_rounded,
                        label: _promoLabel,
                        color: const Color(0xFF22C55E),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _HistoryRouteRow(
                      icon: Icons.radio_button_checked_rounded,
                      label: 'Recojo',
                      value: trip.pickupAddress,
                      iconColor: const Color(0xFFF97316),
                    ),
                    const SizedBox(height: 12),
                    _HistoryRouteRow(
                      icon: Icons.location_on_rounded,
                      label: 'Destino',
                      value: trip.destinationAddress,
                      iconColor: const Color(0xFF22C55E),
                    ),
                    if (driverName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HistoryRouteRow(
                        icon: Icons.badge_outlined,
                        label: 'Conductor',
                        value: driverName,
                        iconColor: const Color(0xFFF97316),
                      ),
                    ],
                    if (driverPhone.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HistoryRouteRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefono',
                        value: driverPhone,
                        iconColor: const Color(0xFFF97316),
                      ),
                    ],
                    if (vehicleLabel.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HistoryRouteRow(
                        icon: _vehicleIcon,
                        label: 'Vehiculo',
                        value: vehicleLabel,
                        iconColor: const Color(0xFFF97316),
                      ),
                    ],
                    if (vehiclePlate.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HistoryRouteRow(
                        icon: Icons.pin_outlined,
                        label: 'Placa',
                        value: vehiclePlate,
                        iconColor: const Color(0xFFF97316),
                      ),
                    ],
                    if (vehicleColor.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _HistoryRouteRow(
                        icon: Icons.palette_outlined,
                        label: 'Color',
                        value: vehicleColor,
                        iconColor: const Color(0xFFF97316),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverName = (trip.driverName ?? '').trim();
    final driverPhone = (trip.driverPhone ?? '').trim();
    final vehicleLabel = (trip.vehicleLabel ?? '').trim();
    final vehiclePlate = (trip.vehiclePlate ?? '').trim();
    final vehicleColor = (trip.vehicleColor ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1F),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              gradient: LinearGradient(
                colors: [
                  _statusColor.withValues(alpha: 0.24),
                  const Color(0xFF232329),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_vehicleIcon, color: _statusColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF121214),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _statusColor.withValues(alpha: 0.26)),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ),
                      if (trip.isPromotional) ...[
                        const SizedBox(height: 10),
                        const _HistoryBadge(
                          icon: Icons.card_giftcard_rounded,
                          label: 'PROMO GRATIS',
                          color: Color(0xFF22C55E),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        trip.requestedAt.isEmpty ? 'Fecha no disponible' : trip.requestedAt,
                        style: const TextStyle(
                          color: Color(0xFFFFD8BF),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.pickupAddress} a ${trip.destinationAddress}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFF4EC),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HistoryBadge(icon: Icons.person_outline_rounded, label: passengerName),
                    if (driverName.isNotEmpty)
                      _HistoryBadge(icon: Icons.badge_outlined, label: driverName),
                    if (driverPhone.isNotEmpty)
                      _HistoryBadge(icon: Icons.phone_outlined, label: driverPhone),
                    if (vehicleLabel.isNotEmpty)
                      _HistoryBadge(icon: _vehicleIcon, label: vehicleLabel),
                    if (vehiclePlate.isNotEmpty)
                      _HistoryBadge(icon: Icons.pin_outlined, label: 'Placa $vehiclePlate'),
                    if (vehicleColor.isNotEmpty)
                      _HistoryBadge(icon: Icons.palette_outlined, label: vehicleColor),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25252B),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalle del recorrido',
                        style: TextStyle(
                          color: Color(0xFFFFD8BF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _HistoryRouteRow(
                        icon: Icons.radio_button_checked_rounded,
                        label: 'Recojo',
                        value: trip.pickupAddress,
                        iconColor: const Color(0xFFF97316),
                      ),
                      const SizedBox(height: 10),
                      _HistoryRouteRow(
                        icon: Icons.location_on_rounded,
                        label: 'Destino',
                        value: trip.destinationAddress,
                        iconColor: const Color(0xFF22C55E),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showDetails(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD8BF),
                        side: BorderSide(color: _statusColor.withValues(alpha: 0.32)),
                      ),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Detalle'),
                    ),
                    if (_canChat)
                      FilledButton.tonalIcon(
                        onPressed: () => _openWhatsApp(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3A2A),
                          foregroundColor: const Color(0xFFB6F5C8),
                        ),
                        icon: const Icon(Icons.chat_bubble_rounded),
                        label: const Text('WhatsApp'),
                      ),
                    if (_canCancel)
                      FilledButton.tonalIcon(
                        onPressed: () => _cancelTrip(context, ref),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3A1F1F),
                          foregroundColor: const Color(0xFFFFC9C9),
                        ),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({
    required this.icon,
    required this.label,
    this.color = const Color(0xFFF97316),
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color == const Color(0xFFF97316) ? const Color(0xFFFFF4EC) : color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRouteRow extends StatelessWidget {
  const _HistoryRouteRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9F978F),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFFF4EC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
