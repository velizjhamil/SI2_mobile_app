import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cuenta_ahorro_model.dart';
import 'mock_auth_service.dart';

/// Resultado de [CuentasService.listarMisCuentas].
///
/// [success] falso + [error] en español cuando no hay token, el backend
/// responde 401 u otro error, o no hay conexión. Nunca lanza.
class CuentasResult {
  final bool success;
  final List<CuentaAhorro> cuentas;
  final String? error;

  const CuentasResult.success(this.cuentas) : success = true, error = null;

  const CuentasResult.failure(this.error)
      : success = false,
        cuentas = const [];
}

/// Consulta real de saldos: GET /api/v1/ahorros/mis-cuentas.
///
/// Reutiliza el patrón de inyección de [AuthService.login]:
/// pasa un [http.Client] (p. ej. MockClient) en tests, o ninguno en
/// producción para usar un cliente propio con timeout de 5s.
class CuentasService {
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const CuentasResult.failure(
        'No hay sesión activa. Inicie sesión nuevamente.',
      );
    }

    final url = Uri.parse('${AuthService.baseUrl}/ahorros/mis-cuentas');
    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final response = await httpClient
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> raw;
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded['cuentas'] ?? [];
          raw = data is List ? data : [];
        } else {
          raw = [];
        }
        final cuentas = raw
            .whereType<Map<String, dynamic>>()
            .map(CuentaAhorro.fromJson)
            .toList();
        return CuentasResult.success(cuentas);
      }

      if (response.statusCode == 401) {
        return const CuentasResult.failure(
          'Sesión no válida o expirada. Inicie sesión nuevamente.',
        );
      }

      return CuentasResult.failure(
        'Error al consultar saldos (${response.statusCode}). Intente más tarde.',
      );
    } catch (_) {
      return const CuentasResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }
}
