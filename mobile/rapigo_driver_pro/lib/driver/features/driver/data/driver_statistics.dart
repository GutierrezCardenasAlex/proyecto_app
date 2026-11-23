import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';

final driverStatisticsProvider = FutureProvider.family<DriverStatistics, String>((ref, range) async {
  final session = ref.watch(driverSessionProvider);
  if (!session.loggedIn || session.token.isEmpty) throw Exception('Inicia sesión.');
  final period = switch (range) { 'Semana' => 'week', 'Mes' => 'month', _ => 'day' };
  final response = await http.get(
    Uri.parse('${AppConfig.apiBaseUrl}/admin/drivers/me/statistics?range=$period'),
    headers: {'Authorization': 'Bearer ${session.token}'},
  ).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) throw Exception('No se pudo cargar el resumen.');
  return DriverStatistics.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
});

class DriverStatistics {
  DriverStatistics.fromJson(Map<String, dynamic> json)
      : completed = (json['completed'] as num).toInt(),
        promotional = (json['promotional'] as num).toInt(),
        totalCompleted = (json['total_completed'] as num).toInt(),
        ratingCount = (json['rating_count'] as num).toInt(),
        revenue = double.parse(json['revenue'].toString()),
        rating = double.tryParse(json['rating']?.toString() ?? '') {
    if (!revenue.isFinite || revenue < 0 || completed < 0 || totalCompleted < 0 || ratingCount < 0) {
      throw const FormatException('Resumen inválido');
    }
  }
  final int completed, promotional, totalCompleted, ratingCount;
  final double revenue;
  final double? rating;
  String get ratingLabel => ratingCount > 0 && rating != null && rating!.isFinite && rating! >= 1 && rating! <= 5
      ? rating!.toStringAsFixed(1) : 'Sin datos';
}
