import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../../core/admin_center/admin_center_repository.dart';
import '../../../../../core/map/offline_map.dart';
import '../../../../../core/ui/top_notice.dart';
import '../../../../../core/update/app_install_info.dart';
import '../../../../../core/update/app_update_service.dart';
import '../../../../../shared/theme/rapigo_theme.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../trip/data/trip_repository.dart';
import '../../../trip/domain/driver_trip.dart';
import '../widgets/driver_ui_kit.dart';

class DriverProfilePage extends ConsumerWidget {
  const DriverProfilePage({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(driverSessionProvider.notifier).logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(driverSessionProvider);
    final displayName = session.firstName.trim().isNotEmpty
        ? session.firstName.trim()
        : (session.fullName.trim().isNotEmpty
              ? session.fullName.trim().split(' ').first
              : 'alex');
    final vehicleSummary = session.vehicleType.trim().isNotEmpty
        ? session.vehicleType.trim()
        : '';

    return _DetailScaffold(
      title: 'Perfil',
      child: Scaffold(
        backgroundColor: palette.backgroundBase,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              metrics.sectionGap,
              metrics.pagePadding,
              metrics.pagePadding + 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, $displayName!',
                            style: textTheme.headlineMedium?.copyWith(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: palette.textPrimary,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: metrics.itemGap * 0.55),
                          Row(
                            children: [
                              Text(
                                'Conductor verificado',
                                style: textTheme.titleMedium?.copyWith(
                                  color: palette.textSecondary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: metrics.itemGap * 0.5),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: palette.accentYellow,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          if (vehicleSummary.isNotEmpty) ...[
                            SizedBox(height: metrics.itemGap * 0.8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfacePrimary,
                                borderRadius: BorderRadius.circular(
                                  metrics.radiusSmall,
                                ),
                                border: Border.all(
                                  color: palette.outlineStrong,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_car_filled_rounded,
                                    size: 18,
                                    color: palette.accentYellow,
                                  ),
                                  SizedBox(width: metrics.itemGap * 0.5),
                                  Flexible(
                                    child: Text(
                                      vehicleSummary,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: palette.surfacePrimary,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: palette.outlineStrong),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 40,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: metrics.sectionGap),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11151D),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF262D37)),
                  ),
                  child: Column(
                    children: [
                      _DriverProfileMenuTile(
                        icon: Icons.edit_outlined,
                        title: 'Editar perfil',
                        onTap: () =>
                            _openPage(context, const DriverEditProfilePage()),
                      ),
                      _DriverProfileDivider(),
                      _DriverProfileMenuTile(
                        icon: Icons.bar_chart_rounded,
                        title: 'Estadistica',
                        onTap: () =>
                            _openPage(context, const DriverStatisticsPage()),
                      ),
                      _DriverProfileDivider(),
                      _DriverProfileMenuTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        onTap: () =>
                            _openPage(context, const DriverNotificationsPage()),
                      ),
                      _DriverProfileDivider(),
                      _DriverProfileMenuTile(
                        icon: Icons.settings_outlined,
                        title: 'Configuraciones',
                        onTap: () =>
                            _openPage(context, const DriverSettingsPage()),
                      ),
                      _DriverProfileDivider(),
                      _DriverProfileMenuTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Soporte',
                        onTap: () =>
                            _openPage(context, const DriverSupportPage()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _handleLogout(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: const Color(0xFF111827),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class DriverAppInfoPage extends StatefulWidget {
  const DriverAppInfoPage({super.key});

  @override
  State<DriverAppInfoPage> createState() => _DriverAppInfoPageState();
}

class _DriverAppInfoPageState extends State<DriverAppInfoPage> {
  late final Future<_DriverAppInfoData> _future = _load();

  Future<_DriverAppInfoData> _load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installInfo = await AndroidAppInstallInfo.read();
    final updateManifest = await AppUpdateService(
      appId: 'rapigo_driver_pro',
    ).fetchLatestManifest();
    return _DriverAppInfoData(
      packageInfo: packageInfo,
      installInfo: installInfo,
      manifestReleasedAt: updateManifest?.releasedAt,
      manifestUpdatedAt: updateManifest?.updatedAt,
      latestVersion: updateManifest == null
          ? null
          : '${updateManifest.version}+${updateManifest.buildNumber}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: 'Acerca de',
      child: Scaffold(
        backgroundColor: const Color(0xFF090D14),
        body: FutureBuilder<_DriverAppInfoData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFACC15)),
              );
            }
            final data = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11151D),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF262D37)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0x19FACC15),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0x33FACC15)),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFFACC15),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RAPIGO PRO',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Información técnica y datos de la versión instalada.',
                                style: TextStyle(
                                  color: Color(0xFFB8C0CC),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DriverInfoSection(
                    title: 'Acerca de',
                    children: [
                      _DriverInfoRow(
                        label: 'Versión instalada',
                        value:
                            '${data.packageInfo.version}+${data.packageInfo.buildNumber}',
                      ),
                      _DriverInfoRow(
                        label: 'Paquete',
                        value: data.packageInfo.packageName,
                      ),
                      _DriverInfoRow(
                        label: 'Fecha de lanzamiento',
                        value:
                            _formatInfoDate(
                              data.installInfo?.firstInstallDate,
                            ) ??
                            'No disponible',
                      ),
                      _DriverInfoRow(
                        label: 'Fecha de actualización',
                        value:
                            _formatInfoDate(data.installInfo?.lastUpdateDate) ??
                            'No disponible',
                      ),
                      _DriverInfoRow(
                        label: 'Última versión publicada',
                        value: data.latestVersion ?? 'No disponible',
                      ),
                      _DriverInfoRow(
                        label: 'Lanzamiento publicado',
                        value:
                            _formatInfoDate(
                              _tryParseDate(data.manifestReleasedAt),
                            ) ??
                            'No disponible',
                      ),
                      _DriverInfoRow(
                        label: 'Actualización publicada',
                        value:
                            _formatInfoDate(
                              _tryParseDate(data.manifestUpdatedAt),
                            ) ??
                            'No disponible',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class DriverEditProfilePage extends ConsumerStatefulWidget {
  const DriverEditProfilePage({super.key});

  @override
  ConsumerState<DriverEditProfilePage> createState() =>
      _DriverEditProfilePageState();
}

class _DriverEditProfilePageState extends ConsumerState<DriverEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  Future<DriverProfileDetails?>? _profileFuture;
  String _vehicleType = 'taxi';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(driverSessionProvider);
    _firstNameController.text = session.firstName;
    _lastNameController.text = session.lastName;
    _emailController.text = session.email;
    _addressController.text = session.address;
    _vehicleType = session.vehicleType.trim().isEmpty
        ? 'taxi'
        : session.vehicleType;
    _profileFuture = _loadDriverProfile();
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

  Future<DriverProfileDetails?> _loadDriverProfile() async {
    final session = ref.read(driverSessionProvider);
    if (session.token.isEmpty || session.userId.isEmpty) {
      return null;
    }
    final profile = await ref
        .read(authRepositoryProvider)
        .fetchDriverProfile(token: session.token, userId: session.userId);
    if (!_loaded && mounted) {
      setState(() {
        _loaded = true;
        _licenseController.text = profile.licenseNumber;
        _vehicleType = profile.vehicleType.trim().isEmpty
            ? _vehicleType
            : profile.vehicleType;
        _plateController.text = profile.plate;
        _brandController.text = profile.brand;
        _modelController.text = profile.model;
        _colorController.text = profile.color;
        _yearController.text = profile.year?.toString() ?? '';
      });
    }
    return profile;
  }

  String? _required(String? value, String label, {int min = 2}) {
    final text = value?.trim() ?? '';
    if (text.length < min ||
        RegExp(
          r'^(temp|temporal|pendiente|sin dato|sin datos|n/a|na|test|prueba)$',
          caseSensitive: false,
        ).hasMatch(text)) {
      return '$label es obligatorio.';
    }
    return null;
  }

  String? _realName(String? value, String label) {
    final text = value?.trim() ?? '';
    final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}').hasMatch(text);
    final isGeneric = RegExp(
      r'^(conductor|conductora|driver|chofer|taxista|usuario|user|test|prueba)$',
      caseSensitive: false,
    ).hasMatch(text);
    if (text.length < 2 || !hasLetters || isGeneric) {
      return 'Ingresa un $label real.';
    }
    return null;
  }

  String? _licenseValidator(String? value) {
    final text = value?.trim() ?? '';
    final requiredError = _required(text, 'Licencia', min: 4);
    if (requiredError != null || text.toUpperCase().startsWith('TEMP-')) {
      return 'Ingresa una licencia real.';
    }
    return null;
  }

  String? _plateValidator(String? value) {
    final text = value?.trim() ?? '';
    final requiredError = _required(text, 'Placa', min: 4);
    if (requiredError != null ||
        RegExp(r'^POT-[0-9A-F]{4}$', caseSensitive: false).hasMatch(text)) {
      return 'Ingresa una placa real.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Correo invalido.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(driverSessionProvider.notifier)
        .completeProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          licenseCategory: '',
          licenseIssueDate: '',
          licenseExpiryDate: '',
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
    setState(() => _saving = false);
    final session = ref.read(driverSessionProvider);
    if (session.errorMessage != null) {
      showTopNotice(context, session.errorMessage!, tone: NoticeTone.error);
      return;
    }
    await ref.read(driverSessionProvider.notifier).refreshSessionStatus();
    if (!mounted) {
      return;
    }
    showTopNotice(
      context,
      'Perfil actualizado correctamente.',
      tone: NoticeTone.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final session = ref.watch(driverSessionProvider);
    return _DetailScaffold(
      title: 'Editar perfil',
      child: Scaffold(
        backgroundColor: palette.backgroundBase,
        body: FutureBuilder<DriverProfileDetails?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_loaded) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFACC15)),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EditSection(
                      title: 'Datos personales',
                      children: [
                        _EditField(
                          controller: _firstNameController,
                          label: 'Nombre',
                          icon: Icons.person_outline_rounded,
                          validator: (value) => _realName(value, 'nombre'),
                        ),
                        _EditField(
                          controller: _lastNameController,
                          label: 'Apellido',
                          icon: Icons.badge_outlined,
                          validator: (value) => _realName(value, 'apellido'),
                        ),
                        _EditField(
                          controller: _emailController,
                          label: 'Correo',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                        ),
                        _EditField(
                          controller: _addressController,
                          label: 'Direccion',
                          icon: Icons.location_on_outlined,
                          validator: (value) =>
                              _required(value, 'Direccion', min: 4),
                        ),
                        _ReadOnlyInfo(label: 'Telefono', value: session.phone),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _EditSection(
                      title: 'Licencia',
                      children: [
                        _EditField(
                          controller: _licenseController,
                          label: 'Numero de licencia',
                          icon: Icons.credit_card_rounded,
                          validator: _licenseValidator,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _EditSection(
                      title: 'Vehiculo',
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'taxi',
                              icon: Icon(Icons.local_taxi_rounded),
                              label: Text('Taxi'),
                            ),
                            ButtonSegment(
                              value: 'moto',
                              icon: Icon(Icons.two_wheeler_rounded),
                              label: Text('Moto'),
                            ),
                          ],
                          selected: {_vehicleType == 'moto' ? 'moto' : 'taxi'},
                          onSelectionChanged: _saving
                              ? null
                              : (value) =>
                                    setState(() => _vehicleType = value.first),
                        ),
                        const SizedBox(height: 12),
                        _EditField(
                          controller: _plateController,
                          label: 'Placa',
                          icon: Icons.pin_rounded,
                          validator: _plateValidator,
                        ),
                        _EditField(
                          controller: _brandController,
                          label: 'Marca',
                          icon: Icons.directions_car_filled_outlined,
                          validator: (value) => _required(value, 'Marca'),
                        ),
                        _EditField(
                          controller: _modelController,
                          label: 'Modelo',
                          icon: Icons.car_repair_outlined,
                          validator: (value) =>
                              _required(value, 'Modelo', min: 1),
                        ),
                        _EditField(
                          controller: _colorController,
                          label: 'Color',
                          icon: Icons.palette_outlined,
                          validator: (value) => _required(value, 'Color'),
                        ),
                        _EditField(
                          controller: _yearController,
                          label: 'Anio',
                          icon: Icons.calendar_month_outlined,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return null;
                            }
                            final year = int.tryParse(text);
                            if (year == null || year < 1990 || year > 2100) {
                              return 'Anio invalido.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Guardando...' : 'Guardar cambios',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.outlineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class _ReadOnlyInfo extends StatelessWidget {
  const _ReadOnlyInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF263244)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, color: Color(0xFFFACC15), size: 19),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? 'Sin dato' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAppInfoData {
  const _DriverAppInfoData({
    required this.packageInfo,
    required this.installInfo,
    required this.manifestReleasedAt,
    required this.manifestUpdatedAt,
    required this.latestVersion,
  });

  final PackageInfo packageInfo;
  final AppInstallInfo? installInfo;
  final String? manifestReleasedAt;
  final String? manifestUpdatedAt;
  final String? latestVersion;
}

class _DriverInfoSection extends StatelessWidget {
  const _DriverInfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF11151D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262D37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DriverInfoRow extends StatelessWidget {
  const _DriverInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF0C121B),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF232D3A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFB8C0CC),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverStatisticsMetricButton extends StatelessWidget {
  const _DriverStatisticsMetricButton({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outlineStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x19FACC15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x44FACC15)),
            ),
            child: Icon(icon, color: palette.accentYellow, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverProfileMenuTile extends StatelessWidget {
  const _DriverProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.surfaceSecondary,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: palette.outlineStrong),
              ),
              child: Icon(icon, color: palette.accentYellow, size: 22),
            ),
            SizedBox(width: metrics.itemGap * 0.75),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: EdgeInsets.zero,
              child: Icon(
                Icons.chevron_right_rounded,
                color: palette.textPrimary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProfileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.rapigoPalette.outlineSoft,
    );
  }
}

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  bool _requestSoundEnabled = true;
  bool _loadingRequestSound = true;

  @override
  void initState() {
    super.initState();
    _loadRequestSoundPreference();
  }

  Future<void> _loadRequestSoundPreference() async {
    final enabled = await LocalNotifications.isRequestSoundEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _requestSoundEnabled = enabled;
      _loadingRequestSound = false;
    });
  }

  Future<void> _setRequestSoundPreference(bool enabled) async {
    setState(() {
      _requestSoundEnabled = enabled;
    });
    await LocalNotifications.setRequestSoundEnabled(enabled);
    if (!mounted) {
      return;
    }
    showTopNotice(
      context,
      enabled
          ? 'Sonido activado para solicitudes de viaje.'
          : 'Sonido desactivado para solicitudes de viaje.',
      tone: NoticeTone.success,
      icon: enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    return _DetailScaffold(
      title: 'Configuraciones',
      child: DriverPageShell(
        eyebrow: 'Preferencias',
        title: 'Configuraciones',
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfacePrimary, palette.surfaceSecondary],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.outlineStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mapa offline',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Descarga o actualiza Potosi ciudad para mantener el mapa listo aun con señal baja.',
                    style: TextStyle(
                      color: Color(0xFFDCE6F2),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => showOfflineMapSheet(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: const Icon(
                        Icons.download_for_offline_rounded,
                        size: 18,
                      ),
                      label: const Text('Abrir mapa offline'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfacePrimary, palette.surfaceSecondary],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.outlineStrong),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          (_requestSoundEnabled
                                  ? palette.accentGreen
                                  : palette.surfaceMuted)
                              .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _requestSoundEnabled
                            ? palette.accentGreen.withValues(alpha: 0.45)
                            : palette.outlineSoft,
                      ),
                    ),
                    child: Icon(
                      _requestSoundEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _requestSoundEnabled
                          ? palette.accentGreen
                          : palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sonido de solicitudes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Alerta sonora cuando llega una solicitud de viaje.',
                          style: TextStyle(
                            color: Color(0xFFDCE6F2),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _requestSoundEnabled,
                    onChanged: _loadingRequestSound
                        ? null
                        : (value) => _setRequestSoundPreference(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfacePrimary, palette.surfaceSecondary],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.outlineStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicios',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Expanded(
                        child: _DriverServiceOptionButton(
                          icon: Icons.local_taxi_rounded,
                          title: 'Taxi o moto',
                          subtitle: 'Activo',
                          active: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DriverServiceOptionButton(
                          icon: Icons.delivery_dining_rounded,
                          title: 'Delivery',
                          subtitle: 'En desarrollo',
                          active: false,
                          onTap: () => showTopNotice(
                            context,
                            'Delivery en desarrollo proximamente.',
                            tone: NoticeTone.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _DriverProtectedSessionCard(),
            const SizedBox(height: 14),
            _DriverAboutSettingsCard(
              onOpenInfo: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DriverAppInfoPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProtectedSessionCard extends StatelessWidget {
  const _DriverProtectedSessionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF11151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262D37)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x19FACC15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x33FACC15)),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFFFACC15),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesión protegida activa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cuenta segura y monitoreada.',
                  style: TextStyle(
                    color: Color(0xFFB8C0CC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF32D74B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF32D74B).withValues(alpha: 0.30),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAboutSettingsCard extends StatelessWidget {
  const _DriverAboutSettingsCard({required this.onOpenInfo});

  final VoidCallback onOpenInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262D37)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acerca de',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onOpenInfo,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF2A3340)),
                backgroundColor: const Color(0xFF0B1220),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFFACC15),
                size: 18,
              ),
              label: const Text('Versión y datos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverServiceOptionButton extends StatelessWidget {
  const _DriverServiceOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = active
        ? const Color(0x661D4ED8)
        : const Color(0x33475569);
    final iconColor = active
        ? const Color(0xFF60A5FA)
        : const Color(0xFF94A3B8);
    return Material(
      color: active ? const Color(0x191D4ED8) : const Color(0xFF0B1220),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const Spacer(),
                  Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: active
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFFACC15),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFDCE6F2),
                  fontSize: 10.5,
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

class DriverNotificationsPage extends ConsumerWidget {
  const DriverNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(driverSessionProvider);
    final repository = const AdminCenterRepository();

    return _DetailScaffold(
      title: 'Notificaciones',
      child: FutureBuilder<List<AdminNotificationItem>>(
        future: session.token.isEmpty
            ? Future.value(const <AdminNotificationItem>[])
            : repository.fetchNotifications(session.token),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <AdminNotificationItem>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(color: Color(0xFFFACC15)),
              ),
            );
          }

          return DriverPageShell(
            eyebrow: 'Bandeja',
            title: 'Notificaciones',
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123E8A), Color(0xFF0C1830)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x551D4ED8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x19FACC15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x55FACC15)),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Color(0xFFFACC15),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items.isEmpty
                                  ? 'Bandeja limpia'
                                  : '${items.length} aviso(s) disponible(s)',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items.isEmpty
                                  ? 'Solicitudes de pasajeros y promociones prioritarias pueden llegar al telefono. El resto aparecera aqui.'
                                  : 'Las solicitudes prioritarias y promociones pueden sonar en el telefono. Cambios operativos y avisos internos se consultan aqui.',
                              style: const TextStyle(
                                color: Color(0xFFDCE6F2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const _DriverSettingsInfoCard(
                    title: 'Sin avisos nuevos',
                    subtitle:
                        'Aqui veras cambios de estado, avisos operativos, autorizaciones y mensajes internos de RAPIGO - PRO.',
                  ),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DriverNotificationCard(
                      kind: item.kind,
                      title: item.title,
                      message: item.message,
                      createdAt: item.createdAt,
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
        future: session.token.isEmpty
            ? Future.value(const <SupportReportItem>[])
            : repository.fetchSupportReports(session.token),
        builder: (context, snapshot) {
          final reports = snapshot.data ?? const <SupportReportItem>[];
          return DriverPageShell(
            eyebrow: 'Soporte',
            title: 'Reporta un problema',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1F),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2C2C31)),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        dropdownColor: const Color(0xFF0C1830),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Tipo de reporte',
                          labelStyle: const TextStyle(
                            color: Color(0xFFFACC15),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1323),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A3A66),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFFACC15),
                              width: 1.4,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Falla de app',
                            child: Text(
                              'Falla de app',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Problema con viaje',
                            child: Text(
                              'Problema con viaje',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Cuenta o acceso',
                            child: Text(
                              'Cuenta o acceso',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Mapa o GPS',
                            child: Text(
                              'Mapa o GPS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'Falla de app'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Detalle del problema',
                          hintText:
                              'Describe lo que pasó para que central pueda ayudarte mejor.',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          labelStyle: const TextStyle(
                            color: Color(0xFFFACC15),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1323),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1A3A66),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFFACC15),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending
                              ? null
                              : () async {
                                  if (_messageController.text.trim().length <
                                      8) {
                                    showTopNotice(
                                      context,
                                      'Describe mejor el problema para enviarlo a central.',
                                      tone: NoticeTone.error,
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
                                      tone: NoticeTone.success,
                                    );
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    showTopNotice(
                                      context,
                                      error.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                      tone: NoticeTone.error,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _sending = false);
                                    }
                                  }
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _sending ? 'Enviando...' : 'Enviar reporte',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (reports.isEmpty)
                  const _DriverSettingsInfoCard(
                    title: 'Sin reportes todavía',
                    subtitle:
                        'Cuando envíes un reporte desde aquí, central podrá verlo con tus datos del conductor.',
                  ),
                ...reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DriverMenuTile(
                      icon: Icons.support_agent,
                      title: '${report.category} · ${report.status}',
                      subtitle:
                          '${report.message}\n${_formatShortDate(report.createdAt)}',
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
  ConsumerState<DriverStatisticsPage> createState() =>
      _DriverStatisticsPageState();
}

class _DriverStatisticsPageState extends ConsumerState<DriverStatisticsPage> {
  String _range = 'Dia';

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final history =
        ref.watch(driverTripHistoryProvider).value ?? const <DriverTrip>[];
    final now = DateTime.now();
    final filtered = history
        .where((trip) {
          final date = DateTime.tryParse(trip.requestedAt ?? '');
          if (date == null) {
            return false;
          }
          final local = date.toLocal();
          if (_range == 'Dia') {
            return local.year == now.year &&
                local.month == now.month &&
                local.day == now.day;
          }
          if (_range == 'Semana') {
            return now.difference(local).inDays < 7;
          }
          return local.year == now.year && local.month == now.month;
        })
        .toList(growable: false);

    final completed = filtered
        .where((trip) => trip.status == 'completed')
        .length;
    final totalCompleted = history
        .where((trip) => trip.status == 'completed')
        .length;
    final promoTrips = filtered.where((trip) => trip.isPromotional).length;

    return _DetailScaffold(
      title: 'Estadistica',
      child: DriverPageShell(
        eyebrow: 'Rendimiento',
        title: 'Estadistica',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _DriverStatisticsMetricButton(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Prioridad',
                    value: '+${totalCompleted < 120 ? 120 : totalCompleted}',
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _DriverStatisticsMetricButton(
                    icon: Icons.star_border_rounded,
                    label: 'Calificación',
                    value: '5.0',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              style: ButtonStyle(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.accentYellow;
                  }
                  return palette.surfacePrimary;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.backgroundBase;
                  }
                  return palette.textPrimary;
                }),
                side: WidgetStatePropertyAll(
                  BorderSide(color: palette.outlineStrong),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              segments: const [
                ButtonSegment(value: 'Dia', label: Text('Dia')),
                ButtonSegment(value: 'Semana', label: Text('Semana')),
                ButtonSegment(value: 'Mes', label: Text('Mes')),
              ],
              selected: {_range},
              onSelectionChanged: (selection) =>
                  setState(() => _range = selection.first),
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

class _DriverNotificationCard extends StatelessWidget {
  const _DriverNotificationCard({
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String kind;
  final String title;
  final String message;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    final visual = _driverNotificationVisual(kind);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1830), Color(0xFF09111F)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visual.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: visual.backgroundColor,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: visual.borderColor),
            ),
            child: Icon(visual.icon, color: visual.accentColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: visual.backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: visual.borderColor),
                      ),
                      child: Text(
                        visual.label,
                        style: TextStyle(
                          color: visual.accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1323),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x331D4ED8)),
                      ),
                      child: Text(
                        _formatShortDate(createdAt),
                        style: const TextStyle(
                          color: Color(0xFFDCE6F2),
                          fontWeight: FontWeight.w700,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFDCE6F2),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({
  Color accentColor,
  Color backgroundColor,
  Color borderColor,
  IconData icon,
  String label,
})
_driverNotificationVisual(String kind) {
  switch (kind.toLowerCase()) {
    case 'importante':
      return (
        accentColor: const Color(0xFFEF4444),
        backgroundColor: const Color(0x22EF4444),
        borderColor: const Color(0x44EF4444),
        icon: Icons.priority_high_rounded,
        label: 'IMPORTANTE',
      );
    case 'sistema':
      return (
        accentColor: const Color(0xFF38BDF8),
        backgroundColor: const Color(0x2238BDF8),
        borderColor: const Color(0x4438BDF8),
        icon: Icons.settings_suggest_rounded,
        label: 'SISTEMA',
      );
    default:
      return (
        accentColor: const Color(0xFFFACC15),
        backgroundColor: const Color(0x19FACC15),
        borderColor: const Color(0xFF1A3A66),
        icon: Icons.notifications_active_outlined,
        label: 'NUEVO',
      );
  }
}

class _DriverSettingsInfoCard extends StatelessWidget {
  const _DriverSettingsInfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C1830), Color(0xFF09111F)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1A3A66)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x191D4ED8),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0x551D4ED8)),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFFFACC15),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDCE6F2),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

class DriverTripDetailPage extends StatelessWidget {
  const DriverTripDetailPage({super.key, required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    final metrics = context.rapigoMetrics;
    final passengerName = (trip.passengerName ?? '').trim().isEmpty
        ? 'Pasajero RAPIGO'
        : trip.passengerName!.trim();
    final distanceKm = driverTripDistanceKm(trip);
    final durationMinutes = driverTripEstimatedMinutes(trip);
    final requestedAt = trip.requestedAt ?? '';
    final routeDate = _formatTripDate(requestedAt);
    final routeTime = _formatTripTime(requestedAt);
    final vehicleLabel = _tripVehicleLabel(trip);
    final vehicleChip = trip.vehicleLabel?.trim().isNotEmpty == true
        ? trip.vehicleLabel!.trim()
        : vehicleLabel;
    final statusLabel = driverTripStatusLabel(trip.status);
    final statusColor = driverTripStatusColor(trip.status);

    return _DetailScaffold(
      title: 'Detalle del viaje',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Container(
            padding: EdgeInsets.all(metrics.pagePadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.surfacePrimary, palette.surfaceSecondary],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.outlineStrong),
              boxShadow: [
                BoxShadow(
                  color: palette.shadowSoft,
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF092114),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF14532D)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _driverInitials(passengerName),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF22C55E),
                        ),
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
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TripCapsule(
                                icon: Icons.verified_outlined,
                                label: 'Viaje realizado',
                              ),
                              _TripCapsule(
                                icon: Icons.local_taxi_rounded,
                                label: vehicleChip,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: statusColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TripMetaLine(
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFFFACC15),
                        text: routeDate,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFF173056),
                    ),
                    Expanded(
                      child: _TripMetaLine(
                        icon: Icons.access_time_rounded,
                        color: const Color(0xFFFACC15),
                        text: routeTime,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DriverTripRoutePreview(
                  trip: trip,
                  height: 238,
                  showLabels: true,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08111E),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF13335A)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TripMetricItem(
                          icon: Icons.place_rounded,
                          value: '${distanceKm.toStringAsFixed(1)} km',
                          label: 'Distancia',
                          color: const Color(0xFF22C55E),
                        ),
                      ),
                      const _TripMetricDivider(),
                      Expanded(
                        child: _TripMetricItem(
                          icon: Icons.schedule_rounded,
                          value: '$durationMinutes min',
                          label: 'Duracion',
                          color: const Color(0xFF2979FF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TripTimelineCard(requestedAt: requestedAt, trip: trip),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF091425), Color(0xFF08111E)],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF15335A)),
            ),
            child: Column(
              children: [
                _TripInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Pasajero',
                  value: passengerName,
                  trailing: Icons.chevron_right_rounded,
                ),
                const _TripInfoDivider(),
                _TripInfoRow(
                  icon: Icons.directions_car_filled_outlined,
                  label: 'Vehiculo',
                  value: vehicleChip,
                  trailing: Icons.chevron_right_rounded,
                ),
                const _TripInfoDivider(),
                _TripInfoRow(
                  icon: Icons.sell_outlined,
                  label: 'Tipo de servicio',
                  value: 'RAPIGO PRO',
                  trailing: Icons.chevron_right_rounded,
                ),
                const _TripInfoDivider(),
                _TripInfoRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'ID del viaje',
                  value: '#${trip.id}',
                  trailing: Icons.copy_rounded,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: trip.id));
                    if (context.mounted) {
                      showTopNotice(context, 'ID del viaje copiado.');
                    }
                  },
                ),
                const _TripInfoDivider(),
                _TripInfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Estado',
                  value: statusLabel,
                  valueColor: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DriverSupportPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Soporte'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF1A3A66)),
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    showTopNotice(
                      context,
                      'Muy pronto podras descargar el recibo del viaje.',
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Descargar recibo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2979FF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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

class DriverTripRoutePreview extends StatelessWidget {
  const DriverTripRoutePreview({
    super.key,
    required this.trip,
    this.height = 180,
    this.showLabels = false,
  });

  final DriverTrip trip;
  final double height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF09111E), Color(0xFF0A1425)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _TripMapGridPainter())),
            Positioned.fill(child: CustomPaint(painter: _TripRoutePainter())),
            Positioned(
              left: 26,
              bottom: 28,
              child: _TripMapPin(
                color: const Color(0xFF22C55E),
                innerColor: Colors.white,
              ),
            ),
            Positioned(
              right: 26,
              top: 28,
              child: _TripMapPin(
                color: const Color(0xFFFF4D5D),
                innerColor: Colors.white,
                glow: const Color(0x55FF4D5D),
              ),
            ),
            if (showLabels) ...[
              Positioned(
                left: 20,
                bottom: 8,
                child: Text(
                  _shortPlaceLabel(trip.passengerPickup),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF86EFAC),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 96,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 138),
                  child: Text(
                    _shortPlaceLabel(trip.destination),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFD9DE),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripCapsule extends StatelessWidget {
  const _TripCapsule({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1628),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF17345E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFACC15)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripMetaLine extends StatelessWidget {
  const _TripMetaLine({
    required this.icon,
    required this.color,
    required this.text,
    this.alignEnd = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE8F0FF),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripMetricItem extends StatelessWidget {
  const _TripMetricItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA8B7CC),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TripMetricDivider extends StatelessWidget {
  const _TripMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFF173056),
    );
  }
}

class _TripTimelineCard extends StatelessWidget {
  const _TripTimelineCard({required this.requestedAt, required this.trip});

  final String requestedAt;
  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF091425), Color(0xFF08111E)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF15335A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                _TripWaypoint(color: const Color(0xFF22C55E), outlined: true),
                Container(
                  width: 2,
                  height: 78,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF314968),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                _TripWaypoint(color: const Color(0xFFFF4D5D), outlined: true),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Origen',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trip.passengerPickup,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTripDate(requestedAt)}  •  ${_formatTripTime(requestedAt)}',
                  style: const TextStyle(
                    color: Color(0xFFAAB7CA),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Destino',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFF4D5D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  trip.destination,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTripDate(requestedAt)}  •  ${_formatEndTime(requestedAt, driverTripEstimatedMinutes(trip))}',
                  style: const TextStyle(
                    color: Color(0xFFAAB7CA),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripWaypoint extends StatelessWidget {
  const _TripWaypoint({required this.color, this.outlined = false});

  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: outlined ? Colors.transparent : color,
        border: Border.all(color: color, width: 3),
      ),
      child: outlined
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            )
          : null,
    );
  }
}

