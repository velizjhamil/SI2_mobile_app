import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/comprobante_model.dart';
import 'mock_auth_service.dart';
import 'session_manager.dart';

class ComprobantesResult<T> {
  final bool success;
  final T? value;
  final String? error;

  const ComprobantesResult.success(this.value)
      : success = true,
        error = null;
  const ComprobantesResult.failure(this.error)
      : success = false,
        value = null;
}

class ComprobantesService {
  Future<ComprobantesResult<List<Comprobante>>> list({
    String? type,
    String? from,
    String? to,
    http.Client? client,
  }) async {
    final result = await _request(
      'GET',
      '/socio/comprobantes',
      query: {
        if (type != null) 'tipo': type,
        if (from != null) 'desde': from,
        if (to != null) 'hasta': to,
      },
      client: client,
    );
    if (!result.success) return ComprobantesResult.failure(result.error);
    final raw = result.value is List
        ? result.value
        : (result.value as Map<String, dynamic>)['data'] ??
            (result.value as Map<String, dynamic>)['_list'];
    return ComprobantesResult.success((raw is List ? raw : const [])
        .whereType<Map>()
        .map((item) => Comprobante.fromJson(item.cast<String, dynamic>()))
        .toList());
  }

  Future<ComprobantesResult<Comprobante>> detail(
    int id, {
    http.Client? client,
  }) async {
    final result =
        await _request('GET', '/socio/comprobantes/$id', client: client);
    return result.success
        ? ComprobantesResult.success(Comprobante.fromJson(result.value!))
        : ComprobantesResult.failure(result.error);
  }

  Future<ComprobantesResult<Uint8List>> pdf(
    int id, {
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const ComprobantesResult.failure(
          'No hay sesión activa. Inicie sesión nuevamente.');
    }
    final httpClient = client ?? http.Client();
    final close = client == null;
    try {
      final response = await httpClient.get(
        Uri.parse('${AuthService.baseUrl}/socio/comprobantes/$id/pdf'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ComprobantesResult.success(response.bodyBytes);
      }
      return ComprobantesResult.failure(_detail(response.body) ??
          'No se pudo descargar el comprobante (${response.statusCode}).');
    } on TimeoutException {
      return const ComprobantesResult.failure(
          'Tiempo de espera agotado. Intente nuevamente.');
    } catch (_) {
      return const ComprobantesResult.failure(
          'No se pudo conectar con el servidor. Verifique su conexión.');
    } finally {
      if (close) httpClient.close();
    }
  }

  Future<ComprobantesResult<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const ComprobantesResult.failure(
          'No hay sesión activa. Inicie sesión nuevamente.');
    }
    final base = Uri.parse('${AuthService.baseUrl}$path');
    final url = query == null ? base : base.replace(queryParameters: query);
    final httpClient = client ?? http.Client();
    final close = client == null;
    try {
      final response = await httpClient.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) return ComprobantesResult.success({'_list': decoded});
        return ComprobantesResult.success(
            decoded is Map ? decoded.cast<String, dynamic>() : {});
      }
      if (response.statusCode == 401) {
        await SessionManager.onUnauthorized();
      }
      return ComprobantesResult.failure(_detail(response.body) ??
          'Error del servidor (${response.statusCode}). Intente más tarde.');
    } on TimeoutException {
      return const ComprobantesResult.failure(
          'Tiempo de espera agotado. Intente nuevamente.');
    } catch (_) {
      return const ComprobantesResult.failure(
          'No se pudo conectar con el servidor. Verifique su conexión.');
    } finally {
      if (close) httpClient.close();
    }
  }

  dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String? _detail(String body) {
    final decoded = _decode(body);
    final detail = decoded is Map ? decoded['detail'] : null;
    return detail is String ? detail : null;
  }
}
