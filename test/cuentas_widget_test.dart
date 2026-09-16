import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/cuenta_ahorro_model.dart';
import 'package:forest_microfinance/screens/dashboard_screen.dart';
import 'package:forest_microfinance/screens/portfolio_screen.dart';
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

const _fakePayloadMultiMoneda = [
  {
    'id': 7,
    'numero': 'AH-000123',
    'tipo_producto': 'Ahorro Programado',
    'saldo_disponible': 100.00,
    'saldo_bloqueado': 0,
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
    'id': 9,
    'numero': 'AH-000200',
    'tipo_producto': 'Ahorro Libre',
    'saldo_disponible': 50.00,
    'saldo_bloqueado': 0,
    'estado': 'ACTIVA',
    'fecha_registro': '2026-05-01',
    'socio_id': 42,
    'moneda': {
      'id': 2,
      'codigo_iso': 'USD',
      'nombre': 'Dólar estadounidense',
      'simbolo': r'$',
    },
  },
];

/// Fake que inyecta datos reales sin red.
class FakeCuentasService extends CuentasService {
  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    final cuentas =
        _fakePayload.map(CuentaAhorro.fromJson).toList();
    return CuentasResult.success(cuentas);
  }
}

/// Fake con cuentas en dos monedas distintas (BOB + USD).
class FakeCuentasServiceMultiMoneda extends CuentasService {
  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    final cuentas =
        _fakePayloadMultiMoneda.map(CuentaAhorro.fromJson).toList();
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
  group('Consulta de Saldos con datos reales', () {
    testWidgets('Dashboard muestra saldos reales y no hardcodeados',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(DashboardScreen(cuentasService: FakeCuentasService())),
      );
      await tester.pumpAndSettle();

      // Saldos reales del fake.
      expect(find.textContaining('AH-000123'), findsWidgets);
      expect(find.textContaining('Ahorro Programado'), findsWidgets);
      expect(find.textContaining('Bs 1250.50'), findsWidgets);
      expect(find.textContaining('Bs 2500.75'), findsWidgets);

      // Los strings viejos hardcodeados deben haber desaparecido.
      expect(find.textContaining('Renta Fija Institucional'), findsNothing);
      expect(find.text('+\$3,420.00 USD'), findsNothing);
      expect(find.text('+\$3,420.00'), findsNothing);
    });

    testWidgets('Portfolio muestra saldos reales y no hardcodeados',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(PortfolioScreen(cuentasService: FakeCuentasService())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('AH-000123'), findsWidgets);
      expect(find.textContaining('Ahorro Libre'), findsWidgets);
      expect(find.textContaining('Bs 1250.50'), findsWidgets);

      expect(find.textContaining('Renta Fija Institucional'), findsNothing);
      expect(find.textContaining('Acciones Tech'), findsNothing);
      expect(find.textContaining('Bonos del Tesoro'), findsNothing);
    });

    testWidgets(
        'Dashboard con cuentas en dos monedas desglosa el total, '
        'no lo suma bajo un solo símbolo', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          DashboardScreen(cuentasService: FakeCuentasServiceMultiMoneda()),
        ),
      );
      await tester.pumpAndSettle();

      // Nunca debe mostrar 150.00 (100 BOB + 50 USD sumados como si fueran
      // la misma moneda) bajo un solo símbolo.
      expect(find.textContaining('150.00'), findsNothing);
      // Cada moneda aparece con su propio símbolo y monto.
      expect(find.textContaining('Bs 100.00'), findsWidgets);
      expect(find.textContaining(r'$ 50.00'), findsWidgets);
    });

    testWidgets(
        'Portfolio con cuentas en dos monedas desglosa el total, '
        'no lo suma bajo un solo símbolo', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          PortfolioScreen(cuentasService: FakeCuentasServiceMultiMoneda()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('150.00'), findsNothing);
      expect(find.textContaining('Bs 100.00'), findsWidgets);
      expect(find.textContaining(r'$ 50.00'), findsWidgets);
    });
  });
}
