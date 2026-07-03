part of '../../home/driver_home_page.dart';

class _DriverOfferRoutePreviewPage extends ConsumerStatefulWidget {
  const _DriverOfferRoutePreviewPage({required this.trip});

  final DriverTrip trip;

  @override
  ConsumerState<_DriverOfferRoutePreviewPage> createState() =>
      _DriverOfferRoutePreviewPageState();
}

class _DriverOfferRoutePreviewPageState
    extends ConsumerState<_DriverOfferRoutePreviewPage> {
  int _mapFocusSignal = 0;
  bool _busy = false;
  bool _routeReviewed = false;

  double _distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadius = 6371000.0;
    final dLat = (endLat - startLat) * math.pi / 180;
    final dLng = (endLng - startLng) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(startLat * math.pi / 180) *
            math.cos(endLat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatEta(double meters) {
    final minutes = (meters / 320).clamp(1, 99).round();
    return '$minutes min';
  }

  LatLngBounds _buildBounds({
    required double driverLat,
    required double driverLng,
  }) {
    final points = <LatLng>[
      LatLng(driverLat, driverLng),
      LatLng(widget.trip.pickupLat, widget.trip.pickupLng),
    ];
    if (widget.trip.destinationLat != null && widget.trip.destinationLng != null) {
      points.add(LatLng(widget.trip.destinationLat!, widget.trip.destinationLng!));
    }
    final rawBounds = LatLngBounds.fromPoints(points);
    final latSpan = (rawBounds.north - rawBounds.south).abs();
    final lngSpan = (rawBounds.east - rawBounds.west).abs();
    final latPadding = latSpan < 0.0045 ? 0.0045 : latSpan * 0.34;
    final lngPadding = lngSpan < 0.0045 ? 0.0045 : lngSpan * 0.34;
    return LatLngBounds(
      LatLng(rawBounds.south - latPadding, rawBounds.west - lngPadding),
      LatLng(rawBounds.north + latPadding, rawBounds.east + lngPadding),
    );
  }

  Future<void> _reject() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.trip.isDirectedRequest) {
        await ref.read(driverOffersProvider.notifier).cancelDirectedOffer(widget.trip);
        await ref.read(offeredTripProvider.notifier).loadOffer();
        await ref.read(driverOffersProvider.notifier).loadOffers();
      } else {
        await ref.read(offeredTripProvider.notifier).clearTrip();
      }
      if (mounted) {
        showTopNotice(
          context,
          widget.trip.isDirectedRequest
              ? 'Solicitud cancelada para este conductor.'
              : 'Solicitud ignorada. Sigue visible en viajes disponibles.',
          tone: NoticeTone.info,
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _accept() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(widget.trip.id);
      await ref.read(offeredTripProvider.notifier).acceptTrip(widget.trip);
      ref.read(driverOffersProvider.notifier).removeOfferLocally(widget.trip.id);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DriverProgressPage(
            onClosed: () {
              ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(null);
            },
          ),
        ),
      );
    } catch (_) {
      ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(null);
      if (mounted) {
        showTopNotice(
          context,
          'No se pudo aceptar el viaje. Intenta nuevamente.',
          tone: NoticeTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showRouteFirst() async {
    if (_busy) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _routeReviewed = true);
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverStateProvider);
    final trip = widget.trip;
    final rejectLabel = trip.isDirectedRequest ? 'Cancelar' : 'Ignorar';
    final pickupDistance = _distanceMeters(
      startLat: driverState.lat,
      startLng: driverState.lng,
      endLat: trip.pickupLat,
      endLng: trip.pickupLng,
    );
    final destinationDistance =
        trip.destinationLat != null && trip.destinationLng != null
            ? _distanceMeters(
                startLat: trip.pickupLat,
                startLng: trip.pickupLng,
                endLat: trip.destinationLat!,
                endLng: trip.destinationLng!,
              )
            : 0.0;

    final passengerName =
        trip.passengerName?.trim().isNotEmpty == true ? trip.passengerName!.trim() : 'Pasajero';
    final phone = (trip.passengerPhone ?? '').trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) {
          return;
        }
        await _reject();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF040B16),
        body: Stack(
          children: [
            Positioned.fill(
              child: DriverMapSurface(
                viewportCacheKey: 'driver_offer_preview_${trip.id}',
                routePersistenceKey: 'driver_offer_preview_route_${trip.id}',
                available: driverState.available,
                tripAccepted: true,
                driverLat: driverState.lat,
                driverLng: driverState.lng,
                headingDegrees: driverState.headingDegrees,
                vehicleType: trip.vehicleType?.isNotEmpty == true
                    ? trip.vehicleType!
                    : ref.watch(driverSessionProvider).vehicleType,
                tripStatus: 'accepted',
                pickupLat: trip.pickupLat,
                pickupLng: trip.pickupLng,
                destinationLat: trip.destinationLat,
                destinationLng: trip.destinationLng,
                routeColor: const Color(0xFF2979FF),
                lockToFocusBounds: true,
                focusBounds: _buildBounds(
                  driverLat: driverState.lat,
                  driverLng: driverState.lng,
                ),
                focusSignal: _mapFocusSignal,
                onRouteUpdated: null,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xB2051120),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xD1040B16),
                      ],
                      stops: const [0, 0.16, 0.58, 1],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Row(
                      children: [
                        _DriverMapCircleButton(
                          icon: Icons.close_rounded,
                          onTap: _busy ? () {} : _reject,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xE60B1730),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: _routeReviewed
                                  ? const Color(0x334ADE80)
                                  : const Color(0x332979FF),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _routeReviewed ? Icons.alt_route_rounded : Icons.route_rounded,
                                color: _routeReviewed
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFF7DB7FF),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatEta(pickupDistance)} · ${_formatDistance(pickupDistance)}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _DriverMapCircleButton(
                          icon: Icons.my_location_rounded,
                          onTap: () {
                            setState(() => _mapFocusSignal++);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        color: const Color(0xF507101B),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0x22FFFFFF)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 30,
                            offset: Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF0E1A2C),
                                child: Text(
                                  passengerName.isNotEmpty ? passengerName[0].toUpperCase() : 'P',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFFFC400),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _routeReviewed
                                          ? 'Recorrido listo para aceptar'
                                          : 'Nueva solicitud de viaje',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: _routeReviewed
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF7DB7FF),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      passengerName,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1424),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0x18FFFFFF)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _PreviewStopTile(
                                    label: 'A · Recogida',
                                    title: trip.passengerPickup.trim().isNotEmpty
                                        ? trip.passengerPickup.trim()
                                        : 'Punto de recogida',
                                    meta:
                                        '${_formatDistance(pickupDistance)} · ${_formatEta(pickupDistance)}',
                                    accent: const Color(0xFF22C55E),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PreviewStopTile(
                                    label: 'B · Destino',
                                    title: trip.destination.trim().isNotEmpty
                                        ? trip.destination.trim()
                                        : 'Destino por confirmar',
                                    meta: trip.destinationLat != null && trip.destinationLng != null
                                        ? '${_formatDistance(destinationDistance)} · ${_formatEta(destinationDistance)}'
                                        : 'Sin punto final',
                                    accent: const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _routeReviewed
                                ? 'La ruta ya esta lista. Si confirmas, entras directo al flujo del viaje activo.'
                                : 'Primero revisa el recorrido completo con los puntos A y B. Luego podras aceptar el viaje.',
                            style: const TextStyle(
                              color: Color(0xFFB8C4D6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _reject,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(58),
                                    side: const BorderSide(color: Color(0x33FFFFFF)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    rejectLabel,
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : (_routeReviewed ? _accept : _showRouteFirst),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(58),
                                    backgroundColor: _routeReviewed
                                        ? const Color(0xFFFFC400)
                                        : const Color(0xFF2979FF),
                                    foregroundColor: const Color(0xFF08111F),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.4),
                                        )
                                      : Text(
                                          _routeReviewed ? 'Aceptar' : 'Recorrido',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

class _PreviewStopTile extends StatelessWidget {
  const _PreviewStopTile({
    required this.label,
    required this.title,
    required this.meta,
    required this.accent,
  });

  final String label;
  final String title;
  final String meta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1929),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
