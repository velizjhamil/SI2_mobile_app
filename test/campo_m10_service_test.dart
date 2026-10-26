import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

Map<String, dynamic> _loadM10Fixture(String filename) {
  final file = File('test/fixtures/m10/$filename');
  if (!file.existsSync()) {
    throw Exception('Fixture not found: ${file.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final previousToken = AuthService.tokenJWT;

  setUp(() {
    AuthService.tokenJWT = 'test-officer-token';
  });

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('CampoService - CU-M10 (Precalificación)', () {
    test('getSociosActivos requests GET /socios/?estado=ACTIVO and parses active members', () async {
      final fixture = _loadM10Fixture('socios_activos.json');
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getSociosActivos(client: client);

      expect(result.success, isTrue);
      expect(requestedUri!.path, endsWith('/socios/'));
      expect(requestedUri!.queryParameters['estado'], 'ACTIVO');

      final socios = result.value!;
      expect(socios.length, 9);
      expect(socios[0].id, 4);
      expect(socios[0].ci, '5559876');
      expect(socios[0].nombreCompleto, 'Mateo Terceros');
      expect(socios[1].id, 3);
      expect(socios[1].ci, '5551234');
      expect(socios[1].nombreCompleto, 'Sofia Socia');
    });

    test('getProductosActivos requests GET /creditos/productos?estado=ACTIVO and parses active credit products', () async {
      final fixture = _loadM10Fixture('productos_activos.json');
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getProductosActivos(client: client);

      expect(result.success, isTrue);
      expect(requestedUri!.path, endsWith('/creditos/productos'));
      expect(requestedUri!.queryParameters['estado'], 'ACTIVO');

      final productos = result.value!;
      expect(productos.length, 3);
      expect(productos[0].id, 2);
      expect(productos[0].codigo, 'CONS-BOB');
      expect(productos[0].nombre, 'Crédito de Consumo');
      expect(productos[0].montoMin, '1000.00');
      expect(productos[0].montoMax, '50000.00');
      expect(productos[0].plazoMinMeses, 6);
      expect(productos[0].plazoMaxMeses, 48);
      expect(productos[0].monedaSimbolo, 'Bs.');
      expect(productos[0].requiereGarantia, isFalse);

      expect(productos[1].id, 1);
      expect(productos[1].codigo, 'MICRO-BOB');
      expect(productos[1].nombre, 'Microcrédito Productivo');
      expect(productos[1].requiereGarantia, isTrue);
    });

    test('precalificar sends POST /creditos/precalificacion and parses approved result', () async {
      final fixture = _loadM10Fixture('precalificacion_aprobada.json');
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/creditos/precalificacion'));
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 3,
        productoId: 2,
        monto: '8000.00',
        plazoMeses: 24,
        ingresoMensual: '6000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
        calificacionAsfi: 'A',
        fuenteIngresos: 'DEPENDIENTE',
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isTrue);
      expect(sentBody!['socio_id'], 3);
      expect(sentBody!['producto_id'], 2);
      expect(sentBody!['monto'], '8000.00');
      expect(sentBody!['plazo_meses'], 24);
      expect(sentBody!['ingreso_mensual'], '6000.00');

      final r = result.value!;
      expect(r.precalificacion, isTrue);
      expect(r.score, 910);
      expect(r.dictamen, 'APROBADO');
      expect(r.isAprobado, isTrue);
      expect(r.isRechazado, isFalse);
      expect(r.knockouts, isEmpty);
      expect(r.factores.length, 7);
      expect(r.cuotaEstimada, '399.39');
      expect(r.relacionCuotaIngreso, '6.66');
      expect(r.probabilidadMora, '0.0492');
      expect(r.nivelRiesgo, 'BAJO');
      expect(r.socioNombre, 'Sofia Socia');
      expect(r.socioCi, '5551234');
      expect(r.productoNombre, 'Crédito de Consumo');
    });

    test('precalificar parses rejected result with knockout exception rules', () async {
      final fixture = _loadM10Fixture('precalificacion_rechazada.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 3,
        productoId: 2,
        monto: '8000.00',
        plazoMeses: 24,
        ingresoMensual: '1500.00',
        egresoMensual: '1400.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
        calificacionAsfi: 'E',
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isTrue);
      final r = result.value!;
      expect(r.score, 650);
      expect(r.dictamen, 'RECHAZADO');
      expect(r.isRechazado, isTrue);
      expect(r.knockouts.length, 2);
      expect(r.knockouts[0].codigo, 'CUOTA_SUPERA_CAPACIDAD');
      expect(r.knockouts[0].efecto, 'RECHAZADO');
      expect(r.knockouts[1].codigo, 'CALIFICACION_ASFI_CRITICA');
      expect(r.nivelRiesgo, 'MEDIO');
      expect(r.probabilidadMora, '0.3178');
    });

    test('precalificar parses manual review result with guarantee knockout', () async {
      final fixture = _loadM10Fixture('precalificacion_con_garantia.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 3,
        productoId: 1, // Requires guarantee
        monto: '8000.00',
        plazoMeses: 24,
        ingresoMensual: '6000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
        calificacionAsfi: 'A',
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isTrue);
      final r = result.value!;
      expect(r.dictamen, 'REVISION_MANUAL');
      expect(r.isRevisionManual, isTrue);
      expect(r.knockouts.length, 1);
      expect(r.knockouts[0].codigo, 'GARANTIA_INSUFICIENTE');
      expect(r.knockouts[0].efecto, 'REVISION_MANUAL');
    });

    test('precalificar returns 400 detail when amount is out of product range', () async {
      final fixture = _loadM10Fixture('precalificacion_monto_fuera_rango.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 3,
        productoId: 2,
        monto: '999999.00',
        plazoMeses: 24,
        ingresoMensual: '6000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isFalse);
      expect(result.error, 'El monto está fuera del rango permitido para el producto');
    });

    test('precalificar returns 404 detail when socio does not exist', () async {
      final fixture = _loadM10Fixture('precalificacion_socio_inexistente.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 999999,
        productoId: 2,
        monto: '5000.00',
        plazoMeses: 12,
        ingresoMensual: '6000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isFalse);
      expect(result.error, 'Socio no encontrado');
    });

    test('precalificar returns 400 detail for invalid ASFI category', () async {
      final fixture = _loadM10Fixture('precalificacion_asfi_invalida.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = PrecalificacionForm(
        socioId: 3,
        productoId: 2,
        monto: '5000.00',
        plazoMeses: 12,
        ingresoMensual: '6000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        antiguedadLaboralMeses: 48,
        calificacionAsfi: 'Z',
      );

      final result = await service.precalificar(form, client: client);

      expect(result.success, isFalse);
      expect(result.error, 'La calificación ASFI no es válida');
    });
  });
}
