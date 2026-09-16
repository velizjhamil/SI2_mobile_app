import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/transferencias_service.dart';

Map<String, dynamic> _moneda({String codigo = 'BOB', String simbolo = 'Bs'}) {
  return {
    'id': 1,
    'codigo_iso': codigo,
    'nombre': 'Boliviano',
    'simbolo': simbolo,
  };
}

Map<String, dynamic> _cuenta({
  int id = 7,
  String numero = 'AH-000123',
  dynamic disponible = 900.50,
}) {
  return {
    'id': id,
    'numero': numero,
    'tipo_producto': 'Ahorro Programado',
    'saldo_disponible': disponible,
    'saldo_bloqueado': 0,
    'estado': 'ACTIVA',
    'fecha_registro': '2026-03-01',
    'socio_id': 42,
    'moneda': _moneda(),
  };
}

Map<String, dynamic> _respuesta201({dynamic monto = 150.75}) {
  return {
    'transaccion_salida_id': 101,
    'transaccion_entrada_id': 102,
    'cuenta_origen': _cuenta(),
    'cuenta_destino': _cuenta(id: 8, numero: 'AH-000124'),
    'monto': monto,
    'glosa': 'Ahorro mensual',
    'fecha_hora': '2026-09-15T10:30:00',
  };
}

void main() {
  final previousToken = AuthService.tokenJWT;

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('TransferenciasService.transferir', () {
    test('201 exitoso parsea ids, monto, glosa, fecha y cuentas anidadas',
        () async {
      AuthService.tokenJWT = 'jwt-de-prueba';

      String? capturedAuth;
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((http.Request request) async {
        capturedAuth = request.headers['Authorization'];
        capturedUrl = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_respuesta201()),
          201,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 150.75,
        glosa: 'Ahorro mensual',
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(capturedUrl.toString(),
          '${AuthService.baseUrl}/ahorros/transferencias');
      expect(capturedAuth, 'Bearer jwt-de-prueba');
      expect(capturedBody, {
        'cuenta_origen_id': 7,
        'cuenta_destino_id': 8,
        'monto': 150.75,
        'glosa': 'Ahorro mensual',
      });

      final transferencia = result.transferencia!;
      expect(transferencia.transaccionSalidaId, 101);
      expect(transferencia.transaccionEntradaId, 102);
      expect(transferencia.monto, 150.75);
      expect(transferencia.glosa, 'Ahorro mensual');
      expect(transferencia.fechaHora, '2026-09-15T10:30:00');
      expect(transferencia.cuentaOrigen.id, 7);
      expect(transferencia.cuentaOrigen.accountNumber, 'AH-000123');
      expect(transferencia.cuentaOrigen.availableBalance, 900.50);
      expect(transferencia.cuentaOrigen.currency.currencyCode, 'BOB');
      expect(transferencia.cuentaDestino.id, 8);
      expect(transferencia.cuentaDestino.accountNumber, 'AH-000124');
    });

    test('201 tolera monto como string', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode(_respuesta201(monto: '150.75')),
            201,
            headers: {'Content-Type': 'application/json'},
          ));

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 150.75,
        client: mockClient,
      );

      expect(result.success, isTrue);
      expect(result.transferencia!.monto, 150.75);
    });

    test('400 devuelve el detail del backend', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'detail': 'Saldo insuficiente para la transferencia.'}),
            400,
            headers: {'Content-Type': 'application/json'},
          ));

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 99999.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.transferencia, isNull);
      expect(result.error, 'Saldo insuficiente para la transferencia.');
    });

    test('401 retorna mensaje de sesión en español', () async {
      AuthService.tokenJWT = 'token-expirado';
      final mockClient =
          MockClient((_) async => http.Response('No autorizado', 401));

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Sesión'));
    });

    test('404 retorna mensaje fijo sin revelar cuál cuenta', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'detail': 'Cuenta 999 no encontrada'}),
            404,
            headers: {'Content-Type': 'application/json'},
          ));

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 999,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error,
          'Una de las cuentas seleccionadas no está disponible.');
    });

    test('timeout retorna mensaje de conexión en español', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async {
        throw http.ClientException('Connection timed out');
      });

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('conexión'));
    });

    test(
        'TimeoutException (respuesta perdida) no dice "no se pudo conectar": '
        'advierte que puede haberse completado', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async {
        throw TimeoutException('timed out');
      });

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      // No debe sugerir que la transferencia no llegó al servidor: la
      // respuesta pudo perderse después de que el backend ya la procesó.
      expect(result.error, isNot(contains('No se pudo conectar')));
      expect(result.error, contains('saldo'));
    });

    test('sin token retorna failure sin llamar a la red', () async {
      AuthService.tokenJWT = null;
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('{}', 201);
      });

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, 'No hay sesión activa. Inicie sesión nuevamente.');
      expect(called, isFalse);
    });

    test(
        '201 con body corrupto no dice "no se pudo conectar": el backend '
        'ya confirmó la transferencia', () async {
      AuthService.tokenJWT = 'jwt-de-prueba';
      final mockClient = MockClient((_) async => http.Response(
            '{esto no es json valido',
            201,
          ));

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      // El backend ya devolvió 201: nunca sugerir que no llegó al servidor.
      expect(result.error, isNot(contains('No se pudo conectar')));
      expect(result.error, contains('se realizó'));
    });

    test('sin token vacío retorna failure sin llamar a la red', () async {
      AuthService.tokenJWT = '';
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('{}', 201);
      });

      final result = await TransferenciasService().transferir(
        cuentaOrigenId: 7,
        cuentaDestinoId: 8,
        monto: 100.0,
        client: mockClient,
      );

      expect(result.success, isFalse);
      expect(result.error, 'No hay sesión activa. Inicie sesión nuevamente.');
      expect(called, isFalse);
    });
  });
}
