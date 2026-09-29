import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

Map<String, dynamic> _loadFixture(String filename) {
  final file = File('test/fixtures/m8/$filename');
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

  group('CampoService', () {
    test('getWorklist parses pending field requests with channel filter', () async {
      final fixture = _loadFixture('worklist.json');
      Uri? requestedUrl;
      final client = MockClient((request) async {
        requestedUrl = request.url;
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getWorklist(
        requiereEvaluacion: true,
        canalOrigen: 'MOVIL',
        client: client,
      );

      expect(result.success, isTrue);
      expect(requestedUrl!.path, endsWith('/creditos/solicitudes'));
      expect(requestedUrl!.queryParameters['requiere_evaluacion'], 'true');
      expect(requestedUrl!.queryParameters['canal_origen'], 'MOVIL');

      final worklist = result.value!;
      expect(worklist.length, 2);

      final req1 = worklist.first;
      expect(req1.id, 9008);
      expect(req1.numeroSolicitud, 'SOL-000005');
      expect(req1.socioNombre, 'Sofia Socia');
      expect(req1.socioCi, '5551234');
      expect(req1.productoNombre, 'Crédito de Consumo');
      expect(req1.monto, '3000.00');
      expect(req1.plazoMeses, 12);
      expect(req1.destino, 'CONSUMO');
      expect(req1.canalOrigen, 'MOVIL');
      expect(req1.requiereEvaluacion, isFalse);
    });

    test('getFichaCampo parses field sheet with declared data, catalogos and null contact safety', () async {
      final fixture = _loadFixture('ficha_campo.json');
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/creditos/solicitudes/9008/ficha-campo'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getFichaCampo(9008, client: client);

      expect(result.success, isTrue);
      final ficha = result.value!;
      expect(ficha.solicitud.id, 9008);
      expect(ficha.solicitud.numeroSolicitud, 'SOL-000005');
      expect(ficha.solicitud.monto, '3000.0');
      expect(ficha.solicitud.requiereEvaluacion, isTrue);

      // Socio with null contact fields formatted safely
      expect(ficha.socio.nombreCompleto, 'Sofia Socia');
      expect(ficha.socio.telefonoDisplay, '—');
      expect(ficha.socio.direccionDisplay, '—');

      // Reference self-declared data
      expect(ficha.datosDeclarados, isNotNull);
      expect(ficha.datosDeclarados!.ingresoMensual, '5200.00');
      expect(ficha.datosDeclarados!.actividadEconomica, 'Venta de abarrotes');

      // Catalogues
      expect(ficha.catalogos.fuentesIngresos, contains('INDEPENDIENTE'));
      expect(ficha.catalogos.calificacionesAsfi, contains('A'));

      // Not evaluated yet
      expect(ficha.evaluacion, isNull);
    });

    test('guardarEvaluacion sends PUT with evaluacion payload and parses updated request', () async {
      final fixture = _loadFixture('evaluacion_guardada.json');
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, endsWith('/creditos/solicitudes/9008'));
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = EvaluacionCampoForm(
        ingresoMensual: '5000.00',
        egresoMensual: '2000.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Venta de abarrotes en mercado',
        fuenteIngresos: 'INDEPENDIENTE',
        antiguedadLaboralMeses: 48,
        calificacionAsfi: 'A',
        observaciones: 'Negocio verificado en visita',
      );

      final result = await service.guardarEvaluacion(9008, form, client: client);

      expect(result.success, isTrue);
      expect(sentBody!['evaluacion'], isNotNull);
      final evalMap = sentBody!['evaluacion'] as Map<String, dynamic>;
      expect(evalMap['ingreso_mensual'], '5000.00');
      expect(evalMap['antiguedad_laboral_meses'], 48);
      expect(evalMap['calificacion_asfi'], 'A');

      final updated = result.value!;
      expect(updated.id, 9008);
      expect(updated.requiereEvaluacion, isFalse);
    });

    test('calcularScoring returns score, dictamen and factors from real scoring fixture', () async {
      final fixture = _loadFixture('scoring.json');
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/creditos/solicitudes/9008/evaluacion'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.calcularScoring(9008, client: client);

      expect(result.success, isTrue);
      final scoring = result.value!;
      expect(scoring.id, 1507);
      expect(scoring.solicitudId, 9008);
      expect(scoring.score, 910);
      expect(scoring.dictamen, 'APROBADO');
      expect(scoring.factores.length, 7);
      expect(scoring.factores.first.codigo, 'CAPACIDAD_PAGO');
      expect(scoring.factores.first.puntos, 300);
      expect(scoring.explicacion, contains('Dictamen APROBADO'));
    });

    test('calcularScoring returns 422 error detail when evaluation is missing', () async {
      final fixture = _loadFixture('scoring_sin_evaluacion.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.calcularScoring(9008, client: client);

      expect(result.success, isFalse);
      expect(result.error, 'Falta la evaluación de campo del oficial');
    });
  });
}
