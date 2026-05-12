import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/admin_center/admin_center_repository.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/ui/top_notice.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../trip/data/trip_repository.dart';
import '../../../trip/domain/driver_trip.dart';
import '../widgets/driver_ui_kit.dart';

class DriverProfilePage extends ConsumerStatefulWidget {
  const DriverProfilePage({super.key});

  @override
  ConsumerState<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends ConsumerState<DriverProfilePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _licenseController;
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _colorController;
  late final TextEditingController _yearController;
  String _vehicleType = 'taxi';
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    final session = ref.read(driverSessionProvider);
    _firstNameController = TextEditingController(text: session.firstName);
    _lastNameController = TextEditingController(text: session.lastName);
    _emailController = TextEditingController(text: session.email);
    _addressController = TextEditingController(text: session.address);
    _licenseController = TextEditingController();
    _plateController = TextEditingController();
    _brandController = TextEditingController();
    _modelController = TextEditingController();
    _colorController = TextEditingController();
    _yearController = TextEditingController();
    _vehicleType = session.vehicleType;
    Future<void>.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = ref.read(driverSessionProvider);
    if (!session.loggedIn || session.token.isEmpty || session.userId.isEmpty) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
      return;
    }

    try {
      final details = await ref.read(authRepositoryProvider).fetchDriverProfile(
            token: session.token,
            userId: session.userId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseController.text = details.licenseNumber;
        _plateController.text = details.plate;
        _brandController.text = details.brand;
        _modelController.text = details.model;
        _colorController.text = details.color;
        _yearController.text = details.year?.toString() ?? '';
        _vehicleType = details.vehicleType.isEmpty ? _vehicleType : details.vehicleType;
        _isFetching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final session = ref.read(driverSessionProvider);
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _licenseController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty ||
        _brandController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        _colorController.text.trim().isEmpty) {
      showTopNotice(
        context,
        'Completa todos los datos obligatorios del conductor y del vehiculo.',
        backgroundColor: const Color(0xFF93000A),
      );
      return;
    }

    await ref.read(driverSessionProvider.notifier).completeProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          vehicleType: _vehicleType,
          plate: _plateController.text.trim().toUpperCase(),
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          color: _colorController.text.trim(),
          year: int.tryParse(_yearController.text.trim()),
        );

    if (!mounted) {
      return;
    }

    final updatedSession = ref.read(driverSessionProvider);
    if (updatedSession.errorMessage != null && updatedSession.errorMessage!.isNotEmpty) {
      showTopNotice(
        context,
        updatedSession.errorMessage!,
        backgroundColor: const Color(0xFF93000A),
      );
      return;
    }

    showTopNotice(
      context,
      'Actualizaste tus datos correctamente.',
      backgroundColor: const Color(0xFFF97316),
      foregroundColor: const Color(0xFF0F0F10),
    );

    if (updatedSession.vehicleType != _vehicleType) {
      setState(() => _vehicleType = updatedSession.vehicleType);
    }

    if (session.userId == updatedSession.userId) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);

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
                color: const Color(0xFF1B1B1F),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF2C2C31)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A31),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.person, size: 44, color: Color(0xFFFFF4EC)),
                  ),
                  const SizedBox(height: 18),
                  Text(
        session.fullName.isEmpty ? 'Conductor Flash Go' : session.fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.phone,
                    style: const TextStyle(
                      color: Color(0xFFFFC89B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x33F97316),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'DATOS EDITABLES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Color(0xFFFFC89B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1F),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF2C2C31)),
              ),
              child: _isFetching
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFF97316)),
                      ),
                    )
                  : Column(
                      children: [
                        _ProfileField(label: 'Nombre', controller: _firstNameController),
                        _ProfileField(label: 'Apellido', controller: _lastNameController),
                        _ProfileField(
                          label: 'Correo',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        _ProfileField(
                          label: 'Direccion',
                          controller: _addressController,
                          maxLines: 2,
                        ),
                        _ProfileField(label: 'Licencia', controller: _licenseController),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tipo de vehiculo',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFC89B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'taxi',
                              icon: Icon(Icons.directions_car_filled_rounded),
                              label: Text('Taxi'),
                            ),
                            ButtonSegment<String>(
                              value: 'moto',
                              icon: Icon(Icons.two_wheeler_rounded),
                              label: Text('Moto'),
                            ),
                          ],
                          selected: {_vehicleType},
                          onSelectionChanged: (selection) {
                            setState(() => _vehicleType = selection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        _ProfileField(
                          label: 'Placa',
                          controller: _plateController,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        _ProfileField(label: 'Marca', controller: _brandController),
                        _ProfileField(label: 'Modelo', controller: _modelController),
                        _ProfileField(label: 'Color', controller: _colorController),
                        _ProfileField(
                          label: 'Ano',
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: session.isLoading ? null : _saveProfile,
                            icon: session.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(session.isLoading ? 'Guardando...' : 'Guardar cambios'),
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
    return _DetailScaffold(
      title: 'Configuraciones',
      child: DriverPageShell(
        eyebrow: 'Preferencias',
        title: 'Configuraciones',
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C31)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mapa offline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Descarga o actualiza Potosi ciudad para mantener el mapa listo aun con señal baja.',
                    style: TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showOfflineMapSheet(context),
                      icon: const Icon(Icons.download_for_offline_rounded),
                      label: const Text('Abrir mapa offline'),
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

class DriverNotificationsPage extends ConsumerWidget {
  const DriverNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(driverSessionProvider);
    final repository = const AdminCenterRepository();

    return _DetailScaffold(
      title: 'Notificaciones',
      child: FutureBuilder<List<AdminNotificationItem>>(
        future: session.token.isEmpty ? Future.value(const <AdminNotificationItem>[]) : repository.fetchNotifications(session.token),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <AdminNotificationItem>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: CircularProgressIndicator(),
            ));
          }

          return DriverPageShell(
            eyebrow: 'Bandeja',
            title: 'Notificaciones',
            child: Column(
              children: [
                if (items.isEmpty)
                  const _DriverSettingsInfoCard(
                    title: 'Sin avisos nuevos',
                    subtitle: 'Las notificaciones de central, autorizaciones y comunicados apareceran aqui.',
                  ),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DriverMenuTile(
                      icon: Icons.notifications_active_outlined,
                      title: item.title,
                      subtitle: '${item.message}\n${_formatShortDate(item.createdAt)}',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DriverSupportPage extends ConsumerStatefulWidget {
  const DriverSupportPage({super.key});

  @override
  ConsumerState<DriverSupportPage> createState() => _DriverSupportPageState();
}

class _DriverSupportPageState extends ConsumerState<DriverSupportPage> {
  final _messageController = TextEditingController();
  String _category = 'Falla de app';
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);
    final repository = const AdminCenterRepository();

    return _DetailScaffold(
      title: 'Soporte',
      child: FutureBuilder<List<SupportReportItem>>(
        future: session.token.isEmpty ? Future.value(const <SupportReportItem>[]) : repository.fetchSupportReports(session.token),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <SupportReportItem>[];
          return DriverPageShell(
            eyebrow: 'Soporte',
            title: 'Reporta un problema',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1F),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2C2C31)),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        dropdownColor: const Color(0xFF1B1B1F),
                        decoration: const InputDecoration(labelText: 'Tipo de reporte'),
                        items: const [
                          DropdownMenuItem(value: 'Falla de app', child: Text('Falla de app')),
                          DropdownMenuItem(value: 'Problema con viaje', child: Text('Problema con viaje')),
                          DropdownMenuItem(value: 'Cuenta o acceso', child: Text('Cuenta o acceso')),
                          DropdownMenuItem(value: 'Mapa o GPS', child: Text('Mapa o GPS')),
                        ],
                        onChanged: (value) => setState(() => _category = value ?? 'Falla de app'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Detalle del problema',
                          hintText: 'Describe lo que pasó para que central pueda ayudarte mejor.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending
                              ? null
                              : () async {
                                  if (_messageController.text.trim().length < 8) {
                                    showTopNotice(
                                      context,
                                      'Describe mejor el problema para enviarlo a central.',
                                      backgroundColor: const Color(0xFF93000A),
                                    );
                                    return;
                                  }
                                  setState(() => _sending = true);
                                  try {
                                    await repository.submitSupportReport(
                                      token: session.token,
                                      category: _category,
                                      message: _messageController.text.trim(),
                                    );
                                    _messageController.clear();
                                    if (!context.mounted) return;
                                    setState(() {});
                                    showTopNotice(
                                      context,
                                      'Reporte enviado correctamente a central.',
                                      backgroundColor: const Color(0xFFF97316),
                                      foregroundColor: const Color(0xFF0F0F10),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    showTopNotice(
                                      context,
                                      error.toString().replaceFirst('Exception: ', ''),
                                      backgroundColor: const Color(0xFF93000A),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _sending = false);
                                    }
                                  }
                                },
                          icon: const Icon(Icons.send_rounded),
                          label: Text(_sending ? 'Enviando...' : 'Enviar reporte'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (reports.isEmpty)
                  const _DriverSettingsInfoCard(
                    title: 'Sin reportes todavía',
                    subtitle: 'Cuando envíes un reporte desde aquí, central podrá verlo con tus datos del conductor.',
                  ),
                ...reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DriverMenuTile(
                      icon: Icons.support_agent,
                      title: '${report.category} · ${report.status}',
                      subtitle: '${report.message}\n${_formatShortDate(report.createdAt)}',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DriverStatisticsPage extends ConsumerStatefulWidget {
  const DriverStatisticsPage({super.key});

  @override
  ConsumerState<DriverStatisticsPage> createState() => _DriverStatisticsPageState();
}

class _DriverStatisticsPageState extends ConsumerState<DriverStatisticsPage> {
  String _range = 'Dia';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(driverTripHistoryProvider).value ?? const <DriverTrip>[];
    final now = DateTime.now();
    final filtered = history.where((trip) {
      final date = DateTime.tryParse(trip.requestedAt ?? '');
      if (date == null) {
        return false;
      }
      final local = date.toLocal();
      if (_range == 'Dia') {
        return local.year == now.year && local.month == now.month && local.day == now.day;
      }
      if (_range == 'Semana') {
        return now.difference(local).inDays < 7;
      }
      return local.year == now.year && local.month == now.month;
    }).toList(growable: false);

    final completed = filtered.where((trip) => trip.status == 'completed').length;
    final promoTrips = filtered.where((trip) => trip.isPromotional).length;
    final estimatedRevenue = filtered
        .where((trip) => trip.status == 'completed' && !trip.isPromotional)
        .fold<double>(0, (sum, trip) => sum + trip.fareAmount);

    return _DetailScaffold(
      title: 'Estadistica',
      child: DriverPageShell(
        eyebrow: 'Rendimiento',
        title: 'Estadistica',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Dia', label: Text('Dia')),
                ButtonSegment(value: 'Semana', label: Text('Semana')),
                ButtonSegment(value: 'Mes', label: Text('Mes')),
              ],
              selected: {_range},
              onSelectionChanged: (selection) => setState(() => _range = selection.first),
            ),
            const SizedBox(height: 18),
            _DriverSettingsInfoCard(
              title: 'Viajes completados',
              subtitle: '$completed viaje(s) cerrados en este periodo.',
            ),
            _DriverSettingsInfoCard(
              title: 'Viajes promocionales',
              subtitle: '$promoTrips viaje(s) promo en este periodo.',
            ),
            _DriverSettingsInfoCard(
              title: 'Cobro estimado',
              subtitle: 'Bs ${estimatedRevenue.toStringAsFixed(2)} en viajes no promocionales.',
            ),
          ],
        ),
      ),
    );
  }
}

String _formatShortDate(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) {
    return raw;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFFFC89B)),
          filled: true,
          fillColor: const Color(0xFF25252B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF303035)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.4),
          ),
        ),
        style: const TextStyle(color: Color(0xFFFFF4EC)),
      ),
    );
  }
}

class _DriverSettingsInfoCard extends StatelessWidget {
  const _DriverSettingsInfoCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2C2C31)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A31),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFFF97316)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFF4EC),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFFFD8BF),
                      fontWeight: FontWeight.w600,
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
      backgroundColor: const Color(0xFF111214),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111214),
        foregroundColor: const Color(0xFFFFF4EC),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFF4EC),
          ),
        ),
      ),
      body: child,
    );
  }
}
