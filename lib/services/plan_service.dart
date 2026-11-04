import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mock_auth_service.dart';

/// Mapeo de identificadores de módulo según la especificación S2 a sus nombres legibles (S3, S5).
const Map<String, String> nombresModulos = {
  'banca_movil': 'banca móvil y comprobantes digitales',
  'scoring_crediticio': 'scoring crediticio',
  'informes_asfi': 'informes ASFI',
  'respaldos_bitacora': 'respaldos y bitácora',
  'chatbot_ia': 'chatbot con IA y dictado por voz',
  'notificaciones_socios': 'notificaciones a socios',
  'recredito_ia': 'recomendación de recrédito con IA',
  'reportes_gerenciales': 'reportes gerenciales',
};

class PlanInfo {
  final String? codigo;
  final String? nombre;

  const PlanInfo({this.codigo, this.nombre});

  factory PlanInfo.fromJson(Map<String, dynamic> json) {
    return PlanInfo(
      codigo: json['codigo']?.toString(),
      nombre: json['nombre']?.toString(),
    );
  }
}

class PlanModulosInfo {
  final PlanInfo? plan;
  final List<String> modulos;
  final bool sinRestriccion;
  final bool fetchFailed;

  const PlanModulosInfo({
    this.plan,
    this.modulos = const [],
    this.sinRestriccion = false,
    this.fetchFailed = false,
  });

  String get planNombre => plan?.nombre ?? 'actual';

  factory PlanModulosInfo.fromJson(Map<String, dynamic> json) {
    final planData = json['plan'];
    return PlanModulosInfo(
      plan:
          planData is Map<String, dynamic> ? PlanInfo.fromJson(planData) : null,
      modulos: (json['modulos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sinRestriccion: json['sin_restriccion'] == true,
      fetchFailed: false,
    );
  }

  factory PlanModulosInfo.failed() {
    return const PlanModulosInfo(fetchFailed: true);
  }
}

/// Helper puro que decide si un módulo está permitido según S2 y S7.
///
/// S7: Si mis-modulos falla (fetchFailed == true) o info es nulo, no se oculta nada (fallback permisivo).
/// S2: Si sin_restriccion == true, está permitido.
/// Si modulos incluye el módulo, está permitido. De lo contrario, está bloqueado.
bool isModuloPermitido(PlanModulosInfo? info, String modulo) {
  if (modulo.isEmpty) return true;

  // Fallo de carga o sin datos -> fallback permisivo (S7)
  if (info == null || info.fetchFailed) {
    return true;
  }

  // Superadmin, sin cooperativa, cooperativa sin suscripción (S2)
  if (info.sinRestriccion) {
    return true;
  }

  return info.modulos.contains(modulo);
}

/// Genera el mensaje de bloqueo según S3 y S5.
/// "Tu plan {nombre} no incluye {módulo}."
String getMensajeBloqueoModulo(PlanModulosInfo? info, String modulo) {
  final planNombre = info?.plan?.nombre ?? 'actual';
  final moduloNombre = nombresModulos[modulo] ?? modulo;
  return 'Tu plan $planNombre no incluye $moduloNombre.';
}

/// Servicio que consulta GET /suscripciones/mis-modulos tras el login.
class PlanService {
  static PlanModulosInfo? currentInfo;

  /// Restablece el estado de los módulos (útil al cerrar sesión o en tests).
  static void reset() {
    currentInfo = null;
  }

  /// Consulta GET /suscripciones/mis-modulos.
  /// Nunca lanza excepciones. En caso de fallo de red, estado != 200, etc.,
  /// registra PlanModulosInfo.failed() y retorna ese objeto (fallback permisivo S7).
  Future<PlanModulosInfo> fetchMisModulos({http.Client? client}) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      final info = PlanModulosInfo.failed();
      currentInfo = info;
      return info;
    }

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final url = Uri.parse('${AuthService.baseUrl}/suscripciones/mis-modulos');
      final response = await httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final info = PlanModulosInfo.fromJson(data);
        currentInfo = info;
        return info;
      } else {
        final info = PlanModulosInfo.failed();
        currentInfo = info;
        return info;
      }
    } catch (_) {
      final info = PlanModulosInfo.failed();
      currentInfo = info;
      return info;
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
  }
}
