import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/cuenta_ahorro_model.dart';
import 'package:forest_microfinance/screens/dashboard_screen.dart';
import 'package:forest_microfinance/screens/transferencia_screen.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';

const _fakePayload = [
  {
    'id': 7,
    'numero': 'AH-000123',
    'tipo_producto': 'Ahorro Programado',
    'saldo_disponible': 1250.50,
    'saldo_bloqueado': 100.00,
    'estado': 'ACTIVA',
    'fecha_registro': '2026-03-01',
    'socio_id': 42,
    'moneda': {
      'id': 1,
      'codigo_iso': 'BOB',
      'nombre': 'Boliviano',
      'simbolo': 'Bs',
    },
  },
  {
    'id': 8,
    'numero': 'AH-000124',
    'tipo_producto': 'Ahorro Libre',
    'saldo_disponible': 2500.75,
    'saldo_bloqueado': 0,
    'estado': 'ACTIVA',
    'fecha_registro': '2026-04-10',
    'socio_id': 42,
    'moneda': {
      'id': 1,
      'codigo_iso': 'BOB',
      'nombre': 'Boliviano',
      'simbolo': 'Bs',
    },
  },
];

/// Fake que cuenta las llamadas a listarMisCuentas (espía de refresh).
class CountingCuentasService extends CuentasService {
  int llamadas = 0;

  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    llamadas++;
    final cuentas = _fakePayload.map(CuentaAhorro.fromJson).toList();
    return CuentasResult.success(cuentas);
  }
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  group('Dashboard → TransferenciaScreen (7.3)', () {
    testWidgets('tap en tile Transferencias abre TransferenciaScreen',
        (WidgetTester tester) async {
      final service = CountingCuentasService();
      await tester.pumpWidget(
        _wrap(DashboardScreen(cuentasService: service)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Transferencias'));
      await tester.pumpAndSettle();

      expect(find.byType(TransferenciaScreen), findsOneWidget);
    });

    testWidgets('volver con true dispara el refresh de saldos',
        (WidgetTester tester) async {
      final service = CountingCuentasService();
      await tester.pumpWidget(
        _wrap(DashboardScreen(cuentasService: service)),
      );
      await tester.pumpAndSettle();
      expect(service.llamadas, 1);

      await tester.tap(find.text('Transferencias'));
      await tester.pumpAndSettle();
      expect(find.byType(TransferenciaScreen), findsOneWidget);

      // La pantalla real usa services de producción sin token: muestra
      // error, pero la ruta existe. Popeamos con true como haría un éxito.
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pop(true);
      await tester.pumpAndSettle();

      expect(find.byType(TransferenciaScreen), findsNothing);
      expect(service.llamadas, 2);
    });
  });
}
