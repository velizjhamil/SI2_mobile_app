import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:forest_microfinance/models/comprobante_model.dart';
import 'package:forest_microfinance/screens/comprobante_screen.dart';

void main() {
  testWidgets('shows receipt details, verification code, QR and actions',
      (tester) async {
    const receipt = Comprobante(
      id: 85,
      number: 'TRF-2026-000001',
      type: 'TRANSFERENCIA',
      channel: 'MOVIL',
      amount: '150.00',
      currency: 'BOB',
      sourceAccount: '****c3-1',
      destinationAccount: '****c3-2',
      creditId: null,
      installmentNumber: null,
      description: 'Ahorro mensual',
      issuedAt: null,
      verificationCode: 'S083-BHSM-0876-2C2G',
      verificationUrl: 'https://example.test/verify/S083-BHSM-0876-2C2G',
    );

    await tester.pumpWidget(const MaterialApp(
      home: ComprobanteScreen(comprobante: receipt),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TRF-2026-000001'), findsOneWidget);
    expect(find.text('S083-BHSM-0876-2C2G'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('share-pdf')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('share-pdf')), findsOneWidget);
    expect(find.byKey(const Key('receipt-done')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
