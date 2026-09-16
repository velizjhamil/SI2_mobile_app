import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

Map<String, dynamic> _cuenta({
  int id = 7,
  String numero = 'AH-000123',
  String tipo = 'Ahorro Programado',
  dynamic disponible = 1250.50,
  dynamic bloqueado = 100,
  String estado = 'ACTIVA',
}) {
  return {
    'id': id,
    'numero': numero,
    'tipo_producto': tipo,
    'saldo_disponible': disponible,
    'saldo_bloqueado': bloqueado,
    'estado': estado,
    'fecha_registro': '2026-03-01',
    'socio_id': 42,
    'moneda': {
      'id': 1,
      'codigo_iso': 'BOB',
      'nombre': 'Boliviano',
      'simbolo': 'Bs',
    },
  };
}

void main() {
  final previousToken = AuthService.tokenJWT;

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('CuentasService.listarMisCuentas', () {
    test('envía header Authorization exacto y parsea saldo/moneda',
        () async {
      AuthService.tokenJWT = 'jwt-de-prueba';

      String? capturedAuth;
      Uri? capturedUrl;

      final mockClient = MockClient((http.Request request) async {
        capturedAuth = request.headers['Authorization'];
        capturedUrl = request.url;
        return http.Response(
          jsonEncode([
            _cuenta(),
            _cuenta(
              id: 8,
              numero: 'AH-000124',
              tipo: 'Ahorro Libre',
              disponible: '2500.75',
              bloqueado: '0',
            ),
          ]),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final result =
          await CuentasService().listarMisCuentas(client: mockClient);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      // URL y header exactos exigidos.
      expect(capturedUrl.toString(),
          '${AuthService.baseUrl}/ahorros/mis-cuentas');
      expect(capturedAuth, 'Bearer jwt-de-prueba');

      expect(result.cuentas, hasLength(2));
      // double directo.
      expect(result.cuentas[0].availableBalance, 1250.50);
      // string tolerado como número.
      expect(result.cuentas[1].availableBalance, 2500.75);
      // Objeto moneda anidado.
      expect(result.cuentas[0].currency.currencyCode, 'BOB');
      expect(result.cuentas[0].currency.symbol, 'Bs');
      expect(result.cuentas[0].currency.name, 'Boliviano');
      expect(result.cuentas[0].accountNumber, 'AH-000123');
      expect(result.cuentas[0].productType, 'Ahorro Programado');
    });

    test('tolera saldo_disponible como int', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode([_cuenta(disponible: 500, bloqueado: 0)]),
            200,
            headers: {'Content-Type': 'application/json'},
          ));

      final result =
          await CuentasService().listarMisCuentas(client: mockClient);

      expect(result.success, isTrue);
      expect(result.cuentas.single.availableBalance, 500.0);
    });

    test('sin token retorna failure claro sin crashear', () async {
      AuthService.tokenJWT = null;
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('[]', 200);
      });

      final result =
          await CuentasService().listarMisCuentas(client: mockClient);

      expect(result.success, isFalse);
      expect(result.cuentas, isEmpty);
      expect(result.error, contains('sesión'));
      // No debe ni intentar la red sin token.
      expect(called, isFalse);
    });

    test('401 retorna failure de sesión en español', () async {
      AuthService.tokenJWT = 'token-expirado';
      final mockClient =
          MockClient((_) async => http.Response('No autorizado', 401));

      final result =
          await CuentasService().listarMisCuentas(client: mockClient);

      expect(result.success, isFalse);
      expect(result.cuentas, isEmpty);
      expect(result.error, contains('Sesión'));
    });

    test('error 500 retorna failure sin crashear', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient =
          MockClient((_) async => http.Response('Error', 500));

      final result =
          await CuentasService().listarMisCuentas(client: mockClient);

      expect(result.success, isFalse);
      expect(result.error, contains('500'));
    });
  });
}
