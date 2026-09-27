import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';

void main() {
  final previousToken = AuthService.tokenJWT;
  tearDown(() => AuthService.tokenJWT = previousToken);

  test('parses account statement while preserving decimal strings', () async {
    AuthService.tokenJWT = 'token';
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
          jsonEncode({
            'cuenta': {
              'id': 1,
              'numero_cuenta': 'AH-1',
              'moneda': 'BOB',
              'saldo_disponible': '10.00'
            },
            'desde': '2026-09-01',
            'hasta': '2026-09-27',
            'saldo_inicial': '1.10',
            'total_creditos': '10.00',
            'total_debitos': '1.10',
            'saldo_final': '10.00',
            'total': 1,
            'movimientos': [
              {
                'transaccion_id': 2,
                'fecha': '2026-09-02T10:00:00',
                'tipo': 'DEPOSITO',
                'descripcion': 'Ahorro',
                'canal': 'MOVIL',
                'monto': '8.90',
                'sentido': 'CREDITO',
                'saldo_resultante': '10.00',
              }
            ],
          }),
          200);
    });

    final result = await SocioService()
        .extracto(1, from: '2026-09-01', to: '2026-09-27', client: client);

    expect(result.success, isTrue);
    expect(requested!.queryParameters['desde'], '2026-09-01');
    expect(result.value!.openingBalance, '1.10');
    expect(result.value!.movements.single.amount, '8.90');
  });

  test('returns backend detail for business errors', () async {
    AuthService.tokenJWT = 'token';
    final client = MockClient((_) async => http.Response(
          jsonEncode({'detail': 'La cuenta no tiene saldo suficiente.'}),
          422,
        ));

    final result = await SocioService().payCredit(7, 3, client: client);

    expect(result.success, isFalse);
    expect(result.error, 'La cuenta no tiene saldo suficiente.');
  });

  test('sends bearer authorization and JSON content type on POST', () async {
    AuthService.tokenJWT = 'token-de-prueba';
    String? authorization;
    String? contentType;
    final client = MockClient((request) async {
      authorization = request.headers['Authorization'];
      contentType = request.headers['Content-Type'];
      return http.Response('{}', 201);
    });

    await SocioService().payCredit(7, 3, client: client);

    expect(authorization, 'Bearer token-de-prueba');
    expect(contentType, 'application/json');
  });

  test('parses list responses returned directly by the API', () async {
    AuthService.tokenJWT = 'token';
    final client = MockClient((_) async => http.Response(
          jsonEncode([
            {
              'id': 4,
              'numero_credito': 'CR-4',
              'producto': 'Consumo',
              'moneda': 'BOB',
              'monto_desembolsado': '100.00',
              'saldo_pendiente': '80.00',
              'estado': 'VIGENTE',
              'proxima_cuota': null,
            }
          ]),
          200,
        ));

    final result = await SocioService().credits(client: client);

    expect(result.success, isTrue);
    expect(result.value!.single.outstandingBalance, '80.00');
  });
}