class _TripInfoRow extends StatelessWidget {
  const _TripInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData? trailing;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Icon(icon, color: const Color(0xFFC5CFDF), size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDCE6F2),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Icon(trailing, color: const Color(0xFFAAB7CA), size: 20),
        ],
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: content,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: content,
      ),
    );
  }
}

class _TripInfoDivider extends StatelessWidget {
  const _TripInfoDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFF143050));
  }
}

class _TripMapPin extends StatelessWidget {
  const _TripMapPin({required this.color, required this.innerColor, this.glow});

  final Color color;
  final Color innerColor;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: glow ?? color.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: innerColor),
        ),
      ),
    );
  }
}

class _TripMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final major = Paint()
      ..color = const Color(0xFF142640)
      ..strokeWidth = 1.4;
    final minor = Paint()
      ..color = const Color(0xFF0F1E34)
      ..strokeWidth = 0.7;
    for (double x = 0; x <= size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y <= size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    for (double x = 0; x <= size.width; x += 72) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = 0; y <= size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TripRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = const Color(0x882979FF)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final route = Paint()
      ..color = const Color(0xFF2979FF)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.10, size.height * 0.74)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.72,
        size.width * 0.36,
        size.height * 0.55,
        size.width * 0.48,
        size.height * 0.56,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.57,
        size.width * 0.73,
        size.height * 0.48,
        size.width * 0.82,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.30,
        size.width * 0.90,
        size.height * 0.25,
        size.width * 0.92,
        size.height * 0.21,
      );

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double driverTripDistanceKm(DriverTrip trip) {
  final destinationLat = trip.destinationLat ?? trip.pickupLat + 0.028;
  final destinationLng = trip.destinationLng ?? trip.pickupLng + 0.018;
  final km = const Distance().as(
    LengthUnit.Kilometer,
    LatLng(trip.pickupLat, trip.pickupLng),
    LatLng(destinationLat, destinationLng),
  );
  return km.isFinite ? km : 0;
}

