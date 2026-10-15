import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/socio_model.dart';
import '../models/comprobante_model.dart';
import 'mock_auth_service.dart';
import 'session_manager.dart';

class SocioResult<T> {
  final bool success;
  final T? value;
  final String? error;
  const SocioResult.success(this.value)
      : success = true,
        error = null;
  const SocioResult.failure(this.error)
      : success = false,
        value = null;
}

class SocioService {
  Future<SocioResult<ExtractoCuenta>> extracto(
    int accountId, {
    String? from,
    String? to,
    int limit = 50,
    int offset = 0,
    http.Client? client,
  }) async {
    final query = <String, String>{
      if (from != null) 'desde': from,
      if (to != null) 'hasta': to,
      'limit': '$limit',
      'offset': '$offset',
    };
    return _get('/socio/cuentas/$accountId/extracto', query,
        ExtractoCuenta.fromJson, client);
  }

  Future<SocioResult<List<SocioCredit>>> credits({http.Client? client}) async {
    return _getList('/socio/creditos', SocioCredit.fromJson, client);
  }

  Future<SocioResult<Map<String, dynamic>>> debt(int creditId,
          {http.Client? client}) =>
      _getMap('/socio/creditos/$creditId/deuda', client);

  Future<SocioResult<CreditPayment>> payCredit(
    int creditId,
    int savingsAccountId, {
    http.Client? client,
  }) async {
    final result = await _request(
      'POST',
      '/socio/creditos/$creditId/pagos',
      body: {'cuenta_ahorro_id': savingsAccountId},
      client: client,
    );
    if (!result.success) return SocioResult.failure(result.error);
    final rawReceipt = result.value!['comprobante'];
    final receipt = rawReceipt is Map
        ? Comprobante.fromJson(rawReceipt.cast<String, dynamic>())
        : null;
    return SocioResult.success(
        CreditPayment(result.value!, comprobante: receipt));
  }

  Future<SocioResult<List<Map<String, dynamic>>>> paymentHistory(
    int creditId, {
    http.Client? client,
  }) =>
      _getMapList('/socio/creditos/$creditId/pagos', client: client);

  Future<SocioResult<CreditSchedule>> creditSchedule(
    int creditId, {
    http.Client? client,
  }) =>
      _get('/socio/creditos/$creditId/cronograma', null,
          CreditSchedule.fromJson, client);

  Future<SocioResult<List<Dpf>>> dpfs({http.Client? client}) =>
      _getList('/socio/dpf', Dpf.fromJson, client);

  Future<SocioResult<Dpf>> dpfDetail(int dpfId, {http.Client? client}) =>
      _get('/socio/dpf/$dpfId', null, Dpf.fromJson, client);

  Future<SocioResult<List<RecreditOffer>>> offers({http.Client? client}) =>
      _getList('/socio/recreditos', RecreditOffer.fromJson, client);

  Future<SocioResult<Map<String, dynamic>>> acceptOffer(
    int offerId, {
    int? termMonths,
    http.Client? client,
  }) async {
    final result = await _request(
      'POST',
      '/socio/recreditos/$offerId/aceptar',
      body: {if (termMonths != null) 'plazo_meses': termMonths},
      client: client,
    );
    return result;
  }

  Future<SocioResult<Map<String, dynamic>>> discardOffer(
    int offerId, {
    http.Client? client,
  }) =>
      _request('POST', '/socio/recreditos/$offerId/descartar', client: client);

  Future<SocioResult<List<ProductoCreditoSocio>>> creditProducts({
    http.Client? client,
  }) =>
      _getList('/socio/productos-credito', ProductoCreditoSocio.fromJson, client);

  Future<SocioResult<SimulacionCredito>> simulateCredit({
    required int productId,
    required String amount,
    required int termMonths,
    http.Client? client,
  }) =>
      _get(
        '/socio/creditos/simulacion',
        {
          'producto_id': '$productId',
          'monto': amount,
          'plazo_meses': '$termMonths',
        },
        SimulacionCredito.fromJson,
        client,
      );

  Future<SocioResult<SolicitudCreditoItem>> createCreditRequest({
    required int productId,
    required String amount,
    required int termMonths,
    required String destination,
    String? destinationDetail,
    required DatosDeclarados declaredData,
    http.Client? client,
  }) async {
    final body = {
      'producto_id': productId,
      'monto': amount,
      'plazo_meses': termMonths,
      'destino': destination,
      if (destinationDetail != null && destinationDetail.trim().isNotEmpty)
        'destino_detalle': destinationDetail.trim(),
      'datos_declarados': declaredData.toJson(),
    };
    final result = await _request(
      'POST',
      '/socio/solicitudes',
      body: body,
      client: client,
    );
    return result.success
        ? SocioResult.success(SolicitudCreditoItem.fromJson(result.value!))
        : SocioResult.failure(result.error);
  }

