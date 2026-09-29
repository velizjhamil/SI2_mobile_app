import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/solicitud_credito_model.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';

Map<String, dynamic> _loadFixture(String filename) {
  final file = File('test/fixtures/m7/$filename');
  if (!file.existsSync()) {
    throw Exception('Fixture not found: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final previousToken = AuthService.tokenJWT;
  setUp(() {
    AuthService.tokenJWT = 'test-token-jwt';
  });
  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('SolicitudCreditoService / SocioService', () {
    test('listarProductosCredito parses active credit products from real fixture', () async {
      final fixture = _loadFixture('m7_productos.json');
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/socio/productos-credito'));
        expect(request.headers['Authorization'], 'Bearer test-token-jwt');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.creditProducts(client: client);

      expect(result.success, isTrue);
      final products = result.value!;
      expect(products.length, 3);

      final p0 = products.first;
      expect(p0.id, 2);
      expect(p0.codigo, 'CONS-BOB');
      expect(p0.nombre, 'Crédito de Consumo');
      expect(p0.moneda, 'BOB');
      expect(p0.montoMin, '1000.00');
      expect(p0.montoMax, '50000.00');
      expect(p0.plazoMinMeses, 6);
      expect(p0.plazoMaxMeses, 48);
      expect(p0.tasaInteresAnual, '18.00');
      expect(p0.tipoAmortizacion, 'FRANCES');
      expect(p0.requiereGarantia, isFalse);
    });

    test('simularCredito parses simulated schedule from real fixture', () async {
      final fixture = _loadFixture('m7_simulacion.json');
      Uri? requestedUrl;
      final client = MockClient((request) async {
        requestedUrl = request.url;
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.simulateCredit(
        productId: 2,
        amount: '1500.00',
        termMonths: 6,
        client: client,
      );

      expect(result.success, isTrue);
      expect(requestedUrl!.queryParameters['producto_id'], '2');
      expect(requestedUrl!.queryParameters['monto'], '1500.00');
      expect(requestedUrl!.queryParameters['plazo_meses'], '6');

      final sim = result.value!;
      expect(sim.cuotaEstimada, '263.29');
      expect(sim.totalIntereses, '79.72');
      expect(sim.totalAPagar, '1579.72');
      expect(sim.cronograma.length, 6);

      final cuota1 = sim.cronograma.first;
      expect(cuota1.numero, 1);
      expect(cuota1.capital, '240.79');
      expect(cuota1.interes, '22.50');
      expect(cuota1.cuota, '263.29');
      expect(cuota1.saldo, '1259.21');
    });

    test('simularCredito returns 422 error detail when amount is out of range', () async {
      final fixture = _loadFixture('m7_simulacion_422.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.simulateCredit(
        productId: 2,
        amount: '100.00',
        termMonths: 6,
        client: client,
      );

      expect(result.success, isFalse);
      expect(result.error, 'El monto está fuera del rango permitido para el producto');
    });

    test('crearSolicitud sends declared data and parses created request from real fixture', () async {
      final fixture = _loadFixture('m7_solicitud_creada.json');
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/socio/solicitudes'));
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      const declared = DatosDeclarados(
        ingresoMensual: '3500.00',
        egresoMensual: '1200.00',
        actividadEconomica: 'Comercio minorista',
        fuenteIngresos: 'DEPENDIENTE',
      );

      final result = await service.createCreditRequest(
        productId: 2,
        amount: '1500.00',
        termMonths: 6,
        destination: 'CONSUMO',
        destinationDetail: 'Compra de electrodomésticos',
        declaredData: declared,
        client: client,
      );

      expect(result.success, isTrue);
      expect(sentBody!['producto_id'], 2);
      expect(sentBody!['monto'], '1500.00');
      expect(sentBody!['plazo_meses'], 6);
      expect(sentBody!['destino'], 'CONSUMO');
      expect(sentBody!['destino_detalle'], 'Compra de electrodomésticos');
      expect(sentBody!['datos_declarados']['ingreso_mensual'], '3500.00');

      final item = result.value!;
      expect(item.id, 8852);
      expect(item.numeroSolicitud, 'SOL-000004');
      expect(item.producto, 'Crédito de Consumo');
      expect(item.monto, '1500.00');
      expect(item.plazoMeses, 6);
      expect(item.destino, 'CONSUMO');
      expect(item.estado, 'PENDIENTE');
      expect(item.canalOrigen, 'MOVIL');
      expect(item.requiereEvaluacion, isTrue);
      expect(item.isPendiente, isTrue);
      expect(item.canCancel, isTrue);
    });

    test('crearSolicitud returns 409 conflict detail when another request is in progress', () async {
      final fixture = _loadFixture('m7_solicitud_409.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.createCreditRequest(
        productId: 2,
        amount: '1500.00',
        termMonths: 6,
        destination: 'CONSUMO',
        declaredData: const DatosDeclarados(
          ingresoMensual: '3000.00',
          egresoMensual: '1000.00',
          actividadEconomica: 'Comercio',
          fuenteIngresos: 'INDEPENDIENTE',
        ),
        client: client,
      );

      expect(result.success, isFalse);
      expect(result.error, 'El socio ya tiene una solicitud en curso');
    });

    test('listarSolicitudes parses history from real fixture', () async {
      final fixture = _loadFixture('m7_solicitudes.json');
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/socio/solicitudes'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.creditRequests(client: client);

      expect(result.success, isTrue);
      final list = result.value!;
      expect(list.length, 2);
      expect(list[0].id, 8852);
      expect(list[0].estado, 'PENDIENTE');
      expect(list[0].canCancel, isTrue);
      expect(list[1].id, 5429);
      expect(list[1].estado, 'DESEMBOLSADO');
      expect(list[1].canCancel, isFalse);
    });

    test('detalleSolicitud parses timeline from real fixture', () async {
      final fixture = _loadFixture('m7_solicitud_detalle.json');
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/socio/solicitudes/8852'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.creditRequestDetail(8852, client: client);

      expect(result.success, isTrue);
      final detail = result.value!;
      expect(detail.id, 8852);
      expect(detail.numeroSolicitud, 'SOL-000004');
      expect(detail.lineaTiempo.length, 1);
      expect(detail.lineaTiempo.first.estado, 'PENDIENTE');
      expect(detail.canCancel, isTrue);
    });

    test('cancelarSolicitud sends reason and parses canceled request from real fixture', () async {
      final fixture = _loadFixture('m7_solicitud_cancelada.json');
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/socio/solicitudes/8852/cancelar'));
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = SocioService();
      final result = await service.cancelCreditRequest(
        8852,
        reason: 'Ya no necesito el crédito',
        client: client,
      );

      expect(result.success, isTrue);
      expect(sentBody!['motivo'], 'Ya no necesito el crédito');
      final canceled = result.value!;
      expect(canceled.estado, 'ANULADA');
      expect(canceled.isAnulada, isTrue);
      expect(canceled.motivo, 'Ya no necesito el crédito');
      expect(canceled.canCancel, isFalse);
    });
  });
}
