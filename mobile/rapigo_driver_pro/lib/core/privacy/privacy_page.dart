import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({
    super.key,
    required this.token,
    required this.onOpenSupport,
  });
  final String token;
  final VoidCallback onOpenSupport;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _sending = false;
  String? _message;
  static const policyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const deletionUrl = String.fromEnvironment('ACCOUNT_DELETION_URL');

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'No se pudo abrir el enlace. Intenta de nuevo o contacta a soporte.',
        );
      }
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar eliminación de cuenta'),
        content: const Text(
          'Enviaremos a la central tu solicitud de eliminar la cuenta y los datos asociados. La central debe verificar y procesar la solicitud; enviarla no elimina la cuenta de inmediato. Puedes consultar su avance en Soporte. Los datos que deban conservarse por una obligación aplicable deben ser explicados por soporte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/admin/support/reports'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'category': 'eliminacion_cuenta',
              'message':
                  'Solicito eliminar mi cuenta RAPIGO y los datos personales asociados. Por favor confirmen la atención y cualquier retención aplicable.',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception();
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final report = body['report'] as Map<String, dynamic>?;
      if (report?['id'] == null) throw Exception();
      if (mounted) {
        setState(
          () => _message =
              'Solicitud ${report!['id']} recibida por la central. Consulta el estado en Soporte. Tu cuenta todavía no se ha eliminado.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'No pudimos confirmar la solicitud. Revisa Soporte antes de volver a enviarla.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacidad y cuenta')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Stellar Labs · RAPIGO',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Usamos tus datos de perfil y contacto para gestionar tu cuenta, los puntos de recogida y destino para prestar el servicio, y los datos de viajes para mostrar el historial y atender reportes. En RAPIGO PRO también se gestionan documentos del conductor y del vehículo para su revisión por la central.',
          ),
          const SizedBox(height: 16),
          const Text(
            'El pasajero y el conductor reciben los datos necesarios para coordinar el viaje. La ubicación del conductor se utiliza para solicitudes y seguimiento. Puedes gestionar los permisos desde los ajustes de tu dispositivo.',
          ),
          const SizedBox(height: 16),
          if (policyUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Política de privacidad completa'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _open(policyUrl),
            ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Consultar a soporte'),
            onTap: widget.onOpenSupport,
          ),
          if (deletionUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Solicitud de eliminación en la web'),
              onTap: () => _open(deletionUrl),
            ),
          const Divider(height: 32),
          Text(
            'Eliminar cuenta y datos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes iniciar una solicitud a la central desde aquí. Cerrar sesión no elimina tu cuenta.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _sending || widget.token.isEmpty
                ? null
                : _requestDeletion,
            icon: const Icon(Icons.delete_outline),
            label: Text(_sending ? 'Enviando…' : 'Solicitar eliminación'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
        ],
      ),
    ),
  );
}
