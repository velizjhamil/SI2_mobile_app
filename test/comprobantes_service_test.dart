import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/comprobante_model.dart';
import 'package:forest_microfinance/services/comprobantes_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

void main() {
  final detail = <String, dynamic>{
    'id': 86,
    'numero': 'PAG-2026-000001',
    'tipo': 'PAGO_CUOTA',
    'canal': 'MOVIL',
    'monto': '15.00',
    'moneda': 'BOB',
    'cuenta_origen': '****c3-1',
    'cuenta_destino': null,
    'credito_id': 1230,
    'numero_cuota': 1,
    'glosa': null,
    'emitido_en': '2026-10-08T07:09:45.314895+00:00',
    'codigo_verificacion': 'B2J6-K99A-H852-3DQW',
    'url_verificacion':
        'http://localhost:8000/api/v1/verificacion/comprobantes/B2J6-K99A-H852-3DQW',
  };

  setUp(() => AuthService.tokenJWT = 'test-token');

  test('parses receipt decimal strings and nullable destination', () {
    final receipt = Comprobante.fromJson(detail);
    expect(receipt.amount, '15.00');
    expect(receipt.destinationAccount, isNull);
    expect(receipt.installmentNumber, 1);
  });

  test('lists receipts with filters and bearer authorization', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response(jsonEncode([detail]), 200);
    });

    final result = await ComprobantesService().list(
      type: 'PAGO_CUOTA',
      from: '2026-10-01',
      to: '2026-10-08',
      client: client,
    );

    expect(result.success, isTrue);
    expect(result.value!.single.number, 'PAG-2026-000001');
    expect(requested!.queryParameters['tipo'], 'PAGO_CUOTA');
    expect(requested!.queryParameters['desde'], '2026-10-01');
  });

  test('gets receipt detail and returns backend detail for 404', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/86')) {
        return http.Response(jsonEncode(detail), 200);
      }
      return http.Response(
          jsonEncode({'detail': 'Comprobante no encontrado'}), 404);
    });

    final service = ComprobantesService();
    final found = await service.detail(86, client: client);
    final missing = await service.detail(999, client: client);
    expect(found.value!.verificationCode, 'B2J6-K99A-H852-3DQW');
    expect(missing.success, isFalse);
    expect(missing.error, 'Comprobante no encontrado');
  });

  test('downloads authenticated PDF bytes', () async {
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response.bytes(bytes, 200, headers: {
        'content-type': 'application/pdf',
      });
    });

    final result = await ComprobantesService().pdf(85, client: client);
    expect(result.success, isTrue);
    expect(result.value, bytes);
  });
}
