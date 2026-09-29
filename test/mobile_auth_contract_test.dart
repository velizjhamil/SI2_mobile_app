import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';
import 'package:forest_microfinance/services/session_manager.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';

class _ThrowingTokenStore extends InMemorySecureTokenStore {
  bool throwOnSave = false;
  bool throwOnClear = false;

  @override
  Future<void> saveToken(String token, {DateTime? expiresAt, String? email}) {
    if (throwOnSave) throw StateError('secure storage unavailable');
    return super.saveToken(token, expiresAt: expiresAt, email: email);
  }

  @override
  Future<void> clearToken() {
    if (throwOnClear) throw StateError('secure storage unavailable');
    return super.clearToken();
  }
}

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

  test('disabling biometrics keeps the live session and sends its bearer token',
      () async {
    final store = InMemorySecureTokenStore();
    final service = AuthService(tokenStore: store);
    AuthService.tokenJWT = 'live-token';
    await store.saveToken('stored-token');
    await store.setBiometricsEnabled(true);

    await service.disableBiometrics();

    expect(AuthService.tokenJWT, 'live-token');
    expect(await store.readToken(), isNull);
    expect(await store.biometricsEnabled(), isFalse);
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer live-token');
      return http.Response('[]', 200);
    });
    AuthService.tokenJWT = 'live-token';
    await CuentasService().listarMisCuentas(client: client);
  });

  test('biometric 401 disables storage, but network failure preserves it',
      () async {
    final invalidStore = InMemorySecureTokenStore();
    await invalidStore.saveToken('invalid');
    await invalidStore.setBiometricsEnabled(true);
    final invalid = AuthService(
      tokenStore: invalidStore,
      biometric: FakeBiometricAuthenticator(true),
    );
    final unauthorized = MockClient(
      (_) async => http.Response('{"detail":"expired"}', 401),
    );
    final invalidResult =
        await invalid.authenticateWithBiometrics(client: unauthorized);
    expect(invalidResult.success, isFalse);
    expect(await invalidStore.readToken(), isNull);
    expect(await invalidStore.biometricsEnabled(), isFalse);

    final networkStore = InMemorySecureTokenStore();
    await networkStore.saveToken('network-token');
    await networkStore.setBiometricsEnabled(true);
    final network = AuthService(
      tokenStore: networkStore,
      biometric: FakeBiometricAuthenticator(true),
    );
    final networkResult = await network.authenticateWithBiometrics(
      client: MockClient((_) async => throw TimeoutException('offline')),
    );
    expect(networkResult.success, isFalse);
    expect(networkResult.error, 'Sin conexión; intentá de nuevo');
    expect(await networkStore.readToken(), 'network-token');
    expect(await networkStore.biometricsEnabled(), isTrue);
  });

  test('enabling biometrics fails when there is no live token or storage fails',
      () async {
    AuthService.tokenJWT = null;
    final noToken = AuthService(tokenStore: InMemorySecureTokenStore());
    expect((await noToken.enableBiometrics()).success, isFalse);

    final throwing = _ThrowingTokenStore()..throwOnSave = true;
    final service = AuthService(tokenStore: throwing);
    AuthService.tokenJWT = 'live-token';
    final result = await service.enableBiometrics();
    expect(result.success, isFalse);
  });

  test('constructing an AuthService does not replace SessionManager store',
      () async {
    final configured = InMemorySecureTokenStore();
    SessionManager.configure(configured);
    AuthService(tokenStore: InMemorySecureTokenStore());
    expect(identical(AuthService.currentStore, configured), isTrue);
  });

  test('logout clears memory even when secure storage cleanup fails', () async {
    final store = _ThrowingTokenStore()..throwOnClear = true;
    final service = AuthService(tokenStore: store);
    AuthService.tokenJWT = 'live-token';
    final cleaned = await service.logout(
      client: MockClient((_) async => http.Response('{}', 204)),
    );
    expect(cleaned, isFalse);
    expect(AuthService.tokenJWT, isNull);
  });
}
