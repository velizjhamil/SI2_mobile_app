import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/chat_model.dart';
import 'package:forest_microfinance/services/chatbot_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

void main() {
  final previousToken = AuthService.tokenJWT;

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('ChatbotService.enviarMensaje', () {
    test('envía URL, header y body exactos y parsea la respuesta', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';

      String? capturedAuth;
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedAuth = request.headers['Authorization'];
        capturedUrl = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'respuesta': 'Sofia Socia, tu ahorro total es 1 250.50.',
            'intent': 'ahorro',
            'fuente': 'PLANTILLA',
            'datos': {},
            'sugerencias': ['¿Cuál es mi saldo?', '¿Tengo cuotas vencidas?'],
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final result = await ChatbotService().enviarMensaje(
        mensaje: '¿Cuál es mi saldo?',
        historial: const [
          ChatMessage(role: 'assistant', content: 'Hola, soy Castor.'),
        ],
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(capturedUrl.toString(), '${AuthService.baseUrl}/chatbot/chat');
      expect(capturedAuth, 'Bearer jwt-de-prueba');
      expect(capturedBody?['mensaje'], '¿Cuál es mi saldo?');
      final historial = capturedBody?['historial'] as List<dynamic>;
      expect(historial, hasLength(1));
      expect(historial[0], {'role': 'assistant', 'content': 'Hola, soy Castor.'});

      expect(result.reply, isNotNull);
      expect(result.reply!.respuesta, contains('ahorro total'));
      expect(result.reply!.intent, 'ahorro');
      expect(result.reply!.sugerencias, hasLength(2));
    });

    test('omite del historial mensajes de error y vacíos', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';

      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((http.Request request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'respuesta': 'ok', 'sugerencias': []}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [
          ChatMessage(role: 'user', content: '  '),
          ChatMessage(role: 'assistant', content: 'fallo', esError: true),
          ChatMessage(role: 'user', content: 'hola'),
        ],
        client: mockClient,
      );

      final historial = capturedBody?['historial'] as List<dynamic>;
      expect(historial, hasLength(1));
      expect(historial[0], {'role': 'user', 'content': 'hola'});
    });

    test('tolera respuesta sin sugerencias', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'respuesta': 'Sin sugerencias', 'intent': 'ayuda'}),
            200,
            headers: {'Content-Type': 'application/json'},
          ));

      final result = await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [],
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.reply!.respuesta, 'Sin sugerencias');
      expect(result.reply!.sugerencias, isEmpty);
    });

    test('sin token retorna failure claro sin crashear ni usar la red',
        () async {
      AuthService.tokenJWT = null;
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });

      final result = await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [],
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.reply, isNull);
      expect(result.error, contains('sesión'));
      expect(called, isFalse);
    });

    test('401 retorna failure de sesión en español', () async {
      AuthService.tokenJWT = 'token-expirado';
      final mockClient =
          MockClient((_) async => http.Response('No autorizado', 401));

      final result = await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [],
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Sesión'));
    });

    test('error 500 retorna failure sin crashear', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response('Error', 500));

      final result = await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [],
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('500'));
    });

    test('error de red retorna failure en español', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async {
        throw http.ClientException('connection refused');
      });

      final result = await ChatbotService().enviarMensaje(
        mensaje: 'hola',
        historial: const [],
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('conexión'));
    });
  });
}
