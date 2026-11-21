import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/extracto_credito_model.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/extracto_credito_screen.dart';
import 'package:forest_microfinance/services/demo_mode.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

const _sampleExtractoJson = {
  'credito': {
    'id': 1,
    'numero_credito': 'CR-2026-001',
    'producto': 'Microcrédito Individual',
    'tipo_credito': 'MICROCREDITO',
    'tipo_amortizacion': 'FRANCES',
    'moneda': 'BOB',
    'estado': 'VIGENTE',
    'monto_desembolsado': '10000.00',
    'saldo_pendiente': '8500.00',
    'tasa_interes_anual': '14.50',
    'tasa_seguro_desgravamen': '0.05',
    'plazo_meses': 12,
    'fecha_desembolso': '2026-01-15',
  },
  'desde': '2026-01-01',
  'hasta': '2026-12-31',
  'pagos': [
    {
      'id': 101,
      'fecha': '2026-02-15',
      'numero_recibo': 'REC-101',
      'numero_cuota': 1,
      'modalidad': 'VENTANILLA',
      'dias_atraso': 0,
      'capital': '750.00',
      'interes': '120.00',
      'seguro': '5.00',
      'mora': '0.00',
      'total': '875.00',
    },
    {
      'id': 102,
      'fecha': '2026-03-15',
      'numero_recibo': 'REC-102',
      'numero_cuota': 2,
      'modalidad': 'MOVIL',
      'dias_atraso': 0,
      'capital': '760.00',
      'interes': '110.00',
      'seguro': '4.80',
      'mora': '0.00',
      'total': '874.80',
    },
  ],
  'totales': {
    'capital': '1510.00',
    'interes': '230.00',
    'seguro': '9.80',
    'mora': '0.00',
    'total': '1749.80',
    'pagos': 2,
  },
  'resumen': {
    'cuotas_total': 12,
    'cuotas_pagadas': 2,
    'cuotas_vencidas': 0,
    'cuotas_pendientes': 10,
    'seguro_programado': '55.00',
  },
  'cuotas': [
    {
      'numero': 1,
      'fecha_vencimiento': '2026-02-15',
      'capital': '750.00',
      'interes': '120.00',
      'seguro': '5.00',
      'monto_total': '875.00',
      'saldo_capital': '9250.00',
      'estado': 'PAGADA',
    },
    {
      'numero': 2,
      'fecha_vencimiento': '2026-03-15',
      'capital': '760.00',
      'interes': '110.00',
      'seguro': '4.80',
      'monto_total': '874.80',
      'saldo_capital': '8490.00',
      'estado': 'PAGADA',
    },
    {
      'numero': 3,
      'fecha_vencimiento': '2026-04-15',
      'capital': '770.00',
      'interes': '100.00',
      'seguro': '4.60',
      'monto_total': '874.60',
      'saldo_capital': '7720.00',
      'estado': 'PENDIENTE',
    },
  ],
};

class FakeExtractoSocioService extends SocioService {
  final ExtractoCredito fakeExtracto;

  FakeExtractoSocioService(this.fakeExtracto);

  @override
  Future<SocioResult<ExtractoCredito>> extractoCredito(
    int creditId, {
    String? desde,
    String? hasta,
    http.Client? client,
  }) async {
    return SocioResult.success(fakeExtracto);
  }
}

