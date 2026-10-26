import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/campo_model.dart';
import 'mock_auth_service.dart';
import 'session_manager.dart';

class CampoResult<T> {
  final bool success;
  final T? value;
  final String? error;

  const CampoResult.success(this.value)
      : success = true,
        error = null;

  const CampoResult.failure(this.error)
      : success = false,
        value = null;
}

class CampoService {
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    final query = <String, String>{
      'requiere_evaluacion': '$requiereEvaluacion',
      if (canalOrigen != null && canalOrigen.isNotEmpty && canalOrigen != 'TODOS')
        'canal_origen': canalOrigen,
    };
    return _getList(
      '/creditos/solicitudes',
      query,
      SolicitudResumenCampo.fromJson,
      client,
    );
  }

  Future<CampoResult<FichaCampo>> getFichaCampo(
    int solicitudId, {
    http.Client? client,
  }) async {
    return _get(
      '/creditos/solicitudes/$solicitudId/ficha-campo',
      null,
      FichaCampo.fromJson,
      client,
    );
  }

  Future<CampoResult<SolicitudResumenCampo>> guardarEvaluacion(
    int solicitudId,
    EvaluacionCampoForm form, {
    http.Client? client,
  }) async {
    final result = await _request(
      'PUT',
      '/creditos/solicitudes/$solicitudId',
      body: form.toJson(),
      client: client,
    );
    return result.success
        ? CampoResult.success(SolicitudResumenCampo.fromJson(result.value!))
        : CampoResult.failure(result.error);
  }

  Future<CampoResult<ScoringResultado>> calcularScoring(
    int solicitudId, {
    http.Client? client,
  }) async {
    final result = await _request(
      'POST',
      '/creditos/solicitudes/$solicitudId/evaluacion',
      body: {},
      client: client,
    );
    return result.success
        ? CampoResult.success(ScoringResultado.fromJson(result.value!))
        : CampoResult.failure(result.error);
  }

  Future<CampoResult<List<SocioPrecalificacion>>> getSociosActivos({
    http.Client? client,
  }) async {
    return _getList(
      '/socios/',
      {'estado': 'ACTIVO'},
      SocioPrecalificacion.fromJson,
      client,
    );
  }

  Future<CampoResult<List<ProductoPrecalificacion>>> getProductosActivos({
    http.Client? client,
  }) async {
    return _getList(
      '/creditos/productos',
      {'estado': 'ACTIVO'},
      ProductoPrecalificacion.fromJson,
      client,
    );
  }

  Future<CampoResult<PrecalificacionResultado>> precalificar(
    PrecalificacionForm form, {
    http.Client? client,
  }) async {
    final result = await _request(
      'POST',
      '/creditos/precalificacion',
      body: form.toJson(),
      client: client,
    );
    return result.success
        ? CampoResult.success(PrecalificacionResultado.fromJson(result.value!))
        : CampoResult.failure(result.error);
  }

  Future<CampoResult<List<FotoEvaluacionCampo>>> getFotosEvaluacion(
    int solicitudId, {
    http.Client? client,
  }) async {
    return _getList(
      '/creditos/solicitudes/$solicitudId/evaluacion/fotos',
      null,
      FotoEvaluacionCampo.fromJson,
      client,
    );
  }

  Future<CampoResult<List<FotoEvaluacionCampo>>> eliminarFotoEvaluacion(
    int solicitudId,
    String fotoId, {
    http.Client? client,
  }) async {
    final encodedFotoId =
        fotoId.split('/').map(Uri.encodeComponent).join('/');
    final result = await _request(
      'DELETE',
      '/creditos/solicitudes/$solicitudId/evaluacion/fotos/$encodedFotoId',
      client: client,
    );
    if (!result.success) return CampoResult.failure(result.error);
    final raw = result.value!['_list'] ??
        result.value!['data'] ??
        result.value!['items'];
    final list = raw is List ? raw : const [];
    return CampoResult.success(list
        .whereType<Map>()
        .map((item) =>
            FotoEvaluacionCampo.fromJson(item.cast<String, dynamic>()))
        .toList());
  }

  Future<CampoResult<List<FotoEvaluacionCampo>>> subirFotoEvaluacion(
    int solicitudId, {
    required List<int> bytes,
    required String filename,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const CampoResult.failure(
        'No hay sesión activa. Inicie sesión nuevamente.',
      );
    }

    final url = Uri.parse(
      '${AuthService.baseUrl}/creditos/solicitudes/$solicitudId/evaluacion/fotos',
    );
    final httpClient = client ?? http.Client();
    final close = client == null;

    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      final ext = filename.split('.').last.toLowerCase();
      final isPng = ext == 'png';
      final mimeType = isPng ? 'png' : 'jpeg';

      request.files.add(
        http.MultipartFile.fromBytes(
          'archivo',
          bytes,
          filename: filename,
          contentType: http.MediaType('image', mimeType),
        ),
      );

      final streamedResponse = await httpClient
          .send(request)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      final result = await _handleResponse(response);
      if (!result.success) return CampoResult.failure(result.error);

      final raw = result.value!['_list'] ??
          result.value!['data'] ??
          result.value!['items'];
      final list = raw is List ? raw : const [];
      return CampoResult.success(list
          .whereType<Map>()
          .map((item) =>
              FotoEvaluacionCampo.fromJson(item.cast<String, dynamic>()))
          .toList());
    } on TimeoutException {
      return const CampoResult.failure(
        'Tiempo de espera agotado. Intente nuevamente.',
      );
    } catch (_) {
      return const CampoResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (close) httpClient.close();
    }
  }

  Future<CampoResult<T>> _get<T>(
    String path,
    Map<String, String>? query,
    T Function(Map<String, dynamic>) parser,
    http.Client? client,
  ) async {
    final result = await _request('GET', path, query: query, client: client);
    return result.success
        ? CampoResult.success(parser(result.value!))
        : CampoResult.failure(result.error);
  }

  Future<CampoResult<List<T>>> _getList<T>(
    String path,
    Map<String, String>? query,
    T Function(Map<String, dynamic>) parser,
    http.Client? client,
  ) async {
    final result = await _request('GET', path, query: query, client: client);
    if (!result.success) return CampoResult.failure(result.error);
    final raw = result.value!['data'] ??
        result.value!['items'] ??
        result.value!['value'];
    final list = raw is List ? raw : result.value!['_list'];
    return CampoResult.success((list is List ? list : const [])
        .whereType<Map>()
        .map((item) => parser(item.cast<String, dynamic>()))
        .toList());
  }

  Future<CampoResult<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const CampoResult.failure(
        'No hay sesión activa. Inicie sesión nuevamente.',
      );
    }

    final base = Uri.parse('${AuthService.baseUrl}$path');
    final url = query == null ? base : base.replace(queryParameters: query);
    final httpClient = client ?? http.Client();
    final close = client == null;

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
      } else if (method == 'PUT') {
        response = await httpClient
            .put(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      } else if (method == 'DELETE') {
        response = await httpClient
            .delete(url, headers: headers)
            .timeout(const Duration(seconds: 10));
      } else {
        response = await httpClient
            .post(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      }

      return await _handleResponse(response);
    } on TimeoutException {
      return const CampoResult.failure(
        'Tiempo de espera agotado. Intente nuevamente.',
      );
    } catch (_) {
      return const CampoResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (close) httpClient.close();
    }
  }

  Future<CampoResult<Map<String, dynamic>>> _handleResponse(
    http.Response response,
  ) async {
    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is List) return CampoResult.success({'_list': decoded});
      return CampoResult.success(
        decoded is Map<String, dynamic> ? decoded : {},
      );
    }

    if (response.statusCode == 401) {
      await SessionManager.onUnauthorized();
      return const CampoResult.failure(
        'Sesión no válida o expirada. Inicie sesión nuevamente.',
      );
    }

    final detail = decoded is Map ? decoded['detail'] : null;
    if (detail is String && detail.isNotEmpty) {
      return CampoResult.failure(detail);
    }
    if (detail is List && detail.isNotEmpty) {
      final messages = detail.map((item) {
        if (item is Map && item.containsKey('msg')) {
          return item['msg'].toString().replaceFirst('Value error, ', '');
        }
        return item.toString();
      }).join('; ');
      return CampoResult.failure(messages);
    }

    return CampoResult.failure(
      'Error del servidor (${response.statusCode}). Intente más tarde.',
    );
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