int driverTripEstimatedMinutes(DriverTrip trip) {
  final km = driverTripDistanceKm(trip);
  return (km * 2.7).round().clamp(4, 90);
}

Color driverTripStatusColor(String status) {
  return switch (status) {
    'completed' => const Color(0xFF22C55E),
    'cancelled' => const Color(0xFFEF4444),
    'in_progress' => const Color(0xFF2979FF),
    'accepted' || 'arriving' || 'at_pickup' => const Color(0xFFFACC15),
    _ => const Color(0xFF22C55E),
  };
}

String driverTripStatusLabel(String status) {
  return switch (status) {
    'requested' => 'Solicitado',
    'searching' => 'Buscando',
    'accepted' => 'Aceptado',
    'arriving' => 'En camino',
    'at_pickup' => 'Llego',
    'in_progress' => 'En curso',
    'completed' => 'Finalizado',
    'cancelled' => 'Cancelado',
    _ => 'Finalizado',
  };
}

String _driverInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'RP';
  }
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length >= 2 ? 2 : 1)
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _tripVehicleLabel(DriverTrip trip) {
  final plate = trip.vehiclePlate?.trim();
  final type = (trip.vehicleType ?? 'Taxi').trim();
  if (plate != null && plate.isNotEmpty) {
    return plate;
  }
  return type[0].toUpperCase() + type.substring(1);
}

String _shortPlaceLabel(String raw) {
  final cleaned = raw.trim();
  if (cleaned.length <= 24) {
    return cleaned;
  }
  return '${cleaned.substring(0, 24)}...';
}

String _formatTripDate(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) {
    return '17 jun 2026';
  }
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _formatTripTime(String raw) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) {
    return '03:08 p. m.';
  }
  final hour = date.hour > 12
      ? date.hour - 12
      : (date.hour == 0 ? 12 : date.hour);
  final minutes = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minutes $suffix';
}

String _formatEndTime(String raw, int minutesToAdd) {
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) {
    return '--:--';
  }
  final end = date.add(Duration(minutes: minutesToAdd));
  final hour = end.hour > 12 ? end.hour - 12 : (end.hour == 0 ? 12 : end.hour);
  final minutes = end.minute.toString().padLeft(2, '0');
  final suffix = end.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minutes $suffix';
}

DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String? _formatInfoDate(DateTime? date) {
  if (date == null) {
    return null;
  }
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute';
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.rapigoPalette;
    return Scaffold(
      backgroundColor: palette.backgroundBase,
      appBar: AppBar(
        backgroundColor: palette.backgroundBase,
        foregroundColor: palette.textPrimary,
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: child,
    );
  }
}
