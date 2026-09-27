import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/socio_screens.dart';
import 'package:forest_microfinance/services/socio_service.dart';

class _FakeSocioService extends SocioService {
  @override
  Future<SocioResult<List<SocioCredit>>> credits({http.Client? client}) async {
    return SocioResult.success([
      const SocioCredit(
        id: 1,
        number: 'CR-001',
        product: 'Crédito productivo',
        currency: 'BOB',
        disbursedAmount: '1000.00',
        outstandingBalance: '600.00',
        status: 'VIGENTE',
        nextInstallment: const CreditInstallment(
            number: 2, dueDate: '2026-10-01', totalAmount: '120.00'),
      ),
    ]);
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
