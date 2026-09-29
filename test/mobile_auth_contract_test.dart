import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';

void main() {
  test('password login validates /auth/me and accepts a socio role', () async {
    final store = InMemorySecureTokenStore();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode({'access_token': 'jwt-socio'}), 200);
      }
      expect(request.headers['Authorization'], 'Bearer jwt-socio');
      return http.Response(
        jsonEncode({
          'id': 12,
          'nombre': 'Sofia Socia',
          'correo': 'socio@test.com',
          'estado': 'ACTIVO',
          'fecha_creacion': '2026-09-24T21:55:25.173985Z',
          'rol': {
            'id': 6,
            'nombre': 'SOCIO',
            'descripcion':
                'Socio / Cliente: acceso limitado a su propia información',
            'permisos': [
              {
                'id': 6,
                'nombre': 'APP_SOCIO_READ',
                'descripcion': 'Consulta de saldos y extractos',
              },
            ],
          },
          'cooperativa_id': 1,
        }),
        200,
      );
    });

    final result = await AuthService(tokenStore: store).login(
      'socio@test.com',
      'password',
      client: client,
    );

    expect(result.success, isTrue);
    expect(result.token, 'jwt-socio');
    expect(AuthService.tokenJWT, 'jwt-socio');
  });

  test('password login rejects roles outside the mobile contract', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode({'access_token': 'jwt-staff'}), 200);
      }
      return http.Response(
        jsonEncode({
          'id': 2,
          'nombre': 'Cajero',
          'correo': 'staff@test.com',
          'estado': 'ACTIVO',
          'rol': {
            'id': 2,
            'nombre': 'CAJERO',
            'descripcion': 'Caja',
            'permisos': [],
          },
          'cooperativa_id': 1,
        }),
        200,
      );
    });

    final result =
        await AuthService(tokenStore: InMemorySecureTokenStore()).login(
      'staff@test.com',
      'password',
      client: client,
    );

    expect(result.success, isFalse);
    expect(
        result.error, 'Esta aplicación es para socios y oficiales de crédito');
    expect(AuthService.tokenJWT, isNull);
  });

  test('biometric login cannot succeed without an enabled stored token',
      () async {
    final biometric = FakeBiometricAuthenticator(true);
    final service = AuthService(
      tokenStore: InMemorySecureTokenStore(),
      biometric: biometric,
    );

    final result = await service.authenticateWithBiometrics();

    expect(result.success, isFalse);
    expect(result.error, contains('contraseña'));
    expect(biometric.prompted, isFalse);
  });

  test('logout clears memory and stored token while retaining preference',
      () async {
    final store = InMemorySecureTokenStore();
    await store.saveToken('jwt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)));
    await store.setBiometricsEnabled(true);
    AuthService.tokenJWT = 'jwt';
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/auth/logout'));
      return http.Response('{}', 204);
    });

    await AuthService(tokenStore: store).logout(client: client);

    expect(AuthService.tokenJWT, isNull);
    expect(await store.readToken(), isNull);
    expect(await store.biometricsEnabled(), isTrue);
  });
}
