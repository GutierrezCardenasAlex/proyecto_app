import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/theme/rapigo_theme.dart';
import '../../../../core/ui/top_notice.dart';
import '../../auth/data/auth_repository.dart';
import 'route_persistence_keys.dart';
import '../data/driver_repository.dart';
import '../home/driver_offer_preview_provider.dart';
import '../../map/presentation/driver_map_surface.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/driver_trip.dart';

class DriverProgressPage extends ConsumerStatefulWidget {
  const DriverProgressPage({super.key, required this.onClosed});

  final VoidCallback onClosed;

  @override
  ConsumerState<DriverProgressPage> createState() => _DriverProgressPageState();
}

class _DriverProgressPageState extends ConsumerState<DriverProgressPage> {
  static const _detailsExpandedPrefix = 'rapigo_driver_progress_details_v1_';
  bool _detailsExpanded = false;
  bool _didNotifyClosed = false;
  bool _isClosingToHome = false;
  bool _homePopScheduled = false;
  bool _isPreparingRoute = true;
  bool _showHomeReturnButton = false;
  double _closingOpacity = 0;
  String _closingMessage = 'Volviendo al mapa principal...';
  String? _restoredDetailsTripId;
  String? _routePreparedTripId;

  @override
  void dispose() {
    if (!_didNotifyClosed) {
      _didNotifyClosed = true;
      widget.onClosed();
    }
    super.dispose();
  }

  void _markRouteReady([String? tripId]) {
    if (!mounted) {
      return;
    }
    if (tripId != null) {
      _routePreparedTripId = tripId;
    }
    if (!_isPreparingRoute) {
      return;
    }
    setState(() => _isPreparingRoute = false);
  }

