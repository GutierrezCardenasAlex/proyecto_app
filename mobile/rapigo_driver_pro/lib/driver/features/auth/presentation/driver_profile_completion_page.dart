import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/top_notice.dart';
import '../data/auth_repository.dart';
import '../domain/driver_session.dart';

class DriverProfileCompletionPage extends ConsumerStatefulWidget {
  const DriverProfileCompletionPage({super.key});

  @override
  ConsumerState<DriverProfileCompletionPage> createState() =>
      _DriverProfileCompletionPageState();
}

class _DriverProfileCompletionPageState
    extends ConsumerState<DriverProfileCompletionPage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  final _licenseController = TextEditingController();
  final _licenseCategoryController = TextEditingController(text: 'B');
  final _licenseIssueController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _yearController = TextEditingController();
  int _step = 4;
  String _vehicleType = 'taxi';
  bool _driverPhotoReady = false;
  bool _licensePhotoReady = false;
  bool _vehiclePhotoReady = false;
  bool _profileSubmitted = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(driverSessionProvider);
    _firstNameController = TextEditingController(text: session.firstName);
    _lastNameController = TextEditingController(text: session.lastName);
    _emailController = TextEditingController(text: session.email);
    _addressController = TextEditingController(text: session.address);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _licenseCategoryController.dispose();
    _licenseIssueController.dispose();
    _licenseExpiryController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  bool _isGenericName(String value) {
    return RegExp(
      r'^(conductor|conductora|driver|chofer|taxista|usuario|user|test|prueba)$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  String? _validateRealName(String value, String label) {
    final text = value.trim();
    final hasLetters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]{2,}').hasMatch(text);
    if (text.length < 2 || !hasLetters || _isGenericName(text)) {
      return 'Ingresa un $label real.';
    }
    return null;
  }

  bool _isLooseField(String value) {
    return RegExp(
      r'^(temp|temporal|pendiente|sin dato|sin datos|n/a|na|test|prueba)$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  String? _validateRequiredField(String value, String label, {int min = 2}) {
    final text = value.trim();
    if (text.length < min || _isLooseField(text)) {
      return '$label es obligatorio.';
    }
    return null;
  }

  String? _validatePersonalStep() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo valido.';
    }
    return _validateRealName(_firstNameController.text, 'nombre') ??
        _validateRealName(_lastNameController.text, 'apellido') ??
        _validateRequiredField(_addressController.text, 'La direccion', min: 4);
  }

  String? _validateLicenseStep() {
    final license = _licenseController.text.trim();
    final licenseError = _validateRequiredField(license, 'La licencia', min: 4);
    if (licenseError != null || license.toUpperCase().startsWith('TEMP-')) {
      return 'Ingresa un numero de licencia real.';
    }
    if (_licenseCategoryController.text.trim().isEmpty) {
      return 'Selecciona la categoria.';
    }
    if (_licenseIssueController.text.trim().isEmpty) {
      return 'Selecciona la fecha de emision.';
    }
    if (_licenseExpiryController.text.trim().isEmpty) {
      return 'Selecciona la fecha de vencimiento.';
    }
    return null;
  }

  String? _validateVehicleStep() {
    final plate = _plateController.text.trim();
    if (_validateRequiredField(plate, 'La placa', min: 4) != null ||
        RegExp(r'^POT-[0-9A-F]{4}$', caseSensitive: false).hasMatch(plate)) {
      return 'Ingresa una placa real del vehiculo.';
    }
    final vehicleDataError =
        _validateRequiredField(_brandController.text, 'La marca') ??
        _validateRequiredField(_modelController.text, 'El modelo', min: 1) ??
        _validateRequiredField(_colorController.text, 'El color');
    if (vehicleDataError != null) return vehicleDataError;
    if (_yearController.text.trim().isEmpty) {
      return 'Ingresa el anio.';
    }
    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1990 || year > 2100) {
      return 'Ingresa un anio valido del vehiculo.';
    }
    return null;
  }

  bool get _photosReady =>
      _driverPhotoReady && _licensePhotoReady && _vehiclePhotoReady;

  Future<void> _pickDate(TextEditingController controller) async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2018),
      lastDate: DateTime(2035),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      controller.text =
          '${result.day.toString().padLeft(2, '0')}/${result.month.toString().padLeft(2, '0')}/${result.year}';
    });
  }

  void _goNextFromCurrent() {
    String? error;
    switch (_step) {
      case 4:
        error = _validatePersonalStep();
        break;
      case 5:
        error = _validateLicenseStep();
        break;
      case 6:
        error = _validateVehicleStep();
        break;
      case 7:
        if (!_photosReady) {
          error = 'Marca las tres fotografias como listas para continuar.';
        }
        break;
    }
    if (error != null) {
      showTopNotice(context, error, tone: NoticeTone.error);
      return;
    }
    setState(() => _step = (_step + 1).clamp(4, 9));
  }

  Future<void> _confirmAndSend() async {
    final personalError = _validatePersonalStep();
    final licenseError = _validateLicenseStep();
    final vehicleError = _validateVehicleStep();
    if (personalError != null ||
        licenseError != null ||
        vehicleError != null ||
        !_photosReady) {
      showTopNotice(
        context,
        personalError ??
            licenseError ??
            vehicleError ??
            'Completa las fotografias antes de enviar.',
        tone: NoticeTone.error,
      );
      return;
    }
    setState(() => _step = 9);
    await _finishVerification();
  }

  Future<void> _finishVerification() async {
    if (_profileSubmitted) {
      await ref.read(driverSessionProvider.notifier).refreshSessionStatus();
      return;
    }
    await ref
        .read(driverSessionProvider.notifier)
        .completeProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          licenseNumber: _licenseController.text.trim(),
          licenseCategory: _licenseCategoryController.text.trim(),
          licenseIssueDate: _licenseIssueController.text.trim(),
          licenseExpiryDate: _licenseExpiryController.text.trim(),
          vehicleType: _vehicleType,
          plate: _plateController.text.trim(),
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          color: _colorController.text.trim(),
          year: int.tryParse(_yearController.text.trim()),
        );
    if (!mounted) {
      return;
    }
    final session = ref.read(driverSessionProvider);
    if (session.errorMessage == null) {
      setState(() => _profileSubmitted = true);
      showTopNotice(
        context,
        'Registro enviado. Quedara pendiente de autorizacion hasta que la central lo apruebe.',
        tone: NoticeTone.success,
      );
    }
  }

  Future<void> _cancelRegistration() async {
    await ref.read(driverSessionProvider.notifier).cancelRegistration();
    if (!mounted) {
      return;
    }
    showTopNotice(
      context,
      'Registro cancelado. Puedes volver a empezar con otro numero.',
      tone: NoticeTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(driverSessionProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _RegisterProgressBar(step: _step),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildStep(session),
                    ),
                    if (session.errorMessage != null && _step != 9) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1DE),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          session.errorMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF9B1C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F8))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _step > 4 ? () => setState(() => _step -= 1) : null,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1746B5),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/rapigo_driver_icon.png',
                  width: 34,
                  height: 34,
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'RAPIGO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1746B5),
                        ),
                      ),
                      TextSpan(
                        text: ' PRO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF6C311),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildStep(DriverSession session) {
    switch (_step) {
      case 4:
        return _buildPersonalStep();
      case 5:
        return _buildLicenseStep();
      case 6:
        return _buildVehicleStep();
      case 7:
        return _buildPhotosStep();
      case 8:
        return _buildReviewStep(session);
      case 9:
        return _buildPendingVerificationStep(session);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPersonalStep() {
    return Column(
      key: const ValueKey('driver-step-4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          titleBlue: 'Completa tus',
          titleYellow: 'datos personales',
          subtitle:
              'Necesitamos esta informacion para crear tu perfil de conductor.',
        ),
        const SizedBox(height: 22),
        _FormField(
          label: 'Nombre',
          controller: _firstNameController,
          icon: Icons.person_outline_rounded,
          hintText: 'Ingresa tu nombre',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Apellido',
          controller: _lastNameController,
          icon: Icons.person_outline_rounded,
          hintText: 'Ingresa tu apellido',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Correo electronico (opcional)',
          controller: _emailController,
          icon: Icons.email_outlined,
          hintText: 'ejemplo@gmail.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Direccion',
          controller: _addressController,
          icon: Icons.location_on_outlined,
          hintText: 'Ingresa tu direccion',
          suffixIcon: Icons.gps_fixed_rounded,
        ),
        const SizedBox(height: 20),
        const _SoftInfoCard(
          title: 'Tu informacion esta protegida',
          message:
              'Usamos esta informacion unicamente para brindarte un mejor servicio y seguridad.',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: 'CONTINUAR',
          onPrimaryPressed: _goNextFromCurrent,
          onCancelPressed: _cancelRegistration,
        ),
      ],
    );
  }

  Widget _buildLicenseStep() {
    return Column(
      key: const ValueKey('driver-step-5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          titleBlue: 'Informacion de',
          titleYellow: 'tu licencia',
          subtitle:
              'Ingresa los datos de tu licencia de conducir tal como aparecen en el documento.',
        ),
        const SizedBox(height: 22),
        _FormField(
          label: 'Numero de licencia',
          controller: _licenseController,
          icon: Icons.badge_outlined,
          hintText: 'Ej: 12345678',
        ),
        const SizedBox(height: 18),
        _DropdownField(
          label: 'Categoria de licencia',
          value: _licenseCategoryController.text,
          items: const ['A', 'B', 'C', 'M'],
          icon: Icons.credit_card_outlined,
          hintText: 'Selecciona la categoria',
          onChanged: (value) =>
              setState(() => _licenseCategoryController.text = value),
        ),
        const SizedBox(height: 18),
        _DateField(
          label: 'Fecha de emision',
          controller: _licenseIssueController,
          onTap: () => _pickDate(_licenseIssueController),
        ),
        const SizedBox(height: 18),
        _DateField(
          label: 'Fecha de vencimiento',
          controller: _licenseExpiryController,
          onTap: () => _pickDate(_licenseExpiryController),
        ),
        const SizedBox(height: 20),
        const _SoftInfoCard(
          title: 'Asegurate de ingresar datos correctos',
          message:
              'Estos datos seran verificados por la central antes de activar tu cuenta.',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: 'CONTINUAR',
          onPrimaryPressed: _goNextFromCurrent,
          onBackPressed: () => setState(() => _step = 4),
          onCancelPressed: _cancelRegistration,
        ),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      key: const ValueKey('driver-step-6'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          titleBlue: 'Informacion de tu',
          titleYellow: 'vehiculo',
          subtitle:
              'Ingresa los datos de tu vehiculo tal como apareceran para los pasajeros.',
        ),
        const SizedBox(height: 20),
        Text(
          'Tipo de vehiculo',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1746B5),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _VehicleOptionCard(
                title: 'Taxi',
                icon: Icons.local_taxi_rounded,
                selected: _vehicleType == 'taxi',
                onTap: () => setState(() => _vehicleType = 'taxi'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VehicleOptionCard(
                title: 'Moto',
                icon: Icons.two_wheeler_rounded,
                selected: _vehicleType == 'moto',
                onTap: () => setState(() => _vehicleType = 'moto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Placa',
          controller: _plateController,
          icon: Icons.pin_outlined,
          hintText: 'Ej: 1234ABC',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Marca',
          controller: _brandController,
          icon: Icons.directions_car_outlined,
          hintText: 'Selecciona la marca',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Modelo',
          controller: _modelController,
          icon: Icons.directions_car_filled_outlined,
          hintText: 'Selecciona el modelo',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Color',
          controller: _colorController,
          icon: Icons.palette_outlined,
          hintText: 'Selecciona el color',
        ),
        const SizedBox(height: 18),
        _FormField(
          label: 'Anio',
          controller: _yearController,
          icon: Icons.calendar_month_outlined,
          hintText: 'Ej: 2020',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
        ),
        const SizedBox(height: 20),
        const _SoftInfoCard(
          title: 'Datos importantes',
          message:
              'Esta informacion ayudara a que los pasajeros identifiquen tu vehiculo correctamente.',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: 'CONTINUAR',
          onPrimaryPressed: _goNextFromCurrent,
          onBackPressed: () => setState(() => _step = 5),
          onCancelPressed: _cancelRegistration,
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      key: const ValueKey('driver-step-7'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          titleBlue: 'Sube tus',
          titleYellow: 'fotografias',
          subtitle:
              'Necesitamos estas fotografias para verificar tu identidad y tu vehiculo antes de activar tu cuenta.',
        ),
        const SizedBox(height: 22),
        _PhotoRequirementCard(
          title: 'Foto del conductor',
          description: 'Tomate una foto clara de tu rostro.',
          bulletItems: const [
            'Rostro visible y centrado',
            'Buena iluminacion',
            'Sin gafas oscuras',
            'Fondo claro',
          ],
          ready: _driverPhotoReady,
          onToggle: () =>
              setState(() => _driverPhotoReady = !_driverPhotoReady),
        ),
        const SizedBox(height: 16),
        _PhotoRequirementCard(
          title: 'Foto de tu licencia',
          description: 'Toma una foto clara de tu licencia de conducir.',
          bulletItems: const [
            'Toda la licencia visible',
            'Texto legible',
            'Sin reflejos',
            'Buena calidad',
          ],
          ready: _licensePhotoReady,
          onToggle: () =>
              setState(() => _licensePhotoReady = !_licensePhotoReady),
        ),
        const SizedBox(height: 16),
        _PhotoRequirementCard(
          title: 'Foto de tu vehiculo',
          description: 'Toma una foto clara de tu vehiculo.',
          bulletItems: const [
            'Vista frontal o lateral',
            'Placa visible',
            'Buena iluminacion',
            'Sin objetos que lo cubran',
          ],
          ready: _vehiclePhotoReady,
          onToggle: () =>
              setState(() => _vehiclePhotoReady = !_vehiclePhotoReady),
        ),
        const SizedBox(height: 18),
        const _DevelopmentTagBanner(
          message:
              'Etapa de desarrollo. La carga real de imagenes se integrara despues; por ahora puedes marcar cada bloque como listo y seguir al siguiente paso.',
        ),
        const SizedBox(height: 20),
        const _SoftInfoCard(
          title: 'Tu seguridad es importante',
          message:
              'Estas fotografias seran revisadas por nuestra central y utilizadas unicamente para verificar tu cuenta.',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: 'CONTINUAR',
          onPrimaryPressed: _goNextFromCurrent,
          onBackPressed: () => setState(() => _step = 6),
          onCancelPressed: _cancelRegistration,
        ),
      ],
    );
  }

  Widget _buildReviewStep(DriverSession session) {
    return Column(
      key: const ValueKey('driver-step-8'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          titleBlue: 'Revisa tus datos',
          titleYellow: 'antes de finalizar',
          subtitle:
              'Verifica que toda la informacion sea correcta. Podras editarla si es necesario.',
        ),
        const SizedBox(height: 20),
        _ReviewBlock(
          icon: Icons.person_rounded,
          title: 'Datos personales',
          lines: [
            '${_firstNameController.text} ${_lastNameController.text}'.trim(),
            session.phone,
            _emailController.text.isEmpty
                ? 'Correo pendiente'
                : _emailController.text.trim(),
            _addressController.text.trim(),
          ],
          onEdit: () => setState(() => _step = 4),
        ),
        const SizedBox(height: 14),
        _ReviewBlock(
          icon: Icons.badge_rounded,
          title: 'Licencia de conducir',
          lines: [
            'N° de licencia: ${_licenseController.text.trim()}',
            'Categoria: ${_licenseCategoryController.text.trim()}',
            'Emision: ${_licenseIssueController.text.trim()}',
            'Vencimiento: ${_licenseExpiryController.text.trim()}',
          ],
          onEdit: () => setState(() => _step = 5),
        ),
        const SizedBox(height: 14),
        _ReviewBlock(
          icon: Icons.local_taxi_rounded,
          title: 'Informacion del vehiculo',
          lines: [
            'Tipo: ${_vehicleType == 'taxi' ? 'Taxi' : 'Moto'}',
            'Placa: ${_plateController.text.trim()}',
            'Marca: ${_brandController.text.trim()}',
            'Modelo: ${_modelController.text.trim()}',
            'Color: ${_colorController.text.trim()}',
            'Anio: ${_yearController.text.trim()}',
          ],
          onEdit: () => setState(() => _step = 6),
        ),
        const SizedBox(height: 14),
        _ReviewBlock(
          icon: Icons.camera_alt_rounded,
          title: 'Fotografias',
          lines: [
            _driverPhotoReady ? 'Conductor listo' : 'Conductor pendiente',
            _licensePhotoReady ? 'Licencia lista' : 'Licencia pendiente',
            _vehiclePhotoReady ? 'Vehiculo listo' : 'Vehiculo pendiente',
          ],
          onEdit: () => setState(() => _step = 7),
        ),
        const SizedBox(height: 18),
        const _SoftInfoCard(
          title: 'Casi listo para empezar',
          message:
              'Al confirmar, tu informacion sera enviada a revision. Te notificaremos cuando tu cuenta este activa.',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: session.isLoading
              ? 'ENVIANDO...'
              : 'CONFIRMAR Y ENVIAR',
          onPrimaryPressed: session.isLoading ? null : _confirmAndSend,
          onBackPressed: () => setState(() => _step = 7),
          onCancelPressed: _cancelRegistration,
        ),
      ],
    );
  }

  Widget _buildPendingVerificationStep(DriverSession session) {
    return Column(
      key: const ValueKey('driver-step-9'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEAF1FF),
                  border: Border.all(color: const Color(0xFFD6E1FF)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 96,
                      color: Color(0xFF1746B5),
                    ),
                    Positioned(
                      right: 24,
                      bottom: 30,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF6C311),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tu cuenta esta siendo',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1746B5),
                ),
              ),
              Text(
                'verificada',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFF6BE00),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hemos recibido toda tu informacion y ya le comunicamos al administrador para que revise tus datos.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C789F),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const _SoftInfoCard(
          title: 'Te notificaremos cuando tu cuenta este activa',
          message:
              'Recibiras una notificacion en la app y podras comenzar a utilizarla.',
        ),
        const SizedBox(height: 22),
        const _SoftInfoCard(
          title: 'Gracias por registrarte en Rapigo Pro',
          message:
              'Estamos trabajando para activarte lo antes posible. ¡Bienvenido a la comunidad!',
        ),
        const SizedBox(height: 24),
        _WizardButtons(
          primaryLabel: session.isLoading
              ? 'ENVIANDO...'
              : (_profileSubmitted ? 'ACTUALIZAR ESTADO' : 'REENVIAR DATOS'),
          onPrimaryPressed: session.isLoading ? null : _finishVerification,
        ),
      ],
    );
  }
}

