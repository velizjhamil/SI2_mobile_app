import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/services/chatbot_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:http/http.dart' as http;

/// Prueba de integración REAL contra el backend (requiere la API corriendo).
///
/// Verifica que el servicio consuma `POST /chatbot/chat` de verdad, con la
/// misma URL base que usa la app (`AuthService.baseUrl`) y un token real
/// obtenido con las credenciales de prueba del socio.
void main() {
  final previousToken = AuthService.tokenJWT;

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  test('login real + chatbot real responden con datos del socio', () async {
    final loginBody = http.post(
      Uri.parse('${AuthService.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body:
          '{"correo":"socio@test.com","contrasena":"password123"}',
    ).timeout(const Duration(seconds: 10));
    final loginResponse = await loginBody;
    expect(loginResponse.statusCode, 200,
        reason: 'El backend debe estar corriendo en ${AuthService.baseUrl}');

    final token = (loginResponse.body.contains('access_token'))
        ? loginResponse.body.split('"access_token":"')[1].split('"')[0]
        : '';
    expect(token, isNotEmpty, reason: 'El login real no devolvió token');
    AuthService.tokenJWT = token;

    final result = await ChatbotService().enviarMensaje(
      mensaje: '¿Cuál es mi saldo?',
      historial: const [],
    );

    expect(result.success, isTrue,
        reason: 'El chatbot real falló: ${result.error}');
    expect(result.reply, isNotNull);
    expect(result.reply!.respuesta, isNotEmpty,
        reason: 'La respuesta del chatbot vino vacía');

    // Visible con --reporter expanded: permite confirmar si el backend
    // respondió con LLM (Gemini) o con plantilla.
    // ignore: avoid_print
    print('RESPUESTA: ${result.reply!.respuesta}');
    // ignore: avoid_print
    print('FUENTE: ${result.reply!.fuente} | INTENT: ${result.reply!.intent}');
    // ignore: avoid_print
    print('SUGERENCIAS: ${result.reply!.sugerencias.join(" | ")}');
  });
}
