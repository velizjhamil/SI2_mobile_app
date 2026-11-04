import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/plan_bloqueado_screen.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/plan_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';

class _FakeLogoutAuthService extends AuthService {
  bool logoutCalled = false;
  _FakeLogoutAuthService() : super(tokenStore: InMemorySecureTokenStore());

  @override
  Future<bool> logout({http.Client? client}) async {
    logoutCalled = true;
    return true;
  }
}

Widget _wrap(Widget child, {bool isDark = false}) {
  return ChangeNotifierProvider(
    create: (_) {
      final provider = ThemeProvider();
      if (isDark && !provider.isDark) {
        provider.toggleTheme();
      }
      return provider;
    },
    child: MaterialApp(
      routes: {
        '/login': (_) => const Scaffold(body: Text('Login Screen Mock')),
      },
      home: child,
    ),
  );
}

void main() {
  testWidgets('muestra aviso exacto con el nombre del plan en S5',
      (WidgetTester tester) async {
    PlanService.currentInfo = const PlanModulosInfo(
      plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
      modulos: [],
    );

    await tester.pumpWidget(_wrap(const PlanBloqueadoScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Tu plan Básico no incluye banca móvil y comprobantes digitales.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('plan_bloqueado_mensaje')), findsOneWidget);
    expect(find.byKey(const Key('plan_bloqueado_logout_btn')), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('muestra aviso con planNombre explícito en constructor',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(const PlanBloqueadoScreen(planNombre: 'Comunitario')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Tu plan Comunitario no incluye banca móvil y comprobantes digitales.'),
      findsOneWidget,
    );
  });

  testWidgets('botón cerrar sesión invoca logout y redirige a /login',
      (WidgetTester tester) async {
    final fakeAuth = _FakeLogoutAuthService();
    PlanService.currentInfo = const PlanModulosInfo(
      plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
    );

    await tester.pumpWidget(
      _wrap(PlanBloqueadoScreen(authService: fakeAuth)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plan_bloqueado_logout_btn')));
    await tester.pumpAndSettle();

    expect(fakeAuth.logoutCalled, isTrue);
    expect(find.text('Login Screen Mock'), findsOneWidget);
    expect(PlanService.currentInfo, isNull);
  });

  testWidgets('renderiza correctamente en modo oscuro',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(const PlanBloqueadoScreen(planNombre: 'Básico'), isDark: true),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlanBloqueadoScreen), findsOneWidget);
    expect(
      find.text(
          'Tu plan Básico no incluye banca móvil y comprobantes digitales.'),
      findsOneWidget,
    );
  });
}
