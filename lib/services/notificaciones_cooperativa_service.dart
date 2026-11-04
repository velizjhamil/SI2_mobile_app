import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mock_auth_service.dart';
import 'plan_service.dart';

/// Notificación enviada por la cooperativa (recordatorio de pago, promoción o aviso).
class NotificacionCooperativa {
  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool leida;

  const NotificacionCooperativa({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.leida,
  });

  factory NotificacionCooperativa.fromJson(Map<String, dynamic> json) {
    return NotificacionCooperativa(
      id: (json['id'] as num).toInt(),
      tipo: json['tipo']?.toString() ?? 'AVISO',
      titulo: json['titulo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      leida: json['leida'] == true,
    );
  }
}

/// Bandeja del socio: GET /notificaciones/mias y marcado como leídas.
///
/// Nunca lanza: devuelve `null` (consulta) o `false` (marcado) ante cualquier
/// error, porque se usa desde un sondeo periódico en segundo plano.
class NotificacionesCooperativaService {
  final http.Client? client;

  NotificacionesCooperativaService({this.client});

  Map<String, String>? _headers() {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<T?> _run<T>(Future<T?> Function(http.Client c) body) async {
    final httpClient = client ?? http.Client();
    try {
      return await body(httpClient).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<List<NotificacionCooperativa>?> listar() async {
    if (!isModuloPermitido(PlanService.currentInfo, 'notificaciones_socios')) {
      return null;
    }
    final headers = _headers();
    if (headers == null) return null;
    return _run((c) async {
      final response = await c.get(Uri.parse('${AuthService.baseUrl}/notificaciones/mias'), headers: headers);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final items = decoded is Map<String, dynamic> ? decoded['items'] : null;
      if (items is! List) return null;
      return items.whereType<Map<String, dynamic>>().map(NotificacionCooperativa.fromJson).toList();
    });
  }

  Future<bool> marcarLeida(int id) async {
    if (!isModuloPermitido(PlanService.currentInfo, 'notificaciones_socios')) {
      return false;
    }
    final headers = _headers();
    if (headers == null) return false;
    final ok = await _run((c) async {
      final response = await c.post(
          Uri.parse('${AuthService.baseUrl}/notificaciones/mias/$id/leer'), headers: headers);
      return response.statusCode == 200;
    });
    return ok ?? false;
  }

  Future<bool> marcarTodas() async {
    if (!isModuloPermitido(PlanService.currentInfo, 'notificaciones_socios')) {
      return false;
    }
    final headers = _headers();
    if (headers == null) return false;
    final ok = await _run((c) async {
      final response = await c.post(
          Uri.parse('${AuthService.baseUrl}/notificaciones/mias/leer-todas'), headers: headers);
      return response.statusCode == 200;
    });
    return ok ?? false;
  }
}
