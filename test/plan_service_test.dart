import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/plan_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';
import 'package:forest_microfinance/services/session_manager.dart';

void main() {
  group('isModuloPermitido helper puro (S2, S7)', () {
    test('fallo de carga (info == null) permite todo según S7', () {
      expect(isModuloPermitido(null, 'banca_movil'), isTrue);
      expect(isModuloPermitido(null, 'scoring_crediticio'), isTrue);
      expect(isModuloPermitido(null, 'cualquier_modulo'), isTrue);
    });

    test('fallo de carga (fetchFailed == true) permite todo según S7', () {
      final failedInfo = PlanModulosInfo.failed();
      expect(failedInfo.fetchFailed, isTrue);
      expect(isModuloPermitido(failedInfo, 'banca_movil'), isTrue);
      expect(isModuloPermitido(failedInfo, 'scoring_crediticio'), isTrue);
    });

    test(
        'sin_restriccion == true permite cualquier módulo (S2 SuperAdmin / sin cooperativa)',
        () {
      const info = PlanModulosInfo(
        sinRestriccion: true,
        modulos: [],
      );
      expect(isModuloPermitido(info, 'banca_movil'), isTrue);
      expect(isModuloPermitido(info, 'scoring_crediticio'), isTrue);
      expect(isModuloPermitido(info, 'modulo_inexistente'), isTrue);
    });

    test(
        'módulo ausente en la lista devuelve false cuando no hay sin_restriccion ni fallo',
        () {
      const info = PlanModulosInfo(
        sinRestriccion: false,
        modulos: ['scoring_crediticio', 'reportes_gerenciales'],
      );
      expect(isModuloPermitido(info, 'banca_movil'), isFalse);
      expect(isModuloPermitido(info, 'chatbot_ia'), isFalse);
      expect(isModuloPermitido(info, 'notificaciones_socios'), isFalse);
    });

    test('módulo presente en la lista devuelve true', () {
      const info = PlanModulosInfo(
        sinRestriccion: false,
        modulos: ['banca_movil', 'scoring_crediticio'],
      );
      expect(isModuloPermitido(info, 'banca_movil'), isTrue);
      expect(isModuloPermitido(info, 'scoring_crediticio'), isTrue);
    });
  });

  group('getMensajeBloqueoModulo', () {
    test('genera el mensaje exacto con nombre del plan y módulo (S3, S5)', () {
      const info = PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: [],
      );
      expect(
        getMensajeBloqueoModulo(info, 'banca_movil'),
        'Tu plan Básico no incluye banca móvil y comprobantes digitales.',
      );
      expect(
        getMensajeBloqueoModulo(info, 'scoring_crediticio'),
        'Tu plan Básico no incluye scoring crediticio.',
      );
    });
  });

  group('Limpieza de PlanService.currentInfo (Defecto 4)', () {
    tearDown(() {
      PlanService.reset();
    });

    test('SessionManager.onUnauthorized limpia PlanService.currentInfo', () async {
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['banca_movil'],
      );
      expect(PlanService.currentInfo, isNotNull);

      await SessionManager.onUnauthorized();
      expect(PlanService.currentInfo, isNull);
    });

    test('AuthService.login limpia PlanService.currentInfo al empezar', () async {
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['banca_movil'],
      );
      expect(PlanService.currentInfo, isNotNull);

      final auth = AuthService(tokenStore: InMemorySecureTokenStore());
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Credenciales incorrectas'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      await auth.login('test@test.com', 'badpass', client: client);
      expect(PlanService.currentInfo, isNull);
    });

    test('AuthService.authenticateWithBiometrics limpia PlanService.currentInfo al empezar', () async {
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['banca_movil'],
      );
      expect(PlanService.currentInfo, isNotNull);

      final store = InMemorySecureTokenStore();
      final auth = AuthService(tokenStore: store);
      await auth.authenticateWithBiometrics();
      expect(PlanService.currentInfo, isNull);
    });
  });

  group('PlanService.fetchMisModulos', () {
    final originalToken = AuthService.tokenJWT;

    tearDown(() {
      AuthService.tokenJWT = originalToken;
      PlanService.reset();
    });

    test('sin token activo retorna PlanModulosInfo.failed()', () async {
      AuthService.tokenJWT = null;
      final service = PlanService();
      final res = await service.fetchMisModulos();
      expect(res.fetchFailed, isTrue);
      expect(isModuloPermitido(PlanService.currentInfo, 'banca_movil'), isTrue);
    });

    test('200 parsea correctamente plan, modulos y actualiza currentInfo',
        () async {
      AuthService.tokenJWT = 'token-test';
      final mockClient = MockClient((request) async {
        expect(request.url.path, endsWith('/suscripciones/mis-modulos'));
        expect(request.headers['Authorization'], 'Bearer token-test');
        return http.Response(
          jsonEncode({
            'plan': {'codigo': 'BASICO', 'nombre': 'Básico'},
            'modulos': ['reportes_gerenciales'],
            'sin_restriccion': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = PlanService();
      final res = await service.fetchMisModulos(client: mockClient);
      expect(res.fetchFailed, isFalse);
      expect(res.plan?.codigo, 'BASICO');
      expect(res.plan?.nombre, 'Básico');
      expect(res.modulos, ['reportes_gerenciales']);
      expect(res.sinRestriccion, isFalse);
      expect(PlanService.currentInfo, equals(res));
      expect(
        isModuloPermitido(PlanService.currentInfo, 'banca_movil'),
        isFalse,
      );
      expect(
        isModuloPermitido(PlanService.currentInfo, 'reportes_gerenciales'),
        isTrue,
      );
    });

    test('error 500 activa fallback permisivo (fetchFailed: true)', () async {
      AuthService.tokenJWT = 'token-test';
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = PlanService();
      final res = await service.fetchMisModulos(client: mockClient);
      expect(res.fetchFailed, isTrue);
      expect(isModuloPermitido(PlanService.currentInfo, 'banca_movil'), isTrue);
    });

    test('excepción de red activa fallback permisivo', () async {
      AuthService.tokenJWT = 'token-test';
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network down');
      });

      final service = PlanService();
      final res = await service.fetchMisModulos(client: mockClient);
      expect(res.fetchFailed, isTrue);
      expect(isModuloPermitido(PlanService.currentInfo, 'banca_movil'), isTrue);
    });
  });
}
