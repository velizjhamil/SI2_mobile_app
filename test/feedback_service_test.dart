import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/services/demo_mode.dart';
import 'package:forest_microfinance/services/feedback_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final previousToken = AuthService.tokenJWT;
  final previousDemo = DemoMode.enabled;

  setUp(() {
    AuthService.tokenJWT = 'test-token-jwt';
    DemoMode.enabled = false;
  });

  tearDown(() {
    AuthService.tokenJWT = previousToken;
    DemoMode.enabled = previousDemo;
  });

  group('FeedbackService HTTP API', () {
    test('calificar envia POST /feedback con canal=MOVIL y parsea respuesta', () async {
      Uri? requestedUri;
      Map<String, String>? headers;
      String? requestBody;

      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        headers = request.headers;
        requestBody = request.body;

        return http.Response(
          jsonEncode({
            'id': 101,
            'servicio': 'CREDITO',
            'calificacion': 5,
            'recomendaria': 10,
            'comentario': 'Muy buena atención',
            'canal': 'MOVIL',
            'fecha': '2026-11-20T20:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FeedbackService(client: mockClient);
      final result = await service.calificar(
        servicio: 'CREDITO',
        calificacion: 5,
        recomendaria: 10,
        comentario: 'Muy buena atención',
        canal: 'MOVIL',
      );

      expect(result.success, isTrue);
      expect(result.value, isNotNull);
      expect(result.value!.id, 101);
      expect(result.value!.servicio, 'CREDITO');
      expect(result.value!.calificacion, 5);
      expect(result.value!.recomendaria, 10);
      expect(result.value!.comentario, 'Muy buena atención');
      expect(result.value!.canal, 'MOVIL');

      expect(requestedUri?.path, endsWith('/feedback'));
      expect(headers?['Authorization'], 'Bearer test-token-jwt');

      final decoded = jsonDecode(requestBody!);
      expect(decoded['servicio'], 'CREDITO');
      expect(decoded['calificacion'], 5);
      expect(decoded['recomendaria'], 10);
      expect(decoded['comentario'], 'Muy buena atención');
      expect(decoded['canal'], 'MOVIL');
    });

    test('calificar maneja error 422 del backend con detail', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'calificacion debe estar entre 1 y 5'}),
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FeedbackService(client: mockClient);
      final result = await service.calificar(
        servicio: 'CREDITO',
        calificacion: 6,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('calificacion debe estar entre 1 y 5'));
    });

    test('misCalificaciones obtiene lista de ratings del socio GET /feedback/mias', () async {
      Uri? requestedUri;

      final mockClient = MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'servicio': 'AHORRO',
              'calificacion': 4,
              'recomendaria': 8,
              'comentario': 'Buen servicio en caja',
              'canal': 'MOVIL',
              'fecha': '2026-11-19T15:30:00Z',
            },
            {
              'id': 2,
              'servicio': 'APP_MOVIL',
              'calificacion': 5,
              'recomendaria': null,
              'comentario': null,
              'canal': 'WEB',
              'fecha': '2026-11-18T10:00:00Z',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FeedbackService(client: mockClient);
      final result = await service.misCalificaciones();

      expect(result.success, isTrue);
      expect(result.value?.length, 2);
      expect(requestedUri?.path, endsWith('/feedback/mias'));

      final first = result.value!.first;
      expect(first.id, 1);
      expect(first.servicio, 'AHORRO');
      expect(first.servicioLabel, 'Ahorro');
      expect(first.calificacion, 4);
      expect(first.calificacionLabel, 'Satisfecho');
      expect(first.canal, 'MOVIL');

      final second = result.value![1];
      expect(second.servicio, 'APP_MOVIL');
      expect(second.servicioLabel, 'Banca Móvil');
      expect(second.calificacion, 5);
      expect(second.calificacionLabel, 'Excelente');
    });

    test('retorna error cuando no hay sesion activa', () async {
      AuthService.tokenJWT = null;
      final service = FeedbackService();

      final res1 = await service.calificar(servicio: 'CREDITO', calificacion: 5);
      expect(res1.success, isFalse);
      expect(res1.error, contains('No hay sesión activa'));

      final res2 = await service.misCalificaciones();
      expect(res2.success, isFalse);
      expect(res2.error, contains('No hay sesión activa'));
    });
  });

  group('FeedbackService Modo Demo', () {
    test('en modo demo funciona offline y almacena feedback', () async {
      DemoMode.enabled = true;
      final service = FeedbackService();

      final initial = await service.misCalificaciones();
      expect(initial.success, isTrue);
      final initialCount = initial.value!.length;

      final addResult = await service.calificar(
        servicio: 'CAJA',
        calificacion: 5,
        recomendaria: 9,
        comentario: 'Atención en ventanilla rápida',
        canal: 'MOVIL',
      );

      expect(addResult.success, isTrue);
      expect(addResult.value!.servicio, 'CAJA');

      final updated = await service.misCalificaciones();
      expect(updated.success, isTrue);
      expect(updated.value!.length, initialCount + 1);
      expect(updated.value!.first.servicio, 'CAJA');
    });
  });
}
