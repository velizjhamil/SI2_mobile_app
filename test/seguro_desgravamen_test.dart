import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/comprobante_model.dart';
import 'package:forest_microfinance/models/cuenta_ahorro_model.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/comprobante_screen.dart';
import 'package:forest_microfinance/screens/socio_screens.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';
import 'package:forest_microfinance/services/demo_mode.dart';
import 'package:forest_microfinance/services/notification_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';
import 'package:provider/provider.dart';

class _FakeDemoSocioService extends SocioService {
  @override
  Future<SocioResult<CreditSchedule>> creditSchedule(int creditId, {dynamic client}) async {
    return const SocioResult.success(CreditSchedule(
      credit: {
        'id': 1,
        'numero_credito': 'CRE-001',
        'producto': 'Consumo',
        'moneda': 'BOB',
        'saldo_pendiente': '800.00',
        'estado': 'VIGENTE',
      },
      totalInsurance: '24.50',
      installments: [
        CreditScheduleItem(
          number: 1,
          dueDate: '2026-11-01',
          capital: '200.00',
          interest: '30.00',
          insurance: '5.50',
          mora: '0.00',
          totalAmount: '235.50',
          capitalBalance: '800.00',
          status: 'PENDIENTE',
          paymentDate: '',
        ),
      ],
    ));
  }
}

class _FakeCuentasService extends CuentasService {
  @override
  Future<CuentasResult> listarMisCuentas({dynamic client}) async {
    return const CuentasResult.success([
      CuentaAhorro(
        id: 1,
        accountNumber: 'AH-001',
        productType: 'Caja Ahorro',
        availableBalance: 1000.0,
        blockedBalance: 0.0,
        status: 'ACTIVA',
        registrationDate: '2026-01-01',
        socioId: 1,
        currency: Moneda(id: 1, currencyCode: 'BOB', name: 'Bolivianos', symbol: 'Bs.'),
      ),
    ]);
  }
}

