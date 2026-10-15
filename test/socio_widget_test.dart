import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/comprobante_model.dart';
import 'package:forest_microfinance/models/cuenta_ahorro_model.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/socio_screens.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';
import 'package:forest_microfinance/services/notification_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';

class _FakeSocioService extends SocioService {
  int payCreditCalls = 0;
  int? lastPaidCreditId;
  int? lastPaidAccountId;

  @override
  Future<SocioResult<List<SocioCredit>>> credits({http.Client? client}) async {
    return const SocioResult.success([
      SocioCredit(
        id: 1,
        number: 'CR-001',
        product: 'Crédito productivo',
        currency: 'BOB',
        disbursedAmount: '1000.00',
        outstandingBalance: '600.00',
        status: 'VIGENTE',
        nextInstallment: CreditInstallment(
            number: 2, dueDate: '2026-10-01', totalAmount: '120.00'),
      ),
    ]);
  }

  @override
  Future<SocioResult<CreditSchedule>> creditSchedule(int creditId,
      {http.Client? client}) async {
    return const SocioResult.success(CreditSchedule(
      credit: {
        'id': 1,
        'numero_credito': 'CR-001',
        'producto': 'Crédito productivo',
        'moneda': 'BOB',
        'saldo_pendiente': '600.00',
        'estado': 'VIGENTE',
      },
      installments: [
        CreditScheduleItem(
          number: 1,
          dueDate: '2026-09-01',
          capital: '100.00',
          interest: '20.00',
          insurance: '0.00',
          mora: '0.00',
          totalAmount: '120.00',
          capitalBalance: '500.00',
          status: 'PAGADA',
          paymentDate: '2026-09-01',
        ),
        CreditScheduleItem(
          number: 2,
          dueDate: '2026-10-01',
          capital: '100.00',
          interest: '20.00',
          insurance: '0.00',
          mora: '15.00',
          totalAmount: '135.00',
          capitalBalance: '400.00',
          status: 'VENCIDA',
          paymentDate: '',
        ),
        CreditScheduleItem(
          number: 3,
          dueDate: '2026-11-01',
          capital: '100.00',
          interest: '20.00',
          insurance: '0.00',
          mora: '0.00',
          totalAmount: '120.00',
          capitalBalance: '300.00',
          status: 'PENDIENTE',
          paymentDate: '',
        ),
      ],
    ));
  }

  @override
  Future<SocioResult<CreditPayment>> payCredit(
    int creditId,
    int savingsAccountId, {
    http.Client? client,
  }) async {
    payCreditCalls++;
    lastPaidCreditId = creditId;
    lastPaidAccountId = savingsAccountId;
    return SocioResult.success(CreditPayment(
      {'id': 10, 'monto': '135.00'},
      comprobante: Comprobante(
        id: 55,
        number: 'PAG-2026-000001',
        type: 'PAGO_CUOTA',
        channel: 'MOVIL',
        amount: '135.00',
        currency: 'BOB',
        sourceAccount: '****1234',
        destinationAccount: null,
        creditId: creditId,
        installmentNumber: 2,
        description: 'Pago de cuota #2 - Crédito CR-001',
        issuedAt: DateTime.now(),
        verificationCode: 'ABCDEF123456',
        verificationUrl: 'https://example.com/v/ABCDEF123456',
      ),
    ));
  }
}

class _FakeCuentasService extends CuentasService {
  final List<CuentaAhorro> testCuentas;
  _FakeCuentasService(this.testCuentas);

  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    return CuentasResult.success(testCuentas);
  }
}

class _FakeOffersService extends SocioService {
  int offersCalls = 0;
  int acceptedId = 0;
  int discardedId = 0;

  RecreditOffer get offer => const RecreditOffer(
        data: {},
        id: 9,
        amount: '5000.00',
        termMonths: 12,
      );

  @override
  Future<SocioResult<List<RecreditOffer>>> offers({http.Client? client}) async {
    offersCalls++;
    return SocioResult.success(offersCalls == 1 ? [offer] : []);
  }

  @override
  Future<SocioResult<Map<String, dynamic>>> acceptOffer(
    int offerId, {
    int? termMonths,
    http.Client? client,
  }) async {
    acceptedId = offerId;
    return const SocioResult.success({});
  }

  @override
  Future<SocioResult<Map<String, dynamic>>> discardOffer(
    int offerId, {
    http.Client? client,
  }) async {
    discardedId = offerId;
    return const SocioResult.success({});
  }
}

