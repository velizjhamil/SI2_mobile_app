import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/socio_model.dart';
import 'package:forest_microfinance/screens/dashboard_screen.dart';
import 'package:forest_microfinance/services/cuentas_service.dart';
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

const _sampleDashboardSocioJson = {
  'socio': {'id': 7, 'nombre': 'María Condori'},
  'ahorros': {'cuentas': 2, 'saldo_total': '4500.50'},
  'creditos': [
    {
      'id': 10,
      'numero_credito': 'CR-2026-099',
      'producto': 'Microcrédito Productivo',
      'moneda': 'BOB',
      'monto_desembolsado': '15000.00',
      'saldo_pendiente': '12400.00',
      'estado': 'VIGENTE',
      'tipo_credito': 'MICROCREDITO',
      'tipo_amortizacion': 'FRANCES',
      'proxima_cuota': {
        'numero': 4,
        'fecha_vencimiento': '2026-12-15',
        'monto_total': '890.00',
      },
    },
  ],
  'pagado': {
    'capital': '2600.00',
    'interes': '480.00',
    'seguro': '30.00',
    'mora': '0.00',
    'total': '3110.00',
  },
  'dpf': {'certificados': 1, 'capital': '10000.00'},
  'notificaciones_sin_leer': 3,
  'calificaciones_enviadas': 1,
};

class FakeDashboardCuentasService extends CuentasService {
  @override
  Future<CuentasResult> listarMisCuentas({http.Client? client}) async {
    return const CuentasResult.success([]);
  }
}

class FakeDashboardSocioService extends SocioService {
  final SocioDashboard dashboard;

  FakeDashboardSocioService(this.dashboard);

  @override
  Future<SocioResult<SocioDashboard>> dashboardSocio({http.Client? client}) async {
    return SocioResult.success(dashboard);
  }
}

void main() {
  group('SocioDashboard Model (T7, S1)', () {
    test('parses socio dashboard JSON correctly', () {
      final model = SocioDashboard.fromJson(_sampleDashboardSocioJson);

      expect(model.socioNombre, 'María Condori');
      expect(model.ahorros.cuentas, 2);
      expect(model.ahorros.saldoTotal, '4500.50');

      expect(model.creditos.length, 1);
      final cr = model.creditos.first;
      expect(cr.product, 'Microcrédito Productivo');
      expect(cr.creditTypeLabel, 'Microcrédito');
      expect(cr.amortizationTypeLabel, 'Francés');
      expect(cr.outstandingBalance, '12400.00');
      expect(cr.nextInstallment?.number, 4);

      expect(model.pagado.total, '3110.00');
      expect(model.pagado.capital, '2600.00');
      expect(model.pagado.interes, '480.00');
      expect(model.pagado.seguro, '30.00');

      expect(model.dpf.certificados, 1);
      expect(model.dpf.capital, '10000.00');
      expect(model.notificacionesSinLeer, 3);
      expect(model.calificacionesEnviadas, 1);
    });
  });

  group('SocioDashboard Service', () {
    final prevToken = AuthService.tokenJWT;
    final prevDemo = DemoMode.enabled;
    tearDown(() {
      AuthService.tokenJWT = prevToken;
      DemoMode.enabled = prevDemo;
    });

    test('calls GET /dashboard/socio with auth header', () async {
      AuthService.tokenJWT = 'test-jwt';
      DemoMode.enabled = false;
      Uri? calledUrl;
      String? authHeader;

      final client = MockClient((request) async {
        calledUrl = request.url;
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode(_sampleDashboardSocioJson), 200);
      });

      final service = SocioService();
      final res = await service.dashboardSocio(client: client);

      expect(res.success, isTrue);
      expect(calledUrl!.path, '/api/v1/dashboard/socio');
      expect(authHeader, 'Bearer test-jwt');
      expect(res.value!.ahorros.saldoTotal, '4500.50');
    });

    test('returns demo dashboard when DemoMode is enabled', () async {
      DemoMode.enabled = true;
      final service = SocioService();
      final res = await service.dashboardSocio();

      expect(res.success, isTrue);
      expect(res.value!.socioNombre, 'María Condori Mamani');
      expect(res.value!.ahorros.cuentas, 2);
    });
  });

  group('DashboardScreen Socio Widgets', () {
    testWidgets('renders socio dashboard sections and shortcut to calificar',
        (tester) async {
      final dashboard = SocioDashboard.fromJson(_sampleDashboardSocioJson);
      final fakeSocio = FakeDashboardSocioService(dashboard);
      final fakeCuentas = FakeDashboardCuentasService();

      await tester.pumpWidget(
        _wrap(
          DashboardScreen(
            cuentasService: fakeCuentas,
            socioService: fakeSocio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Calificar servicio shortcut
      expect(find.text('Calificar servicio'), findsWidgets);
      expect(find.text('Calificar'), findsOneWidget);

      // Notificaciones sin leer
      expect(find.textContaining('3 notificaciones pendientes'), findsOneWidget);

      // Resumen de productos
      expect(find.text('RESUMEN DE PRODUCTOS'), findsOneWidget);
      expect(find.text('Bs. 4500.50'), findsOneWidget);
      expect(find.text('Bs. 10000.00'), findsOneWidget);

      // Total pagado
      expect(find.text('TOTAL PAGADO'), findsOneWidget);
      expect(find.text('Bs. 3110.00'), findsOneWidget);
      expect(find.text('Bs. 2600.00'), findsOneWidget);
      expect(find.text('Bs. 480.00'), findsOneWidget);
      expect(find.text('Bs. 30.00'), findsOneWidget);

      // Tus créditos
      expect(find.text('TUS CRÉDITOS'), findsOneWidget);
      expect(find.text('Microcrédito Productivo'), findsOneWidget);
      expect(find.text('Tipo: Microcrédito'), findsOneWidget);
      expect(find.text('Sistema: Francés'), findsOneWidget);
      expect(find.text('BOB 12400.00'), findsOneWidget);
      expect(find.textContaining('Próxima cuota #4'), findsOneWidget);
      expect(find.text('Extracto >'), findsOneWidget);
    });
  });
}
