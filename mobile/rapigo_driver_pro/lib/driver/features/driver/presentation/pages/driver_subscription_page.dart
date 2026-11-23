import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/config/app_config.dart';

class DriverSubscriptionPage extends StatefulWidget {
  const DriverSubscriptionPage({super.key, required this.token});
  final String token;
  @override
  State<DriverSubscriptionPage> createState() => _DriverSubscriptionPageState();
}

class _DriverSubscriptionPageState extends State<DriverSubscriptionPage> {
  late Future<Map<String, dynamic>> _future = _load();
  Future<Map<String, dynamic>> _load() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/admin/subscriptions/me'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('No se pudo consultar la suscripción.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _date(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return 'Sin fecha';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mi suscripción'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => setState(() => _future = _load()),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: const Text('No se pudo cargar. Reintentar'),
            ),
          );
        }
        final subscription =
            snapshot.data?['subscription'] as Map<String, dynamic>?;
        final history = (snapshot.data?['history'] as List?) ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              subscription == null
                  ? Icons.event_busy_outlined
                  : Icons.verified_outlined,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              subscription == null
                  ? 'Sin suscripción vigente'
                  : subscription['plan_name'].toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (subscription != null) ...[
              const SizedBox(height: 12),
              Text('Vigente hasta ${_date(subscription['expires_at'])}'),
              Text('Importe registrado: Bs ${subscription['amount']}'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Consulta aquí las vigencias registradas en tu cuenta. No se realizan cobros ni renovaciones automáticas desde esta pantalla.',
            ),
            const SizedBox(height: 24),
            Text('Historial', style: Theme.of(context).textTheme.titleLarge),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Todavía no hay registros.'),
              ),
            for (final item in history)
              Card(
                child: ListTile(
                  title: Text(item['plan_name'].toString()),
                  subtitle: Text(
                    '${_date(item['starts_at'])} → ${_date(item['expires_at'])}',
                  ),
                  trailing: Text('Bs ${item['amount']}'),
                ),
              ),
          ],
        );
      },
    ),
  );
}