class _RegisterProgressBar extends StatelessWidget {
  const _RegisterProgressBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const steps = <String, int>{
      'Celular': 1,
      'Verificacion': 2,
      'Contrasena': 3,
      'Datos': 4,
      'Licencia': 5,
      'Vehiculo': 6,
      'Fotos': 7,
      'Revision': 8,
    };
    final activeEntry = steps.entries.firstWhere(
      (entry) => entry.value == step,
      orElse: () => const MapEntry('Revision', 8),
    );
    final progress = ((step - 1).clamp(0, steps.length) / steps.length);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F8)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1650D7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${activeEntry.value}',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeEntry.key,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1746B5),
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE2E8F8),
                  color: const Color(0xFFF6BE00),
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.titleBlue,
    required this.titleYellow,
    required this.subtitle,
  });

  final String titleBlue;
  final String titleYellow;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleBlue,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1746B5),
          ),
        ),
        Text(
          titleYellow,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFF6BE00),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6C789F),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hintText,
    this.keyboardType,
    this.suffixIcon,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1746B5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F8)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: const Color(0xFF1650D7), size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  cursorColor: const Color(0xFF1650D7),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    hintText: hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFA3AEC9),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2D59),
                  ),
                ),
              ),
              if (suffixIcon != null) ...[
                Icon(suffixIcon, color: const Color(0xFF1650D7), size: 18),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.hintText,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final IconData icon;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1746B5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              isExpanded: true,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2D59),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF1650D7),
              ),
              hint: Text(
                hintText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA3AEC9),
                ),
              ),
              selectedItemBuilder: (context) => items
                  .map(
                    (item) => Row(
                      children: [
                        Icon(icon, color: const Color(0xFF1650D7), size: 18),
                        const SizedBox(width: 9),
                        Text(
                          item,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2D59),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Row(
                        children: [
                          Icon(icon, color: const Color(0xFF1650D7), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            item,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2D59),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1746B5),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F8)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF1650D7),
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    controller.text.isEmpty
                        ? 'Selecciona la fecha'
                        : controller.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: controller.text.isEmpty
                          ? FontWeight.w500
                          : FontWeight.w700,
                      color: controller.text.isEmpty
                          ? const Color(0xFFA3AEC9)
                          : const Color(0xFF1D2D59),
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF1650D7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleOptionCard extends StatelessWidget {
  const _VehicleOptionCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF1650D7) : const Color(0xFFD5DCF2),
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFFE8F0FF)
                    : const Color(0xFFF5F7FC),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF1650D7)
                    : const Color(0xFF9CA8CB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? const Color(0xFF1746B5)
                      : const Color(0xFF3A4974),
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? const Color(0xFF1650D7)
                  : const Color(0xFFB8C4E4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoRequirementCard extends StatelessWidget {
  const _PhotoRequirementCard({
    required this.title,
    required this.description,
    required this.bulletItems,
    required this.ready,
    required this.onToggle,
  });

  final String title;
  final String description;
  final List<String> bulletItems;
  final bool ready;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF1650D7),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1746B5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF55648F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final bullet in bulletItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF1650D7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF42517F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    side: BorderSide(
                      color: ready
                          ? const Color(0xFF22A863)
                          : const Color(0xFF1650D7),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    ready ? Icons.check_circle_rounded : Icons.upload_rounded,
                    color: ready
                        ? const Color(0xFF22A863)
                        : const Color(0xFF1650D7),
                    size: 18,
                  ),
                  label: Text(
                    ready ? 'Lista' : 'Etapa de desarrollo',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ready
                          ? const Color(0xFF22A863)
                          : const Color(0xFF1650D7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'JPG, PNG  Max. 5MB',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B97BA),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftInfoCard extends StatelessWidget {
  const _SoftInfoCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Color(0xFF1650D7),
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1746B5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF60709A),
                    height: 1.4,
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

class _WizardButtons extends StatelessWidget {
  const _WizardButtons({
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.onBackPressed,
    this.onCancelPressed,
  });

  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onBackPressed;
  final VoidCallback? onCancelPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPrimaryPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFFF6C311),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              primaryLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (onBackPressed != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onBackPressed,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Anterior'),
          ),
        ],
        if (onCancelPressed != null) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onCancelPressed,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text(
              'Cancelar registro',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({
    required this.icon,
    required this.title,
    required this.lines,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE4F8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: const Color(0xFF1650D7), size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1746B5),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE6ECFA)),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F5D87),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DevelopmentTagBanner extends StatelessWidget {
  const _DevelopmentTagBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF6D873)),
      ),
      child: Text(
        message,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8C6A08),
          height: 1.4,
        ),
      ),
    );
  }
}
