import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/campo_model.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/screens/dashboard_screen.dart';
import 'package:forest_microfinance/screens/main_navigation_screen.dart';
import 'package:forest_microfinance/services/campo_service.dart';
import 'package:forest_microfinance/services/notification_service.dart';
import 'package:forest_microfinance/services/plan_service.dart';

class _FakeCampoService extends CampoService {
  @override
  Future<CampoResult<List<SolicitudResumenCampo>>> getWorklist({
    bool requiereEvaluacion = true,
    String? canalOrigen,
    http.Client? client,
  }) async {
    return const CampoResult.success([]);
  }
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void _ignorarAvisoListTileConFondo() {
  final originalOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = originalOnError);
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('ink splashes may be invisible')) return;
    originalOnError?.call(details);
  };
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  tearDown(() {
    PlanService.reset();
  });

  group(
      'S6: CampoHomeScreen oculta botones de Precalificar sin scoring_crediticio',
      () {
    testWidgets(
        'oculta botón en app bar y FAB cuando scoring_crediticio no está en el plan',
        (WidgetTester tester) async {
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['reportes_gerenciales'],
      );

      final fakeService = _FakeCampoService();
      await tester.pumpWidget(_wrap(CampoHomeScreen(service: fakeService)));
      await tester.pumpAndSettle();

      // Botones de precalificar deben estar ocultos
      expect(
          find.byKey(const Key('campo_precalificar_nav_btn')), findsNothing);
      expect(find.byKey(const Key('campo_precalificar_fab')), findsNothing);

      // El resto de la pantalla de campo queda intacta (sincronizar, logout, título)
      expect(find.byKey(const Key('campo_sync_btn')), findsOneWidget);
      expect(find.byKey(const Key('campo_logout_btn')), findsOneWidget);
      expect(find.text('Módulo de Campo'), findsOneWidget);
    });

    testWidgets(
        'muestra botones de precalificar cuando scoring_crediticio está en el plan',
        (WidgetTester tester) async {
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'CRECIMIENTO_PRO', nombre: 'Crecimiento Pro'),
        modulos: ['scoring_crediticio'],
      );

      final fakeService = _FakeCampoService();
      await tester.pumpWidget(_wrap(CampoHomeScreen(service: fakeService)));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('campo_precalificar_nav_btn')), findsOneWidget);
      expect(find.byKey(const Key('campo_precalificar_fab')), findsOneWidget);
    });
  });

  group('S6: Chatbot y Notificaciones según plan', () {
    testWidgets(
        'MainNavigationScreen oculta FAB del Chatbot si chatbot_ia no está en el plan',
        (WidgetTester tester) async {
      _ignorarAvisoListTileConFondo();
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['banca_movil'],
      );

      await tester.pumpWidget(_wrap(const MainNavigationScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    });

    testWidgets(
        'MainNavigationScreen muestra FAB del Chatbot si chatbot_ia está en el plan',
        (WidgetTester tester) async {
      _ignorarAvisoListTileConFondo();
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'CRECIMIENTO_PRO', nombre: 'Crecimiento Pro'),
        modulos: ['banca_movil', 'chatbot_ia'],
      );

      await tester.pumpWidget(_wrap(const MainNavigationScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets(
        'DashboardScreen oculta campana de notificaciones si notificaciones_socios no está en el plan',
        (WidgetTester tester) async {
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
        modulos: ['banca_movil'],
      );

      await tester.pumpWidget(_wrap(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_none), findsNothing);
    });

    testWidgets(
        'DashboardScreen muestra campana de notificaciones si notificaciones_socios está en el plan',
        (WidgetTester tester) async {
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'CRECIMIENTO_PRO', nombre: 'Crecimiento Pro'),
        modulos: ['banca_movil', 'notificaciones_socios'],
      );

      await tester.pumpWidget(_wrap(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets(
        'logout en CampoHomeScreen limpia PlanService y detiene monitor (Defecto 4 y 5)',
        (WidgetTester tester) async {
      _setLargeSurface(tester);
      PlanService.currentInfo = const PlanModulosInfo(
        plan: PlanInfo(codigo: 'CRECIMIENTO_PRO', nombre: 'Crecimiento Pro'),
        modulos: ['scoring_crediticio'],
      );
      final provider = NotificationProvider();
      provider.startMonitoring();
      expect(provider.isMonitoring, isTrue);

      final fakeService = _FakeCampoService();
      await tester.pumpWidget(_wrap(CampoHomeScreen(service: fakeService)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('campo_logout_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dialog_confirm_logout_btn')));
      await tester.pumpAndSettle();

      expect(PlanService.currentInfo, isNull);
      expect(provider.isMonitoring, isFalse);
    });
  });
}
