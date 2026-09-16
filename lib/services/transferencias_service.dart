import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transferencia_model.dart';
import 'mock_auth_service.dart';

/// Resultado de [TransferenciasService.transferir].
///
/// [success] falso + [error] en español cuando no hay token, el backend
/// responde 400/401/403/404 u otro error, o no hay conexión. Nunca lanza.
class TransferenciaResult {
  final bool success;
  final TransferenciaModel? transferencia;
  final String? error;

  const TransferenciaResult.success(this.transferencia)
      : success = true,
        error = null;

  const TransferenciaResult.failure(this.error)
      : success = false,
        transferencia = null;
}

/// Transferencias entre cuentas propias: POST /api/v1/ahorros/transferencias.
///
/// Reutiliza el patrón de inyección de [AuthService.login] y
/// [CuentasService.listarMisCuentas]: pasa un [http.Client] (p. ej.
/// MockClient) en tests, o ninguno en producción para usar un cliente
/// propio con timeout de 10s.
class TransferenciasService {
  Future<TransferenciaResult> transferir({
    required int cuentaOrigenId,
    required int cuentaDestinoId,
    required double monto,
    String? glosa,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const TransferenciaResult.failure(
        'No hay sesión activa. Inicie sesión nuevamente.',
      );
    }

    final url = Uri.parse('${AuthService.baseUrl}/ahorros/transferencias');
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final response = await httpClient
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'cuenta_origen_id': cuentaOrigenId,
              'cuenta_destino_id': cuentaDestinoId,
              'monto': monto,
              'glosa': glosa,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        // El backend ya CONFIRMÓ la transferencia (201). Si el cuerpo llega
        // truncado o corrupto, el problema es solo de lectura de la
        // respuesta -- nunca hay que decir "no se pudo conectar" acá, eso
        // sugeriría que la plata no se movió cuando en realidad sí.
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return TransferenciaResult.success(
              TransferenciaModel.fromJson(decoded),
            );
          }
        } catch (_) {
          // sigue abajo con el mensaje de éxito-sin-detalle
        }
        return const TransferenciaResult.failure(
          'La transferencia se realizó, pero no se pudo confirmar el '
          'detalle. Verifique sus saldos.',
        );
      }

      if (response.statusCode == 401) {
        return const TransferenciaResult.failure(
          'Sesión no válida o expirada. Inicie sesión nuevamente.',
        );
      }

      // 404 sin revelar cuál cuenta (origen o destino) no está disponible.
      if (response.statusCode == 404) {
        return const TransferenciaResult.failure(
          'Una de las cuentas seleccionadas no está disponible.',
        );
      }

      // 400 (reglas de negocio) y 403 (sin Socio): detail plano del backend.
      if (response.statusCode == 400 || response.statusCode == 403) {
        final detail = _extractDetail(response.body);
        if (detail != null && detail.isNotEmpty) {
          return TransferenciaResult.failure(detail);
        }
      }

      if (response.statusCode == 403) {
        return const TransferenciaResult.failure(
          'Su usuario no tiene una cuenta de socio asociada.',
        );
      }

      return TransferenciaResult.failure(
        'Error al realizar la transferencia (${response.statusCode}). Intente más tarde.',
      );
    } on TimeoutException {
      // El timeout no dice si el backend ya proceso la transferencia antes
      // de que la respuesta se perdiera: no la tratamos como "no llego" para
      // no invitar a un reintento ciego que duplique el movimiento de dinero.
      return const TransferenciaResult.failure(
        'No se pudo confirmar si la transferencia se completó (tiempo de '
        'espera agotado). Verifique su saldo antes de reintentar.',
      );
    } catch (_) {
      return const TransferenciaResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }
}

/// Extrae el campo "detail" plano (string) del cuerpo de error del backend.
///
/// Retorna null si el cuerpo no es JSON o "detail" no es un string plano
/// (p. ej. la lista de errores de validación 422, que no se parsea).
String? _extractDetail(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
    }
  } catch (_) {
    // Cuerpo no JSON: sin detail extraíble.
  }
  return null;
}
