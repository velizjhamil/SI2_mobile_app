import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/socio_screens.dart';
import 'package:forest_microfinance/services/socio_service.dart';
import 'package:http/http.dart' as http;

class _MockRecreditosService extends SocioService {
  final List<RecreditOffer> _offers;
  _MockRecreditosService(this._offers);

  @override
  Future<SocioResult<List<RecreditOffer>>> offers({http.Client? client}) async {
    return SocioResult.success(_offers);
  }
}

void main() {
  group('RecreditOffer CU-M13 Model & Parsing Tests', () {
    test('parses backend-shaped JSON correctly into RecreditOffer', () {
      final json = {
        'id': 42,
        'producto': {
          'id': 1,
          'codigo': 'PEQ',
          'nombre': 'Crédito Emprendedor',
        },
        'moneda': 'BOB',
        'monto_sugerido': '15000.00',
        'plazo_meses': 18,
        'tasa_interes': '12.50',
        'cuota_estimada': '918.25',
        'fecha_vencimiento': '2026-12-31',
        'fecha_generacion': '2026-11-01',
        'estado': 'VIGENTE',
        'nivel_riesgo': 'BAJO',
        'motivos': ['Buen historial de pago'],
      };

      final offer = RecreditOffer.fromJson(json);

      expect(offer.id, 42);
      expect(offer.amount, '15000.00');
      expect(offer.termMonths, 18);
      expect(offer.productName, 'Crédito Emprendedor');
      expect(offer.currency, 'BOB');
      expect(offer.interestRate, '12.50');
      expect(offer.estimatedInstallment, '918.25');
      expect(offer.validUntil, DateTime(2026, 12, 31));
      expect(offer.formattedValidUntil, '31/12/2026');
    });

    test('falls back to monto when monto_sugerido is null', () {
      final json = {
        'id': 10,
        'monto': '8000.00',
        'plazo_meses': 12,
        'producto': 'Crédito Personal',
      };

      final offer = RecreditOffer.fromJson(json);

      expect(offer.amount, '8000.00');
      expect(offer.productName, 'Crédito Personal');
      expect(offer.termMonths, 12);
      expect(offer.validUntil, isNull);
      expect(offer.formattedValidUntil, '');
    });
  });

  group('RecreditosScreen CU-M13 Widget Tests', () {
    testWidgets('displays all required offer fields on the card', (tester) async {
      final offer = RecreditOffer.fromJson({
        'id': 7,
        'producto': {
          'id': 2,
          'codigo': 'AGR',
          'nombre': 'Crédito Agrícola',
        },
        'moneda': 'BOB',
        'monto_sugerido': '20000.00',
        'plazo_meses': 24,
        'tasa_interes': '11.80',
        'cuota_estimada': '940.30',
        'fecha_vencimiento': '2026-11-30',
      });

      final service = _MockRecreditosService([offer]);

      await tester.pumpWidget(
        MaterialApp(
          home: RecreditosScreen(service: service),
        ),
      );
      await tester.pumpAndSettle();

      // Verify product name and offer id
      expect(find.text('Crédito Agrícola'), findsOneWidget);
      expect(find.text('Oferta 7'), findsOneWidget);

      // Verify amount with currency
      expect(find.textContaining('20000.00'), findsOneWidget);
      expect(find.textContaining('BOB'), findsWidgets);

      // Verify term in months
      expect(find.text('24 meses'), findsOneWidget);

      // Verify annual interest rate
      expect(find.text('Tasa: 11.80% anual'), findsOneWidget);

      // Verify estimated installment
      expect(find.textContaining('Cuota estimada: 940.30'), findsOneWidget);

      // Verify validity date
      expect(find.text('Vigente hasta 30/11/2026'), findsOneWidget);

      // Verify actions menu still works
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });
  });
}
