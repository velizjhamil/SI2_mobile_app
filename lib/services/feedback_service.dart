import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/feedback_model.dart';
import 'demo_mode.dart';
import 'mock_auth_service.dart';
import 'session_manager.dart';

class FeedbackResult<T> {
  final bool success;
  final T? value;
  final String? error;

  const FeedbackResult.success(this.value)
      : success = true,
        error = null;

  const FeedbackResult.failure(this.error)
      : success = false,
        value = null;
}

class FeedbackService {
  final http.Client? client;

  FeedbackService({this.client});

  // Mock en memoria para modo demo
  static final List<EncuestaFeedback> _demoFeedbackList = [
    EncuestaFeedback(
      id: 1,
      servicio: 'CREDITO',
      calificacion: 5,
      recomendaria: 10,
      comentario: 'Excelente atención y desembolso rápido.',
      canal: 'MOVIL',
      fecha: DateTime.now().subtract(const Duration(days: 2)),
    ),
    EncuestaFeedback(
      id: 2,
      servicio: 'APP_MOVIL',
      calificacion: 4,
      recomendaria: 8,
      comentario: 'La app es muy intuitiva y rápida.',
      canal: 'MOVIL',
      fecha: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  /// Envía la calificación de un servicio (Socio).
  /// POST /feedback
  Future<FeedbackResult<EncuestaFeedback>> calificar({
    required String servicio,
    required int calificacion,
    int? recomendaria,
    String? comentario,
    String canal = 'MOVIL',
    http.Client? clientOverride,
  }) async {
    if (DemoMode.enabled) {
      final nueva = EncuestaFeedback(
        id: _demoFeedbackList.length + 1,
        servicio: servicio,
        calificacion: calificacion,
        recomendaria: recomendaria,
        comentario: (comentario?.trim().isEmpty ?? true) ? null : comentario!.trim(),
        canal: canal,
        fecha: DateTime.now(),
      );
      _demoFeedbackList.insert(0, nueva);
      return FeedbackResult.success(nueva);
    }

    final body = <String, dynamic>{
      'servicio': servicio,
      'calificacion': calificacion,
      if (recomendaria != null) 'recomendaria': recomendaria,
      if (comentario != null && comentario.trim().isNotEmpty)
        'comentario': comentario.trim(),
      'canal': canal,
    };

    final result = await _request(
      'POST',
      '/feedback',
      body: body,
      clientOverride: clientOverride,
    );

    if (!result.success) {
      return FeedbackResult.failure(result.error);
    }

    try {
      final item = EncuestaFeedback.fromJson(result.value ?? {});
      return FeedbackResult.success(item);
    } catch (_) {
      return const FeedbackResult.failure(
          'Formato de respuesta inválido del servidor.');
    }
  }

  /// Lista las calificaciones realizadas por el socio activo.
  /// GET /feedback/mias
  Future<FeedbackResult<List<EncuestaFeedback>>> misCalificaciones({
    http.Client? clientOverride,
  }) async {
    if (DemoMode.enabled) {
      return FeedbackResult.success(List.unmodifiable(_demoFeedbackList));
    }

    final result = await _request(
      'GET',
      '/feedback/mias',
      clientOverride: clientOverride,
    );

    if (!result.success) {
      return FeedbackResult.failure(result.error);
    }

    try {
      final rawList = result.value?['_list'];
      if (rawList is List) {
        final list = rawList
            .whereType<Map<String, dynamic>>()
            .map(EncuestaFeedback.fromJson)
            .toList();
        return FeedbackResult.success(list);
      }
      return const FeedbackResult.success([]);
    } catch (_) {
      return const FeedbackResult.failure(
          'Error al procesar las calificaciones del socio.');
    }
  }

  Future<FeedbackResult<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    http.Client? clientOverride,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const FeedbackResult.failure(
          'No hay sesión activa. Inicie sesión nuevamente.');
    }

    final url = Uri.parse('${AuthService.baseUrl}$path');
    final httpClient = clientOverride ?? client ?? http.Client();
    final shouldClose = clientOverride == null && client == null;

    try {
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final http.Response response;
      if (method == 'GET') {
        response = await httpClient
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 10));
      } else {
        response = await httpClient
            .post(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      }

      final decoded = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) {
          return FeedbackResult.success({'_list': decoded});
        }
        return FeedbackResult.success(
            decoded is Map<String, dynamic> ? decoded : {});
      }

      if (response.statusCode == 401) {
        await SessionManager.onUnauthorized();
        return const FeedbackResult.failure(
            'Sesión no válida o expirada. Inicie sesión nuevamente.');
      }

      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String && detail.isNotEmpty) {
        return FeedbackResult.failure(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        final messages = detail.map((item) {
          if (item is Map && item.containsKey('msg')) {
            return item['msg'].toString().replaceFirst('Value error, ', '');
          }
          return item.toString();
        }).join('; ');
        return FeedbackResult.failure(messages);
      }

      return FeedbackResult.failure(
          'Error del servidor (${response.statusCode}). Intente más tarde.');
    } on TimeoutException {
      return const FeedbackResult.failure(
          'Tiempo de espera agotado. Intente nuevamente.');
    } catch (_) {
      return const FeedbackResult.failure(
          'No se pudo conectar con el servidor. Verifique su conexión.');
    } finally {
      if (shouldClose) httpClient.close();
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