  Future<SocioResult<List<SolicitudCreditoItem>>> creditRequests({
    http.Client? client,
  }) =>
      _getList('/socio/solicitudes', SolicitudCreditoItem.fromJson, client);

  Future<SocioResult<SolicitudCreditoDetalle>> creditRequestDetail(
    int requestId, {
    http.Client? client,
  }) =>
      _get('/socio/solicitudes/$requestId', null,
          SolicitudCreditoDetalle.fromJson, client);

  Future<SocioResult<SolicitudCreditoItem>> cancelCreditRequest(
    int requestId, {
    required String reason,
    http.Client? client,
  }) async {
    final result = await _request(
      'POST',
      '/socio/solicitudes/$requestId/cancelar',
      body: {'motivo': reason},
      client: client,
    );
    return result.success
        ? SocioResult.success(SolicitudCreditoItem.fromJson(result.value!))
        : SocioResult.failure(result.error);
  }

  Future<SocioResult<T>> _get<T>(
    String path,
    Map<String, String>? query,
    T Function(Map<String, dynamic>) parser,
    http.Client? client,
  ) async {
    final result = await _request('GET', path, query: query, client: client);
    return result.success
        ? SocioResult.success(parser(result.value!))
        : SocioResult.failure(result.error);
  }

  Future<SocioResult<List<T>>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parser,
    http.Client? client,
  ) async {
    final result = await _request('GET', path, client: client);
    if (!result.success) return SocioResult.failure(result.error);
    final raw = result.value!['data'] ??
        result.value!['items'] ??
        result.value!['value'];
    final list = raw is List ? raw : result.value!['_list'];
    return SocioResult.success((list is List ? list : const [])
        .whereType<Map>()
        .map((item) => parser(item.cast<String, dynamic>()))
        .toList());
  }

  Future<SocioResult<Map<String, dynamic>>> _getMap(
          String path, http.Client? client) =>
      _request('GET', path, client: client);

  Future<SocioResult<List<Map<String, dynamic>>>> _getMapList(
    String path, {
    http.Client? client,
  }) async {
    final result = await _request('GET', path, client: client);
    if (!result.success) return SocioResult.failure(result.error);
    final list = result.value!['_list'];
    return SocioResult.success(list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const []);
  }

  Future<SocioResult<SocioPerfil>> perfil({http.Client? client}) async {
    return _get('/socio/perfil', null, SocioPerfil.fromJson, client);
  }

  Future<SocioResult<SocioPerfil>> updatePerfil({
    String? direccion,
    String? telefono,
    String? correo,
    http.Client? client,
  }) async {
    final body = <String, dynamic>{
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (correo != null) 'correo': correo,
    };
    final res =
        await _request('PATCH', '/socio/perfil', body: body, client: client);
    if (!res.success) return SocioResult.failure(res.error);
    return SocioResult.success(SocioPerfil.fromJson(res.value!));
  }

  Future<SocioResult<Map<String, dynamic>>> deposit({
    required int accountId,
    required double amount,
    String? concept,
    http.Client? client,
  }) async {
    return _request(
      'POST',
      '/socio/cuentas/$accountId/depositos',
      body: {
        'monto': amount,
        if (concept != null) 'concepto': concept,
      },
      client: client,
    );
  }

  Future<SocioResult<Map<String, dynamic>>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const SocioResult.failure(
          'No hay sesión activa. Inicie sesión nuevamente.');
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
      } else if (method == 'PATCH') {
        response = await httpClient
            .patch(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      } else {
        response = await httpClient
            .post(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 10));
      }
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) return SocioResult.success({'_list': decoded});
        return SocioResult.success(
            decoded is Map<String, dynamic> ? decoded : {});
      }
      if (response.statusCode == 401) {
        await SessionManager.onUnauthorized();
        return const SocioResult.failure(
            'Sesión no válida o expirada. Inicie sesión nuevamente.');
      }
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is String && detail.isNotEmpty) {
        return SocioResult.failure(detail);
      }
      if (detail is List && detail.isNotEmpty) {
        final messages = detail.map((item) {
          if (item is Map && item.containsKey('msg')) {
            return item['msg'].toString().replaceFirst('Value error, ', '');
          }
          return item.toString();
        }).join('; ');
        return SocioResult.failure(messages);
      }
      return SocioResult.failure(
          'Error del servidor (${response.statusCode}). Intente más tarde.');
    } on TimeoutException {
      return const SocioResult.failure(
          'Tiempo de espera agotado. Intente nuevamente.');
    } catch (_) {
      return const SocioResult.failure(
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
}
