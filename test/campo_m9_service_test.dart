import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';

Map<String, dynamic> _loadM9Fixture(String filename) {
  final file = File('test/fixtures/m9/$filename');
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

  group('CampoService - CU-M9 (Fotos y GPS)', () {
    test('getFotosEvaluacion parses photos list from m9 fixture', () async {
      final fixture = _loadM9Fixture('fotos_lista.json');
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getFotosEvaluacion(3, client: client);

      expect(result.success, isTrue);
      expect(requestedUri!.path, endsWith('/creditos/solicitudes/3/evaluacion/fotos'));
      final photos = result.value!;
      expect(photos.length, 3);
      expect(photos[0].id, 'negocio_demo.jpg');
      expect(photos[0].url, isNull);
      expect(photos[1].id, 'domicilio_demo.jpg');
      expect(photos[1].url, isNull);
      expect(photos[2].id, '1/3/c6a4a333-5ea0-42fa-a90e-1cf8921bb6e5.jpg');
      expect(photos[2].url, startsWith('https://storage.example.test/'));
    });

    test('subirFotoEvaluacion sends multipart request with field archivo, sets image/jpeg content type and parses 201 response', () async {
      final fixture = _loadM9Fixture('foto_subida.json');
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/creditos/solicitudes/3/evaluacion/fotos'));
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        expect(request.headers['content-type'], contains('multipart/form-data'));

        // Inspect multipart body using latin1 to safely parse binary headers
        final bodyText = latin1.decode(request.bodyBytes);
        expect(bodyText, contains('name="archivo"'));
        expect(bodyText, contains('filename="visita.jpg"'));
        // Assert exact part content type (S4/S5: image/jpeg, avoiding 415 from application/octet-stream)
        expect(bodyText, contains('content-type: image/jpeg'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final dummyBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]; // Minimal JPEG header
      final result = await service.subirFotoEvaluacion(
        3,
        bytes: dummyBytes,
        filename: 'visita.jpg',
        client: client,
      );

      expect(result.success, isTrue);
      final photos = result.value!;
      expect(photos.length, 3);
      expect(photos.last.id, '1/3/c6a4a333-5ea0-42fa-a90e-1cf8921bb6e5.jpg');
      expect(photos.last.url, isNotNull);
    });

    test('subirFotoEvaluacion sets image/png content type when uploading PNG image', () async {
      final fixture = _loadM9Fixture('foto_subida.json');
      final client = MockClient((request) async {
        final bodyText = latin1.decode(request.bodyBytes);
        expect(bodyText, contains('content-type: image/png'));
        expect(bodyText, contains('filename="visita.png"'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final dummyPngBytes = [0x89, 0x50, 0x4E, 0x47]; // Minimal PNG header
      final result = await service.subirFotoEvaluacion(
        3,
        bytes: dummyPngBytes,
        filename: 'visita.png',
        client: client,
      );

      expect(result.success, isTrue);
    });

    test('subirFotoEvaluacion returns error detail on 415 invalid media type', () async {
      final fixture = _loadM9Fixture('foto_tipo_invalido.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.subirFotoEvaluacion(
        3,
        bytes: [0x47, 0x49, 0x46], // GIF header
        filename: 'animacion.gif',
        client: client,
      );

      expect(result.success, isFalse);
      expect(result.error, 'Solo se permiten fotografías JPEG o PNG válidas');
    });

    test('eliminarFotoEvaluacion sends DELETE encoding each segment and keeping slashes', () async {
      final fixture = _loadM9Fixture('foto_eliminada.json');
      Uri? requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.method, 'DELETE');
        expect(request.headers['Authorization'], 'Bearer test-officer-token');
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.eliminarFotoEvaluacion(
        3,
        '1/3/c6a4a333-5ea0-42fa-a90e-1cf8921bb6e5.jpg',
        client: client,
      );

      expect(result.success, isTrue);
      expect(
        requestedUri!.path,
        endsWith('/creditos/solicitudes/3/evaluacion/fotos/1/3/c6a4a333-5ea0-42fa-a90e-1cf8921bb6e5.jpg'),
      );
      final remaining = result.value!;
      expect(remaining.length, 2);
      expect(remaining.any((p) => p.id.contains('c6a4a333')), isFalse);
    });

    test('eliminarFotoEvaluacion returns 404 error detail for nonexistent photo', () async {
      final fixture = _loadM9Fixture('foto_inexistente.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.eliminarFotoEvaluacion(
        3,
        'inexistente.jpg',
        client: client,
      );

      expect(result.success, isFalse);
      expect(result.error, 'La fotografía no existe');
    });

    test('getFichaCampo parses ficha_campo_con_fotos fixture with fotografias and coordenadas', () async {
      final fixture = _loadM9Fixture('ficha_campo_con_fotos.json');
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/creditos/solicitudes/3/ficha-campo'));
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getFichaCampo(3, client: client);

      expect(result.success, isTrue);
      final ficha = result.value!;
      expect(ficha.evaluacion, isNotNull);
      expect(ficha.evaluacion!.coordenadas, '-17.7833,-63.1821');
      expect(ficha.evaluacion!.fotografias.length, 3);
      expect(ficha.evaluacion!.fotografias[0].id, 'negocio_demo.jpg');
      expect(ficha.evaluacion!.fotografias[0].url, isNull);
      expect(ficha.evaluacion!.fotografias[2].id, '1/3/c6a4a333-5ea0-42fa-a90e-1cf8921bb6e5.jpg');
      expect(ficha.evaluacion!.fotografias[2].url, startsWith('https://'));
    });

    test('getFichaCampo parses ficha_campo_legacy_photos fixture with null urls', () async {
      final fixture = _loadM9Fixture('ficha_campo_legacy_photos.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      final result = await service.getFichaCampo(3, client: client);

      expect(result.success, isTrue);
      final ficha = result.value!;
      expect(ficha.evaluacion!.fotografias.length, 2);
      expect(ficha.evaluacion!.fotografias.every((p) => p.url == null), isTrue);
    });

    test('guardarEvaluacion sends coordenadas in PUT payload', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 3,
            'numero_solicitud': 'SOL-000002',
            'monto': '8000.00',
            'plazo_meses': 10,
            'estado': 'PENDIENTE',
            'canal_origen': 'VENTANILLA',
            'requiere_evaluacion': false,
            'socio': {'nombre_completo': 'Diego Vargas', 'ci': '8877004 SC'},
            'producto': {'nombre': 'Crédito Demo'},
            'moneda': {'simbolo': 'Bs.'},
          }),
          200,
        );
      });

      final service = CampoService();
      const form = EvaluacionCampoForm(
        ingresoMensual: '6500.00',
        egresoMensual: '2500.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'DEPENDIENTE',
        antiguedadLaboralMeses: 24,
        calificacionAsfi: 'A',
        coordenadas: '-17.783300,-63.182100',
      );

      final result = await service.guardarEvaluacion(3, form, client: client);
      expect(result.success, isTrue);
      expect(sentBody!['evaluacion']['coordenadas'], '-17.783300,-63.182100');
    });

    test('guardarEvaluacion strips Value error prefix from 422 pydantic coordinates error', () async {
      final fixture = _loadM9Fixture('coordenadas_invalidas.json');
      final client = MockClient((request) async {
        return http.Response(jsonEncode(fixture['body']), fixture['status'] as int);
      });

      final service = CampoService();
      const form = EvaluacionCampoForm(
        ingresoMensual: '6500.00',
        egresoMensual: '2500.00',
        cuotaDeudasMensual: '0.00',
        actividadEconomica: 'Comercio',
        fuenteIngresos: 'DEPENDIENTE',
        antiguedadLaboralMeses: 24,
        calificacionAsfi: 'A',
        coordenadas: '95,-63.18', // Invalid latitude > 90
      );

      final result = await service.guardarEvaluacion(3, form, client: client);
      expect(result.success, isFalse);
      expect(result.error, 'La latitud debe estar entre -90 y 90 grados');
      expect(result.error, isNot(contains('Value error, ')));
    });
  });
}