void main() {
  testWidgets('credits screen shows next installment and credit balance',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(home: CreditosScreen(service: _FakeSocioService())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CR-001'), findsOneWidget);
    expect(find.textContaining('600.00'), findsOneWidget);
    expect(find.textContaining('120.00'), findsOneWidget);
  });

  testWidgets('CronogramaCreditoScreen displays installments with PAGADA, VENCIDA and PENDIENTE statuses',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeSocioService();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: CronogramaCreditoScreen(
            creditId: 1,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cuota #1'), findsOneWidget);
    expect(find.text('PAGADA'), findsOneWidget);
    expect(find.text('Cuota #2'), findsOneWidget);
    expect(find.text('VENCIDA'), findsOneWidget);
    expect(find.text('Cuota #3'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('Capital amortizado:'), findsWidgets);
    expect(find.text('Interés cuota:'), findsWidgets);
    expect(find.text('Mora acumulada:'), findsOneWidget);
    expect(find.text('Pagar cuota'), findsNWidgets(2));
  });

  testWidgets('PagoCreditoScreen validates sufficient balance and executes payment',
      (tester) async {
    final socioService = _FakeSocioService();
    final cuentasService = _FakeCuentasService([
      const CuentaAhorro(
        id: 101,
        accountNumber: 'AH-101',
        productType: 'Caja de Ahorro',
        availableBalance: 200.00,
        blockedBalance: 0.00,
        status: 'ACTIVA',
        registrationDate: '2026-01-01',
        socioId: 1,
        currency: Moneda(id: 1, currencyCode: 'BOB', name: 'Bolivianos', symbol: 'Bs.'),
      ),
    ]);

    const credit = SocioCredit(
      id: 1,
      number: 'CR-001',
      product: 'Crédito productivo',
      currency: 'BOB',
      disbursedAmount: '1000.00',
      outstandingBalance: '600.00',
      status: 'VIGENTE',
      nextInstallment: CreditInstallment(
          number: 2, dueDate: '2026-10-01', totalAmount: '135.00'),
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
            service: socioService,
            accountsService: cuentasService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo disponible suficiente'), findsOneWidget);
    final confirmBtn = find.byKey(const Key('btn-confirmar-pago-cuota'));
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Confirmar Pago de Cuota'), findsNWidgets(2));
    await tester.tap(find.text('Sí, Pagar'));
    await tester.pumpAndSettle();

    expect(socioService.payCreditCalls, 1);
    expect(socioService.lastPaidAccountId, 101);
    expect(find.text('Comprobante'), findsOneWidget);
    expect(find.text('PAG-2026-000001'), findsOneWidget);
  });

  testWidgets('PagoCreditoScreen disables confirm when balance is insufficient',
      (tester) async {
    final socioService = _FakeSocioService();
    final cuentasService = _FakeCuentasService([
      const CuentaAhorro(
        id: 102,
        accountNumber: 'AH-102',
        productType: 'Caja de Ahorro',
        availableBalance: 50.00,
        blockedBalance: 0.00,
        status: 'ACTIVA',
        registrationDate: '2026-01-01',
        socioId: 1,
        currency: Moneda(id: 1, currencyCode: 'BOB', name: 'Bolivianos', symbol: 'Bs.'),
      ),
    ]);

    const credit = SocioCredit(
      id: 1,
      number: 'CR-001',
      product: 'Crédito productivo',
      currency: 'BOB',
      disbursedAmount: '1000.00',
      outstandingBalance: '600.00',
      status: 'VIGENTE',
      nextInstallment: CreditInstallment(
          number: 2, dueDate: '2026-10-01', totalAmount: '135.00'),
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
            service: socioService,
            accountsService: cuentasService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Saldo insuficiente'), findsOneWidget);
    final btn = tester.widget<ElevatedButton>(find.byKey(const Key('btn-confirmar-pago-cuota')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('accepting an offer requires confirmation and reloads offers',
      (tester) async {
    final service = _FakeOffersService();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(home: RecreditosScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar').last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar aceptación'), findsOneWidget);
    expect(service.acceptedId, 0);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(service.acceptedId, 9);
    expect(service.offersCalls, 2);
    expect(find.text('No tienes ofertas vigentes.'), findsOneWidget);
  });

  testWidgets('discarding an offer reloads the list after confirmation',
      (tester) async {
    final service = _FakeOffersService();
    await tester.pumpWidget(
      MaterialApp(home: RecreditosScreen(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();

    expect(service.discardedId, 9);
    expect(service.offersCalls, 2);
    expect(find.text('No tienes ofertas vigentes.'), findsOneWidget);
  });
}
