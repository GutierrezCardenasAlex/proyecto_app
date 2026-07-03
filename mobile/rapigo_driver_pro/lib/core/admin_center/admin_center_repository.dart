import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class SupportReportItem {
  const SupportReportItem({
    required this.id,
    required this.category,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String category;
  final String message;
  final String status;
  final String createdAt;
}

class AdminNotificationItem {
  const AdminNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String title;
  final String message;
  final String createdAt;
}

class AdminCenterRepository {
  const AdminCenterRepository();

  Future<List<SupportReportItem>> fetchSupportReports(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/admin/support/reports'),
      headers: _headers(token),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo cargar soporte');
    final payload = (jsonDecode(response.body) as List<dynamic>? ?? const []);
    return payload
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SupportReportItem(
            id: item['id'] is num ? (item['id'] as num).toInt() : 0,
            category: item['category']?.toString() ?? 'General',
            message: item['message']?.toString() ?? '',
            status: item['status']?.toString() ?? 'ABIERTO',
            createdAt: item['created_at']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Future<void> submitSupportReport({
    required String token,
    required String category,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/admin/support/reports'),
      headers: _headers(token),
      body: jsonEncode({
        'category': category,
        'message': message,
      }),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudo enviar el reporte');
  }

  Future<List<AdminNotificationItem>> fetchNotifications(String token) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/admin/notifications/inbox'),
      headers: _headers(token),
    );
    await _throwIfError(response, fallbackMessage: 'No se pudieron cargar las notificaciones');
    final payload = (jsonDecode(response.body) as List<dynamic>? ?? const []);
    return payload
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AdminNotificationItem(
            id: item['id'] is num ? (item['id'] as num).toInt() : 0,
            kind: item['kind']?.toString() ?? 'nuevo',
            title: item['title']?.toString() ?? 'Aviso RAPIGO - PRO',
            message: item['message']?.toString() ?? '',
            createdAt: item['created_at']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> _throwIfError(http.Response response, {required String fallbackMessage}) async {
    if (response.statusCode < 400) {
      return;
    }

    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = payload['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
    } on FormatException {
      // ignore and use fallback
    }

    throw Exception('$fallbackMessage (${response.statusCode})');
  }
}