void main() {
  group('ExtractoCredito Model (S3, S4)', () {
    test('parses full extracto response correctly', () {
      final model = ExtractoCredito.fromJson(_sampleExtractoJson);
      expect(model.credito.numeroCredito, 'CR-2026-001');
      expect(model.credito.tipoCreditoLabel, 'Microcrédito');
      expect(model.credito.tipoAmortizacionLabel, 'Francés');
      expect(model.credito.montoDesembolsado, '10000.00');
      expect(model.credito.tasaSeguroDesgravamen, '0.05');

      expect(model.pagos.length, 2);
      expect(model.pagos.first.numeroRecibo, 'REC-101');
      expect(model.totales.total, '1749.80');
      expect(model.totales.pagos, 2);

      expect(model.resumen.cuotasPagadas, 2);
      expect(model.resumen.cuotasPendientes, 10);
      expect(model.resumen.seguroProgramado, '55.00');

      expect(model.cuotas.length, 3);
      expect(model.cuotas[2].estado, 'PENDIENTE');
    });

    test('tipo_credito labels translate properly', () {
      const credit1 = SocioCredit(
        id: 1,
        number: 'C1',
        product: 'P1',
        currency: 'BOB',
        disbursedAmount: '100',
        outstandingBalance: '50',
        status: 'VIGENTE',
        nextInstallment: null,
        creditType: 'CONSUMO',
        amortizationType: 'ALEMAN',
      );
      expect(credit1.creditTypeLabel, 'Consumo');
      expect(credit1.amortizationTypeLabel, 'Alemán');

      const credit2 = SocioCredit(
        id: 2,
        number: 'C2',
        product: 'P2',
        currency: 'BOB',
        disbursedAmount: '100',
        outstandingBalance: '50',
        status: 'VIGENTE',
        nextInstallment: null,
        creditType: 'VIVIENDA_HIPOTECARIA',
        amortizationType: 'FRANCES',
      );
      expect(credit2.creditTypeLabel, 'Vivienda hipotecaria');
      expect(credit2.amortizationTypeLabel, 'Francés');

      const creditNull = SocioCredit(
        id: 3,
        number: 'C3',
        product: 'P3',
        currency: 'BOB',
        disbursedAmount: '100',
        outstandingBalance: '50',
        status: 'VIGENTE',
        nextInstallment: null,
      );
      expect(creditNull.creditTypeLabel, 'Sin clasificar');
      expect(creditNull.amortizationTypeLabel, '-');
    });
  });

  group('ExtractoCredito Service', () {
    final prevToken = AuthService.tokenJWT;
    final prevDemo = DemoMode.enabled;
    tearDown(() {
      AuthService.tokenJWT = prevToken;
      DemoMode.enabled = prevDemo;
    });

    test('calls GET /socio/creditos/{id}/extracto with date filters', () async {
      AuthService.tokenJWT = 'test-token';
      DemoMode.enabled = false;
      Uri? calledUrl;

      final client = MockClient((request) async {
        calledUrl = request.url;
        return http.Response(jsonEncode(_sampleExtractoJson), 200);
      });

      final service = SocioService();
      final res = await service.extractoCredito(
        1,
        desde: '2026-01-01',
        hasta: '2026-06-30',
        client: client,
      );

      expect(res.success, isTrue);
      expect(calledUrl!.path, '/api/v1/socio/creditos/1/extracto');
      expect(calledUrl!.queryParameters['desde'], '2026-01-01');
      expect(calledUrl!.queryParameters['hasta'], '2026-06-30');
    });

    test('returns demo extracto when DemoMode is enabled', () async {
      DemoMode.enabled = true;
      final service = SocioService();
      final res = await service.extractoCredito(1);

      expect(res.success, isTrue);
      expect(res.value!.credito.id, 1);
      expect(res.value!.totales.pagos, 2);
    });
  });

  group('ExtractoCreditoScreen Widget', () {
    testWidgets('renders credit header, summary, payments and schedule',
        (tester) async {
      _setLargeSurface(tester);
      final extracto = ExtractoCredito.fromJson(_sampleExtractoJson);
      final fakeService = FakeExtractoSocioService(extracto);

      await tester.pumpWidget(
        _wrap(
          ExtractoCreditoScreen(
            creditId: 1,
            service: fakeService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Microcrédito Individual'), findsOneWidget);
      expect(find.text('CR-2026-001'), findsOneWidget);
      expect(find.text('Tipo: Microcrédito'), findsOneWidget);
      expect(find.text('Sistema: Francés'), findsOneWidget);
      expect(find.text('BOB 10000.00'), findsOneWidget);
      expect(find.text('BOB 8500.00'), findsOneWidget);
      expect(find.text('14.50%'), findsOneWidget);
      expect(find.text('0.05%'), findsOneWidget);

      // Resumen cuotas
      expect(find.text('RESUMEN DE CUOTAS Y SEGURO'), findsOneWidget);
      expect(find.text('Pagadas'), findsOneWidget);
      expect(find.text('Vencidas'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('BOB 55.00'), findsOneWidget);

      // Historial de pagos
      expect(find.text('HISTORIAL DE PAGOS'), findsOneWidget);
      expect(find.textContaining('REC-101'), findsOneWidget);
      expect(find.textContaining('REC-102'), findsOneWidget);
      expect(find.textContaining('BOB 1749.80'), findsOneWidget);

      // Plan de amortización
      expect(find.text('PLAN DE AMORTIZACIÓN'), findsOneWidget);
      expect(find.textContaining('Cuota #1'), findsWidgets);
      expect(find.textContaining('Cuota #2'), findsWidgets);
      expect(find.textContaining('Cuota #3'), findsWidgets);
    });
  });
}