void main() {
  group('S7 Models Parsing - Seguro Desgravamen', () {
    test('CreditSchedule parses total_seguro and CreditScheduleItem parses seguro', () {
      final json = {
        'credito': {
          'id': 10,
          'numero_credito': 'CRE-10',
          'moneda': 'BOB',
          'estado': 'VIGENTE',
          'saldo_pendiente': '1200.00',
        },
        'total_seguro': '18.75',
        'cuotas': [
          {
            'numero': 1,
            'fecha_vencimiento': '2026-12-15',
            'capital': '300.00',
            'interes': '45.00',
            'seguro': '6.25',
            'mora': '0.00',
            'monto_total': '351.25',
            'saldo_capital': '900.00',
            'estado': 'PENDIENTE',
            'fecha_pago': '',
          },
        ],
      };

      final schedule = CreditSchedule.fromJson(json);
      expect(schedule.totalInsurance, '18.75');
      expect(schedule.installments.length, 1);
      final item = schedule.installments.first;
      expect(item.insurance, '6.25');
      expect(item.totalAmount, '351.25');
    });

    test('ProductoCreditoSocio parses tasa_seguro_desgravamen', () {
      final json = {
        'id': 5,
        'codigo': 'PROD-01',
        'nombre': 'Microcrédito',
        'moneda': 'BOB',
        'monto_min': '1000.00',
        'monto_max': '20000.00',
        'plazo_min_meses': 6,
        'plazo_max_meses': 24,
        'tasa_interes_anual': '16.00',
        'tasa_seguro_desgravamen': '0.08',
        'tipo_amortizacion': 'FRANCES',
        'requiere_garantia': false,
      };

      final product = ProductoCreditoSocio.fromJson(json);
      expect(product.tasaSeguroDesgravamen, '0.08');
    });

    test('SimulacionCredito and SimulacionCuota parse total_seguro and seguro', () {
      final json = {
        'cuota_estimada': '351.25',
        'total_intereses': '135.00',
        'total_seguro': '18.75',
        'total_a_pagar': '1353.75',
        'cronograma': [
          {
            'numero': 1,
            'capital': '300.00',
            'interes': '45.00',
            'seguro': '6.25',
            'cuota': '351.25',
            'saldo': '900.00',
          },
        ],
      };

      final sim = SimulacionCredito.fromJson(json);
      expect(sim.totalSeguro, '18.75');
      expect(sim.cronograma.first.seguro, '6.25');
    });

    test('Comprobante parses capital, interest, and seguro', () {
      final json = {
        'id': 100,
        'numero': 'REC-001',
        'tipo': 'PAGO_CUOTA',
        'canal': 'MOVIL',
        'monto': '351.25',
        'moneda': 'BOB',
        'cuenta_origen': '****001',
        'cuenta_destino': null,
        'credito_id': 10,
        'numero_cuota': 1,
        'glosa': 'Pago cuota 1',
        'capital': '300.00',
        'interes': '45.00',
        'seguro': '6.25',
        'emitido_en': '2026-11-13T10:00:00',
        'codigo_verificacion': 'VERIF-1234',
        'url_verificacion': 'http://localhost:8000/v/VERIF-1234',
      };

      final comp = Comprobante.fromJson(json);
      expect(comp.capital, '300.00');
      expect(comp.interest, '45.00');
      expect(comp.insurance, '6.25');
    });
  });

  group('DemoMode seguro calculations', () {
    test('creditSchedule in demo mode generates real seguro and totalInsurance', () async {
      final schedule = await DemoMode.socio.creditSchedule(1);
      expect(schedule, isNotNull);
      expect(double.parse(schedule!.totalInsurance), greaterThan(0));
      expect(double.parse(schedule.installments.first.insurance), greaterThan(0));
    });

    test('simulateCredit in demo mode includes seguro per installment and totalSeguro', () async {
      final sim = await DemoMode.socio.simulateCredit(
        productId: 1,
        amount: '10000.00',
        termMonths: 12,
      );
      expect(sim, isNotNull);
      expect(double.parse(sim!.totalSeguro), greaterThan(0));
      expect(double.parse(sim.cronograma.first.seguro), greaterThan(0));
    });
  });

  group('UI Screens Seguro Desgravamen Display', () {
    testWidgets('CronogramaCreditoScreen displays TOTAL SEGURO and Seguro desgravamen row', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: CronogramaCreditoScreen(
              creditId: 1,
              service: _FakeDemoSocioService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL SEGURO'), findsOneWidget);
      expect(find.textContaining('24.50'), findsWidgets);
      expect(find.text('Seguro desgravamen:'), findsOneWidget);
      expect(find.textContaining('5.50'), findsWidgets);
    });

    testWidgets('PagoCreditoScreen shows Seguro line in quota breakdown', (tester) async {
      const cuota = CreditScheduleItem(
        number: 1,
        dueDate: '2026-11-01',
        capital: '200.00',
        interest: '30.00',
        insurance: '5.50',
        mora: '0.00',
        totalAmount: '235.50',
        capitalBalance: '800.00',
        status: 'PENDIENTE',
        paymentDate: '',
      );

      const credit = SocioCredit(
        id: 1,
        number: 'CRE-001',
        product: 'Consumo',
        currency: 'BOB',
        disbursedAmount: '1000.00',
        outstandingBalance: '800.00',
        status: 'VIGENTE',
        nextInstallment: CreditInstallment(number: 1, dueDate: '2026-11-01', totalAmount: '235.50'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ],
          child: MaterialApp(
            home: PagoCreditoScreen(
              credit: credit,
              cuota: cuota,
              service: _FakeDemoSocioService(),
              accountsService: _FakeCuentasService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Capital:'), findsOneWidget);
      expect(find.text('Interés:'), findsOneWidget);
      expect(find.text('Seguro:'), findsOneWidget);
      expect(find.text('BOB 5.50'), findsOneWidget);
    });

    testWidgets('ComprobanteScreen displays Seguro line when insurance is present', (tester) async {
      const receipt = Comprobante(
        id: 88,
        number: 'PAG-2026-000088',
        type: 'PAGO_CUOTA',
        channel: 'MOVIL',
        amount: '235.50',
        currency: 'BOB',
        sourceAccount: '****001',
        destinationAccount: null,
        creditId: 1,
        installmentNumber: 1,
        description: 'Pago de cuota',
        capital: '200.00',
        interest: '30.00',
        insurance: '5.50',
        issuedAt: null,
        verificationCode: 'CODE-1234',
        verificationUrl: 'http://localhost/v/CODE-1234',
      );

      await tester.pumpWidget(
        const MaterialApp(home: ComprobanteScreen(comprobante: receipt)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Capital'), findsOneWidget);
      expect(find.text('200.00 BOB'), findsOneWidget);
      expect(find.text('Interés'), findsOneWidget);
      expect(find.text('30.00 BOB'), findsOneWidget);
      expect(find.text('Seguro'), findsOneWidget);
      expect(find.text('5.50 BOB'), findsOneWidget);
    });
  });
}
