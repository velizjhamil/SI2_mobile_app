import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

void main() {
  group('AuthService.login envía JSON', () {
    test('usa header application/json y body con correo/contrasena exactos',
        () async {
      String? capturedContentType;
      Map<String, dynamic>? capturedBody;
      Uri? capturedUrl;

      final mockClient = MockClient((http.Request request) async {
        capturedUrl = request.url;
        capturedContentType = request.headers['Content-Type'];
        capturedBody =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'access_token': 'token-test-123'}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final service = AuthService();
      final result = await service.login(
        '  usuario@cooperativa.com  ',
        'CoopIA#2026',
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.token, 'token-test-123');
      expect(
        capturedUrl.toString(),
        '${AuthService.baseUrl}/auth/login',
      );
      // Header exacto exigido.
      expect(capturedContentType, 'application/json');
      // Body exacto exigido: email con trim, clave sin modificar.
      expect(
        capturedBody,
        {'correo': 'usuario@cooperativa.com', 'contrasena': 'CoopIA#2026'},
      );
    });

    test('401 devuelve error de credenciales en español', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 401));

      final result = await AuthService()
          .login('a@b.com', 'clave123', client: mockClient);

      expect(result.success, isFalse);
      expect(result.error, contains('Credenciales inválidas'));
    });

    test('400 devuelve error de credenciales en español', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 400));

      final result = await AuthService()
          .login('a@b.com', 'clave123', client: mockClient);

      expect(result.success, isFalse);
      expect(result.error, contains('Credenciales inválidas'));
    });
  });
}
