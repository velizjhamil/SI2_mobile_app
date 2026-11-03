import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_model.dart';
import 'mock_auth_service.dart';
import 'session_manager.dart';

/// Resultado de [ChatbotService.enviarMensaje].
///
/// [success] falso + [error] en español cuando no hay token, el backend
/// responde 401 u otro error, o no hay conexión. Nunca lanza.
class ChatbotResult {
  final bool success;
  final ChatbotReply? reply;
  final String? error;

  const ChatbotResult.success(this.reply)
      : success = true,
        error = null;

  const ChatbotResult.failure(this.error)
      : success = false,
        reply = null;
}

/// Consulta real al asistente: POST /api/v1/chatbot/chat.
///
/// Reutiliza el patrón de [CuentasService]: lee el token estático de
/// [AuthService] y acepta un [http.Client] inyectable para tests.
class ChatbotService {
  Future<ChatbotResult> enviarMensaje({
    required String mensaje,
    required List<ChatMessage> historial,
    http.Client? client,
  }) async {
    final token = AuthService.tokenJWT;
    if (token == null || token.isEmpty) {
      return const ChatbotResult.failure(
        'No hay sesión activa. Inicie sesión nuevamente.',
      );
    }

    final url = Uri.parse('${AuthService.baseUrl}/chatbot/chat');
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
              'mensaje': mensaje,
              'historial': historial
                  .where((m) => !m.esError && m.content.trim().isNotEmpty)
                  .map((m) => m.toJson())
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return const ChatbotResult.failure(
            'Respuesta inesperada del asistente. Intente nuevamente.',
          );
        }
        return ChatbotResult.success(ChatbotReply.fromJson(decoded));
      }

      if (response.statusCode == 401) {
        await SessionManager.onUnauthorized();
        return const ChatbotResult.failure(
          'Sesión no válida o expirada. Inicie sesión nuevamente.',
        );
      }

      if (response.statusCode == 503) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['detail'] is String &&
            (decoded['detail'] as String).contains('HTTP 429')) {
          return ChatbotResult.failure(decoded['detail'] as String);
        }
      }

      return ChatbotResult.failure(
        'Error al consultar al asistente (${response.statusCode}). Intente más tarde.',
      );
    } catch (_) {
      return const ChatbotResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }
}