  void _ensureRoutePreparingForTrip(DriverTrip trip) {
    if (_routePreparedTripId == trip.id || _isClosingToHome) {
      return;
    }
    if (_isPreparingRoute) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isClosingToHome || _routePreparedTripId == trip.id) {
        return;
      }
      setState(() => _isPreparingRoute = true);
    });
  }

  Future<void> _restoreDetailsExpanded(String tripId) async {
    if (_restoredDetailsTripId == tripId) {
      return;
    }
    _restoredDetailsTripId = tripId;
    final preferences = await SharedPreferences.getInstance();
    final restored = preferences.getBool('$_detailsExpandedPrefix$tripId');
    if (!mounted || restored == null) {
      return;
    }
    setState(() => _detailsExpanded = restored);
  }

  Future<void> _persistDetailsExpanded(String tripId, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_detailsExpandedPrefix$tripId', value);
  }

  Future<void> _clearDetailsExpanded(String tripId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_detailsExpandedPrefix$tripId');
  }

  LatLngBounds? _buildDriverFocusBounds({
    required double driverLat,
    required double driverLng,
    DriverTrip? trip,
  }) {
    if (trip == null) {
      return null;
    }
    final driverPoint = LatLng(driverLat, driverLng);
    if (trip.status == 'in_progress' || trip.status == 'completed') {
      if (trip.destinationLat == null || trip.destinationLng == null) {
        return LatLngBounds.fromPoints([
          driverPoint,
          LatLng(trip.pickupLat, trip.pickupLng),
        ]);
      }
      return LatLngBounds.fromPoints([
        driverPoint,
        LatLng(trip.destinationLat!, trip.destinationLng!),
      ]);
    }
    return LatLngBounds.fromPoints([
      driverPoint,
      LatLng(trip.pickupLat, trip.pickupLng),
    ]);
  }

  double _distanceMeters(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '${meters.round()} m';
  }

  String _formatEtaFromMeters(double meters) {
    final minutes = (meters / 320).clamp(1, 99).round();
    return '$minutes min';
  }

  DateTime? _parseTripDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _formatClock(DateTime? value) {
    if (value == null) {
      return '--:--';
    }
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatTripDuration(DriverTrip trip) {
    final startedAt = _parseTripDate(trip.requestedAt);
    if (startedAt == null) {
      return '18 min';
    }
    final minutes = DateTime.now()
        .difference(startedAt)
        .inMinutes
        .clamp(1, 180);
    return '$minutes min';
  }

  String _primaryAddress(String raw) {
    final parts = raw.split(',');
    return parts.first.trim().isEmpty ? raw : parts.first.trim();
  }

  String _secondaryAddress(String raw) {
    final parts = raw.split(',');
    if (parts.length <= 1) {
      return raw;
    }
    return parts.skip(1).join(',').trim();
  }

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

  Future<void> _openPassengerWhatsApp(DriverTrip trip) async {
    final normalizedPhone = _normalizeWhatsAppPhone(trip.passengerPhone);
    if (normalizedPhone == null) {
      if (mounted) {
        showTopNotice(
          context,
          'Todavia no hay numero del pasajero para WhatsApp.',
        );
      }
      return;
    }
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'pasajero';
    final message = trip.status == 'at_pickup'
        ? 'Hola $passengerName, ya llegue al punto de recojo en RAPIGO PRO.'
        : 'Hola $passengerName, te escribo por tu viaje de RAPIGO PRO.';
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showTopNotice(context, 'No se pudo abrir WhatsApp en este momento.');
    }
  }

  Future<void> _callPassenger(DriverTrip trip) async {
    final phone = trip.passengerPhone?.trim() ?? '';
    if (phone.isEmpty) {
      if (mounted) {
        showTopNotice(
          context,
          'Todavia no hay numero del pasajero para llamar.',
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showTopNotice(context, 'No se pudo iniciar la llamada en este momento.');
    }
  }

  Future<void> _openPassengerActions(DriverTrip trip) async {
    if (!mounted) {
      return;
    }
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';
    final passengerPhone = trip.passengerPhone?.trim().isNotEmpty == true
        ? trip.passengerPhone!.trim()
        : 'Sin telefono';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF08111E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF020617).withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1D4ED8),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF111827),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              passengerName,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              passengerPhone,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _PassengerActionCard(
                          icon: Icons.call_rounded,
                          label: 'Llamar',
                          color: const Color(0xFF22C55E),
                          onTap: () {
                            Navigator.of(context).pop();
                            _callPassenger(trip);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PassengerActionCard(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.of(context).pop();
                            _openPassengerWhatsApp(trip);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (trip.status == 'completed') ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1627),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF22C55E),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recorrido completado con exito',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelTrip(DriverTrip trip) async {
    try {
      await ref
          .read(offeredTripProvider.notifier)
          .updateTripStatus('cancelled');
      await _clearDetailsExpanded(trip.id);
      await ref.read(offeredTripProvider.notifier).loadOffer();
      await _returnToHome();
    } catch (error) {
      if (mounted) {
        showTopNotice(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          tone: NoticeTone.error,
        );
      }
    }
  }

  Future<void> _returnToHome() async {
    if (_homePopScheduled || !mounted) {
      return;
    }
    _homePopScheduled = true;
    if (!_isClosingToHome) {
      setState(() {
        _isClosingToHome = true;
        _closingOpacity = 1;
        _closingMessage = 'Cargando inicio...';
      });
    }
    if (!_didNotifyClosed) {
      _didNotifyClosed = true;
      widget.onClosed();
    }
    if (mounted && _showHomeReturnButton) {
      setState(() => _showHomeReturnButton = false);
    }
    ref.read(driverHomeResumeOverlayProvider.notifier).showOnce();
    ref
        .read(driverSuppressIncomingOfferOverlayProvider.notifier)
        .suppressOnce();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _refreshHomeStateAfterClose() {
    final tripNotifier = ref.read(offeredTripProvider.notifier);
    final offersNotifier = ref.read(driverOffersProvider.notifier);
    unawaited(
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await tripNotifier.loadOffer();
        await offersNotifier.loadOffers();
      }),
    );
  }

  Future<void> _handlePrimaryAction(DriverTrip trip) async {
    if (trip.status == 'completed') {
      await _closeSummaryAndReturnHome();
      return;
    }

    try {
      if (trip.status == 'accepted') {
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('arriving');
        return;
      }
      if (trip.status == 'arriving') {
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('at_pickup');
        return;
      }
      if (trip.status == 'at_pickup') {
        final destinationLabel = trip.destination.trim().toLowerCase();
        final destinationMissing =
            trip.destinationLat == null ||
            trip.destinationLng == null ||
            destinationLabel.isEmpty ||
            destinationLabel == 'destino no esta marcado' ||
            destinationLabel == 'destino por confirmar' ||
            destinationLabel == 'abordaje inmediato';
        if (destinationMissing) {
          if (mounted) {
            showTopNotice(
              context,
              'El pasajero aun no guardo el destino final. Espera a que lo marque para iniciar el viaje.',
              tone: NoticeTone.warning,
            );
          }
          return;
        }
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('in_progress');
        return;
      }
      if (trip.status == 'in_progress') {
        await ref
            .read(offeredTripProvider.notifier)
            .updateTripStatus('completed');
        if (mounted) {
          setState(() => _detailsExpanded = true);
        }
        await _persistDetailsExpanded(trip.id, true);
      }
    } catch (error) {
      if (mounted) {
        showTopNotice(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          tone: NoticeTone.error,
        );
      }
    }
  }

  bool _canCancelTrip(DriverTrip trip) {
    return const {'accepted', 'arriving', 'at_pickup'}.contains(trip.status);
  }

  Future<void> _closeSummaryAndReturnHome() async {
    final tripId = ref.read(offeredTripProvider).value?.id;
    if (mounted) {
      setState(() {
        _isClosingToHome = true;
        _closingOpacity = 0;
        _closingMessage = 'Cargando inicio...';
        _showHomeReturnButton = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _closingOpacity = 1);
      }
    });
    if (tripId != null && tripId.isNotEmpty) {
      await _clearDetailsExpanded(tripId);
    }
    ref.read(driverOfferPreviewTripIdProvider.notifier).setTrip(null);
    ref
        .read(driverSuppressIncomingOfferOverlayProvider.notifier)
        .suppressOnce();
    ref.read(driverIgnoredIncomingTripIdProvider.notifier).ignore(tripId);
    ref.read(driverHomeResumeOverlayProvider.notifier).showOnce();
    if (tripId != null && tripId.isNotEmpty) {
      ref.read(driverOffersProvider.notifier).removeOfferLocally(tripId);
    }
    await ref.read(driverOffersProvider.notifier).clearOffers();
    await ref.read(offeredTripProvider.notifier).clearTrip();
    _refreshHomeStateAfterClose();
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _homePopScheduled) {
      return;
    }
    setState(() {
      _closingMessage = 'Viaje completado correctamente';
      _showHomeReturnButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(
      driverStateProvider.select((state) => state.available),
    );
    final driverLat = ref.watch(
      driverStateProvider.select((state) => state.lat),
    );
    final driverLng = ref.watch(
      driverStateProvider.select((state) => state.lng),
    );
    final driverHeading = ref.watch(
      driverStateProvider.select((state) => state.headingDegrees),
    );
    final tripAsync = ref.watch(offeredTripProvider);
    final trip = tripAsync.value;
    final session = ref.watch(driverSessionProvider);

    if (trip != null) {
      _ensureRoutePreparingForTrip(trip);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_restoreDetailsExpanded(trip.id));
        }
      });
    }

    if (_isClosingToHome || trip == null || trip.status == 'cancelled') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        if (!_isClosingToHome) {
          await _returnToHome();
        }
      });
      return Scaffold(
        backgroundColor: const Color(0xFF040B17),
        body: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          opacity: _closingOpacity,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF08111E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF020617).withValues(alpha: 0.5),
                    blurRadius: 26,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _closingMessage,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_showHomeReturnButton) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _returnToHome,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Ir al inicio',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final routeColor =
        trip.status == 'in_progress' || trip.status == 'completed'
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF2563EB);
    final focusBounds = _buildDriverFocusBounds(
      driverLat: driverLat,
      driverLng: driverLng,
      trip: trip,
    );
    final pickupDistance = _distanceMeters(
      LatLng(driverLat, driverLng),
      LatLng(trip.pickupLat, trip.pickupLng),
    );
    final destinationDistance =
        trip.destinationLat != null && trip.destinationLng != null
        ? _distanceMeters(
            LatLng(trip.pickupLat, trip.pickupLng),
            LatLng(trip.destinationLat!, trip.destinationLng!),
          )
        : 0.0;
    final destinationDistanceLabel =
        trip.destinationLat != null && trip.destinationLng != null
        ? _formatDistance(destinationDistance)
        : '--';
    final destinationEtaLabel =
        trip.destinationLat != null && trip.destinationLng != null
        ? _formatEtaFromMeters(destinationDistance)
        : '--';
    final showSummaryOnly = trip.status == 'completed';
    final showDetailsModal = _detailsExpanded || showSummaryOnly;
    final showCompactPanel = !showSummaryOnly;
    final isPickupStage =
        trip.status == 'accepted' ||
        trip.status == 'arriving' ||
        trip.status == 'at_pickup';
    final navigationDistanceLabel = isPickupStage
        ? _formatDistance(pickupDistance)
        : destinationDistanceLabel;
    final navigationEtaLabel = isPickupStage
        ? _formatEtaFromMeters(pickupDistance)
        : destinationEtaLabel;
    final navigationTitle = isPickupStage
        ? _primaryAddress(trip.passengerPickup)
        : _primaryAddress(trip.destination);
    final navigationSubtitle = isPickupStage
        ? _secondaryAddress(trip.passengerPickup)
        : _secondaryAddress(trip.destination);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !mounted) {
          return;
        }
        if (trip.status == 'completed') {
          showTopNotice(
            context,
            'Falta presionar COMPLETAR para volver al inicio.',
            tone: NoticeTone.warning,
          );
          return;
        }
        showTopNotice(
          context,
          'Debes terminar el flujo del viaje antes de salir de esta vista.',
          tone: NoticeTone.warning,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF040B17),
        body: Stack(
          children: [
            Positioned.fill(
              child: DriverMapSurface(
                viewportCacheKey: 'driver_shared_premium_map',
                routePersistenceKey: 'driver_trip_route_${trip.id}',
                routePersistenceReadKeys: driverTripRouteReadKeys(
                  trip.id,
                  trip.status,
                ),
                routePersistenceWriteKeys: driverTripRouteWriteKeys(
                  trip.id,
                  trip.status,
                ),
                prefetchRoutePersistenceKey: driverTripRoutePrefetchKey(
                  trip.id,
                  trip.status,
                ),
                available: available,
                tripAccepted: true,
                driverLat: driverLat,
                driverLng: driverLng,
                headingDegrees: driverHeading,
                vehicleType: (trip.vehicleType?.isNotEmpty ?? false)
                    ? trip.vehicleType!
                    : session.vehicleType,
                tripStatus: trip.status,
                pickupLat: trip.pickupLat,
                pickupLng: trip.pickupLng,
                destinationLat: trip.destinationLat,
                destinationLng: trip.destinationLng,
                routeColor: routeColor,
                focusBounds: focusBounds,
                focusSignal: 0,
                showStatusBadge: false,
                onRouteUpdated: () => _markRouteReady(trip.id),
                onOfflineRouteRetained: () {
                  _markRouteReady(trip.id);
                  if (!mounted) {
                    return;
                  }
                  showTopNotice(
                    context,
                    'Modo offline activo. La ruta del viaje sigue trazada.',
                    tone: NoticeTone.info,
                    compact: true,
                    centered: true,
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xF40B1220),
                    foregroundColor: const Color(0xFFF8FAFC),
                  );
                },
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
                        const Color(0xFF020617).withValues(alpha: 0.72),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFF020617).withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isPreparingRoute && !_isClosingToHome)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF040B17).withValues(alpha: 0.62),
                    ),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 22,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF08111E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF1E293B)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF020617,
                              ).withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cargando ruta del viaje...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: [
                    _DriverNavigationHeader(
                      distanceLabel: navigationDistanceLabel,
                      title: navigationTitle,
                      subtitle: navigationSubtitle,
                      pickupStage: isPickupStage,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            if (showCompactPanel) ...[
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: _DriverNavigationCompactDrawer(
                    key: ValueKey('compact-${trip.status}'),
                    trip: trip,
                    statusLabel: available ? 'Conectado' : 'Desconectado',
                    etaLabel: navigationEtaLabel,
                    distanceLabel: navigationDistanceLabel,
                    detailsExpanded: showDetailsModal,
                    onExpand: () {
                      final nextValue = !_detailsExpanded;
                      setState(() => _detailsExpanded = nextValue);
                      unawaited(_persistDetailsExpanded(trip.id, nextValue));
                    },
                    onPrimary: (tripAsync.isLoading || _isPreparingRoute)
                        ? null
                        : () => _handlePrimaryAction(trip),
                  ),
                ),
              ),
            ],
            Positioned(
              left: 20,
              right: 20,
              bottom: showSummaryOnly ? 16 : 132,
              child: SafeArea(
                top: false,
                child: IgnorePointer(
                  ignoring: !showDetailsModal,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    offset: showDetailsModal
                        ? Offset.zero
                        : Offset(0, showSummaryOnly ? 0.18 : 0.12),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: showDetailsModal ? 1 : 0,
                      child: _DriverTripFlowPanel(
                        trip: trip,
                        driverPoint: LatLng(driverLat, driverLng),
                        onPrimary: tripAsync.isLoading
                            ? null
                            : () => _handlePrimaryAction(trip),
                        onSecondary: _canCancelTrip(trip)
                            ? () => _cancelTrip(trip)
                            : null,
                        onCall: () => _callPassenger(trip),
                        onChat: () => _openPassengerWhatsApp(trip),
                        onMore: () => _openPassengerActions(trip),
                        pickupDistanceLabel: _formatDistance(pickupDistance),
                        pickupEtaLabel: _formatEtaFromMeters(pickupDistance),
                        destinationDistanceLabel:
                            trip.destinationLat != null &&
                                trip.destinationLng != null
                            ? _formatDistance(destinationDistance)
                            : '--',
                        destinationEtaLabel:
                            trip.destinationLat != null &&
                                trip.destinationLng != null
                            ? _formatEtaFromMeters(destinationDistance)
                            : '--',
                        totalDistanceLabel:
                            trip.destinationLat != null &&
                                trip.destinationLng != null
                            ? _formatDistance(
                                _distanceMeters(
                                  LatLng(trip.pickupLat, trip.pickupLng),
                                  LatLng(
                                    trip.destinationLat!,
                                    trip.destinationLng!,
                                  ),
                                ),
                              )
                            : '--',
                        totalDurationLabel: _formatTripDuration(trip),
                        pickupTitle: _primaryAddress(trip.passengerPickup),
                        pickupSubtitle: _secondaryAddress(trip.passengerPickup),
                        destinationTitle: _primaryAddress(trip.destination),
                        destinationSubtitle: _secondaryAddress(
                          trip.destination,
                        ),
                        pickupClockLabel: _formatClock(
                          _parseTripDate(trip.requestedAt),
                        ),
                        onCloseSummary: trip.status == 'completed'
                            ? _closeSummaryAndReturnHome
                            : null,
                        onCollapse: trip.status == 'completed'
                            ? null
                            : () {
                                setState(() => _detailsExpanded = false);
                                unawaited(
                                  _persistDetailsExpanded(trip.id, false),
                                );
                              },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverNavigationHeader extends StatelessWidget {
  const _DriverNavigationHeader({
    required this.distanceLabel,
    required this.title,
    required this.subtitle,
    required this.pickupStage,
  });

  final String distanceLabel;
  final String title;
  final String subtitle;
  final bool pickupStage;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: palette.surfacePrimary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.outlineSoft),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              pickupStage ? Icons.turn_left_rounded : Icons.flag_circle_rounded,
              color: Colors.white,
              size: 54,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distanceLabel,
                  style: textTheme.headlineSmall?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: palette.accentBlueSoft,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
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
    );
  }
}

class _DriverNavigationCompactDrawer extends StatelessWidget {
  const _DriverNavigationCompactDrawer({
    super.key,
    required this.trip,
    required this.statusLabel,
    required this.etaLabel,
    required this.distanceLabel,
    required this.detailsExpanded,
    required this.onExpand,
    required this.onPrimary,
  });

  final DriverTrip trip;
  final String statusLabel;
  final String etaLabel;
  final String distanceLabel;
  final bool detailsExpanded;
  final VoidCallback onExpand;
  final VoidCallback? onPrimary;

  bool get _isAccepted => trip.status == 'accepted';
  bool get _isArriving => trip.status == 'arriving';
  bool get _isAtPickup => trip.status == 'at_pickup';
  bool get _isInProgress => trip.status == 'in_progress';

  String get _primaryLabel {
    if (_isAccepted) return 'IR AHORA';
    if (_isArriving) return 'CONFIRMAR LLEGADA';
    if (_isAtPickup) return 'INICIAR VIAJE';
    if (_isInProgress) return 'FINALIZAR VIAJE';
    return 'CONTINUAR';
  }

  Color get _primaryColor {
    if (_isAtPickup || _isInProgress) return const Color(0xFF22C55E);
    return const Color(0xFF38BDF8);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: palette.surfacePrimary.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(metrics.radiusLarge),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radiusLarge),
          border: Border.all(color: palette.outlineSoft),
          boxShadow: [
            BoxShadow(
              color: palette.shadowSoft,
              blurRadius: 26,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 6,
              decoration: BoxDecoration(
                color: palette.textMuted.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _CompactRoundButton(
                  icon: detailsExpanded
                      ? Icons.close_rounded
                      : Icons.menu_rounded,
                  onTap: onExpand,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        etaLabel,
                        style: textTheme.headlineSmall?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$distanceLabel • $statusLabel',
                        style: textTheme.bodyLarge?.copyWith(
                          color: palette.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const _CompactRoundButton(icon: Icons.alt_route_rounded),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPrimary,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: _isAccepted || _isArriving
                      ? const Color(0xFF031018)
                      : Colors.white,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _primaryLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRoundButton extends StatelessWidget {
  const _CompactRoundButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    return Material(
      color: palette.surfaceSecondary,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 58,
          child: Icon(icon, color: palette.textPrimary, size: 28),
        ),
      ),
    );
  }
}

class _DriverTripFlowPanel extends StatelessWidget {
  const _DriverTripFlowPanel({
    required this.trip,
    required this.driverPoint,
    required this.onPrimary,
    required this.onSecondary,
    required this.onCall,
    required this.onChat,
    required this.onMore,
    required this.pickupDistanceLabel,
    required this.pickupEtaLabel,
    required this.destinationDistanceLabel,
    required this.destinationEtaLabel,
    required this.totalDistanceLabel,
    required this.totalDurationLabel,
    required this.pickupTitle,
    required this.pickupSubtitle,
    required this.destinationTitle,
    required this.destinationSubtitle,
    this.pickupClockLabel,
    this.onCloseSummary,
    this.onCollapse,
  });

  final DriverTrip trip;
  final LatLng driverPoint;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onMore;
  final String pickupDistanceLabel;
  final String pickupEtaLabel;
  final String destinationDistanceLabel;
  final String destinationEtaLabel;
  final String totalDistanceLabel;
  final String totalDurationLabel;
  final String pickupTitle;
  final String pickupSubtitle;
  final String destinationTitle;
  final String destinationSubtitle;
  final String? pickupClockLabel;
  final VoidCallback? onCloseSummary;
  final VoidCallback? onCollapse;

  bool get _isRequest => const {'requested', 'searching'}.contains(trip.status);
  bool get _isAccepted => trip.status == 'accepted';
  bool get _isArriving => trip.status == 'arriving';
  bool get _isAtPickup => trip.status == 'at_pickup';
  bool get _isInProgress => trip.status == 'in_progress';
  bool get _isCompleted => trip.status == 'completed';

  double get _distanceToDestinationMeters {
    if (trip.destinationLat == null || trip.destinationLng == null) {
      return 999999;
    }
    return const Distance().as(
      LengthUnit.Meter,
      driverPoint,
      LatLng(trip.destinationLat!, trip.destinationLng!),
    );
  }

  bool get _isNearDestination => _distanceToDestinationMeters <= 450;

  String get _secondaryRequestLabel => 'Ignorar';

  IconData get _headlineIcon {
    if (_isRequest) return Icons.access_time_rounded;
    if (_isAccepted) return Icons.check_circle_outline_rounded;
    if (_isArriving) return Icons.directions_car_filled_rounded;
    if (_isAtPickup) return Icons.verified_rounded;
    if (_isCompleted) return Icons.receipt_long_rounded;
    return _isNearDestination
        ? Icons.task_alt_rounded
        : Icons.play_circle_outline_rounded;
  }

  Color get _headlineColor {
    if (_isRequest) return const Color(0xFFFACC15);
    if (_isCompleted) return const Color(0xFF22C55E);
    if (_isAtPickup) return const Color(0xFF22C55E);
    return const Color(0xFF22C55E);
  }

  String get _headlineTitle {
    if (_isRequest) return 'Nueva solicitud de viaje';
    if (_isAccepted) return 'Viaje aceptado';
    if (_isArriving) return 'En camino al pasajero';
    if (_isAtPickup) return 'Llegaste al pasajero';
    if (_isCompleted) return 'Resumen del viaje';
    return _isNearDestination ? 'Finalizar viaje' : 'Viaje iniciado';
  }

  String get _headlineSubtitle {
    if (_isRequest) return 'Tienes una nueva solicitud disponible';
    if (_isAccepted) return 'Dirigete al punto de recogida';
    if (_isArriving) {
      return 'Llegada estimada en $pickupEtaLabel ($pickupDistanceLabel)';
    }
    if (_isAtPickup) return 'Espera a que el pasajero suba al vehiculo';
    if (_isCompleted) return 'Gracias por elegir nuestro servicio';
    return _isNearDestination
        ? 'Estas llegando al destino'
        : 'El viaje ha comenzado';
  }

  String get _statusLabel {
    switch (trip.status) {
      case 'requested':
        return 'Solicitud';
      case 'accepted':
        return 'Aceptado';
      case 'arriving':
        return 'En camino';
      case 'at_pickup':
        return 'En recojo';
      case 'in_progress':
        return 'En viaje';
      case 'completed':
        return 'Finalizado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Activo';
    }
  }

  String get _primaryLabel {
    if (_isRequest) return 'Aceptar';
    if (_isAccepted) return 'NAVEGAR';
    if (_isArriving) return 'LLEGUE AL PUNTO\nDE RECOGIDA';
    if (_isAtPickup) return 'INICIAR VIAJE';
    if (_isCompleted) return 'LISTO';
    return 'FINALIZAR VIAJE';
  }

  Color get _primaryColor {
    if (_isRequest) return const Color(0xFFFACC15);
    if (_isAtPickup || _isInProgress) return const Color(0xFF22C55E);
    return const Color(0xFF2563EB);
  }

  Widget _buildMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationLine({
    required Color color,
    required String label,
    required String title,
    required String subtitle,
    String? trailingTop,
    String? trailingBottom,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (label != 'Destino')
              Container(width: 2, height: 54, color: const Color(0xFF374151)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (trailingTop != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailingTop,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (trailingBottom != null) ...[
                const SizedBox(height: 4),
                Text(
                  trailingBottom,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    final passengerName = trip.passengerName?.trim().isNotEmpty == true
        ? trip.passengerName!.trim()
        : 'Pasajero';
    final vehicleLabel = (trip.vehicleType ?? 'taxi').toUpperCase();

    return Material(
      color: palette.surfacePrimary.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(metrics.radiusLarge + 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(metrics.radiusLarge + 4),
          border: Border.all(color: palette.outlineStrong),
          boxShadow: [
            BoxShadow(
              color: palette.shadowSoft,
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                Container(
                  width: 64,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF35516E), Color(0xFF667A92)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(_headlineIcon, color: _headlineColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headlineTitle,
                              style: textTheme.titleLarge?.copyWith(
                                color: _headlineColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _headlineSubtitle,
                              style: textTheme.bodyMedium?.copyWith(
                                color: palette.textMuted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (onCollapse != null && !_isCompleted) ...[
                  Material(
                    color: palette.surfaceSecondary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onCollapse,
                      child: const SizedBox(
                        width: 54,
                        height: 54,
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (_isRequest)
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.accentYellow, width: 5),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  )
                else ...[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: palette.surfaceInteractive,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.accentBlue, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF111827),
                      size: 34,
                    ),
                  ),
                  if (!_isCompleted) ...[
                    const SizedBox(width: 12),
                    Material(
                      color: palette.surfaceSecondary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onCall,
                        child: const SizedBox(
                          width: 58,
                          height: 58,
                          child: Icon(Icons.call_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFF111827), size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.passengerPhone?.trim().isNotEmpty == true
                            ? trip.passengerPhone!.trim()
                            : 'Sin telefono',
                        style: textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _MiniAction(
                  icon: Icons.more_horiz_rounded,
                  label: 'Mas',
                  onTap: onMore,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: palette.outlineStrong),
            const SizedBox(height: 12),
            _buildLocationLine(
              color: const Color(0xFF22C55E),
              label: 'Punto de recogida',
              title: pickupTitle,
              subtitle: pickupSubtitle,
              trailingTop: _isCompleted
                  ? (pickupClockLabel ?? '--:--')
                  : pickupDistanceLabel,
              trailingBottom: _isCompleted ? null : pickupEtaLabel,
            ),
            const SizedBox(height: 12),
            if (_isInProgress && !_isNearDestination) ...[
              _buildLocationLine(
                color: const Color(0xFF1D4ED8),
                label: 'En camino',
                title: 'Recogiendo pasajero',
                subtitle: '',
              ),
              const SizedBox(height: 12),
            ],
            if (_isNearDestination && _isInProgress) ...[
              _buildLocationLine(
                color: const Color(0xFF1D4ED8),
                label: 'Recogido',
                title: '',
                subtitle: '',
                trailingTop: pickupClockLabel ?? '--:--',
              ),
              const SizedBox(height: 12),
            ],
            _buildLocationLine(
              color: const Color(0xFFEF4444),
              label: 'Destino',
              title: destinationTitle,
              subtitle: destinationSubtitle,
              trailingTop: _isCompleted
                  ? 'Finalizado'
                  : destinationDistanceLabel,
              trailingBottom: _isCompleted ? null : destinationEtaLabel,
            ),
            const SizedBox(height: 14),
            Divider(color: palette.outlineStrong),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMetric(
                  icon: Icons.local_taxi_rounded,
                  color: const Color(0xFFFACC15),
                  label: 'Tipo de servicio',
                  value: vehicleLabel,
                ),
                _buildMetric(
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF22C55E),
                  label: 'Estado',
                  value: _statusLabel,
                ),
              ],
            ),
            if (_isCompleted) ...[
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF1F2937)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetric(
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF3B82F6),
                    label: 'Duracion del viaje',
                    value: totalDurationLabel,
                  ),
                  _buildMetric(
                    icon: Icons.route_rounded,
                    color: const Color(0xFF22C55E),
                    label: 'Distancia recorrida',
                    value: totalDistanceLabel,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09111F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Viaje completado correctamente',
                              style: TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (!_isCompleted)
              Row(
                children: [
                  if (onSecondary != null) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: onSecondary,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B2430),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _isRequest
                              ? _secondaryRequestLabel
                              : 'CANCELAR VIAJE',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: _isRequest
                            ? const Color(0xFF111827)
                            : Colors.white,
                        minimumSize: const Size.fromHeight(60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        _primaryLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCloseSummary,
                  icon: const Icon(Icons.check_circle_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: const Color(0xFF04111E),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  label: const Text(
                    'COMPLETAR',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverSlideAction extends StatefulWidget {
  const _DriverSlideAction({
    required this.color,
    required this.label,
    required this.onCompleted,
  });

  final Color color;
  final String label;
  final VoidCallback? onCompleted;

  @override
  State<_DriverSlideAction> createState() => _DriverSlideActionState();
}

class _DriverSlideActionState extends State<_DriverSlideAction> {
  double _dragRatio = 0;
  bool _isCompleting = false;
  bool _flashVisible = false;

  Future<void> _handleEnd() async {
    if (_isCompleting) {
      return;
    }
    if (_dragRatio >= 0.82) {
      setState(() {
        _isCompleting = true;
        _dragRatio = 1;
        _flashVisible = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) {
        return;
      }
      widget.onCompleted?.call();
    }
    if (mounted) {
      setState(() {
        _dragRatio = 0;
        _isCompleting = false;
        _flashVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 110.0;
        final trackWidth = constraints.maxWidth;
        final maxTravel = (trackWidth - knobSize).clamp(0.0, double.infinity);
        final knobLeft = maxTravel * _dragRatio;

        return GestureDetector(
          onHorizontalDragUpdate: widget.onCompleted == null || _isCompleting
              ? null
              : (details) {
                  setState(() {
                    _dragRatio = (_dragRatio + (details.delta.dx / maxTravel))
                        .clamp(0.0, 1.0);
                  });
                },
          onHorizontalDragEnd: widget.onCompleted == null
              ? null
              : (_) => _handleEnd(),
          onHorizontalDragCancel: widget.onCompleted == null
              ? null
              : _handleEnd,
          child: Container(
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1320),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF243244)),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _flashVisible ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.color.withValues(alpha: 0.28),
                            widget.color.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.18),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: widget.color,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Desliza para confirmar',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      '>>>',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.34),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: _isCompleting
                      ? const Duration(milliseconds: 180)
                      : const Duration(milliseconds: 80),
                  curve: Curves.easeOutCubic,
                  left: knobLeft,
                  top: 9,
                  bottom: 9,
                  child: AnimatedContainer(
                    duration: _isCompleting
                        ? const Duration(milliseconds: 180)
                        : const Duration(milliseconds: 120),
                    width: knobSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.34),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.double_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2430),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2B3440)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerActionCard extends StatelessWidget {
  const _PassengerActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101927),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
