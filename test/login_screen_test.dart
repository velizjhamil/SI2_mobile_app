import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/campo_screens.dart';
import 'package:forest_microfinance/screens/login_screen.dart';
import 'package:forest_microfinance/screens/main_navigation_screen.dart';
import 'package:forest_microfinance/screens/plan_bloqueado_screen.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/plan_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

class FakeRoleAuthService extends AuthService {
  final String role;
  final bool bioAvailable;
  FakeRoleAuthService(this.role,
      {this.bioAvailable = false, super.tokenStore, super.biometric});

  @override
  Future<AuthResult> login(String email, String password,
      {http.Client? client}) async {
    AuthService.tokenJWT = 'jwt-fake-$role';
    AuthService.currentRole = role;
    return AuthResult.success(token: 'jwt-fake-$role', role: role);
  }

  @override
  Future<bool> isBiometricAvailable() async => bioAvailable;

  @override
  Future<AuthResult> authenticateWithBiometrics({http.Client? client}) async {
    AuthService.tokenJWT = 'jwt-fake-$role';
    AuthService.currentRole = role;
    return AuthResult.success(token: 'jwt-fake-$role', role: role);
  }
}

class FakePlanService extends PlanService {
  final PlanModulosInfo info;
  FakePlanService(this.info);

  @override
  Future<PlanModulosInfo> fetchMisModulos({http.Client? client}) async {
    PlanService.currentInfo = info;
    return info;
  }
}

void _ignorarAvisoListTileConFondo() {
  final originalOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = originalOnError);
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('ink splashes may be invisible')) return;
    originalOnError?.call(details);
  };
}

void main() {
  tearDown(() {
    PlanService.reset();
  });
  testWidgets(
      'Formulario vacío muestra errores de validación y no navega (sin red)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    // Vaciar los campos (vienen pre-llenados por defecto).
    await tester.enterText(find.byKey(const Key('emailField')), '');
    await tester.enterText(find.byKey(const Key('passwordField')), '');
    await tester.pump();

    // La validación falla de forma sincrónica dentro de _handleLogin,
    // ANTES de cualquier llamada a AuthService.login: no hay red.
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pump();

    expect(find.text('Correo no válido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    // No navegó a la pantalla principal.
    expect(find.byType(MainNavigationScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('biometric button is hidden without an enabled stored token',
      (WidgetTester tester) async {
    final service = AuthService(
      tokenStore: InMemorySecureTokenStore(),
      biometric: FakeBiometricAuthenticator(true),
    );
    await tester.pumpWidget(_wrap(LoginScreen(authService: service)));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar con Biometría'), findsNothing);
  });

  testWidgets(
      'login con OFICIAL_CREDITO navega a CampoHomeScreen (/campo)',
      (WidgetTester tester) async {
    final service = FakeRoleAuthService(
      'OFICIAL_CREDITO',
      tokenStore: InMemorySecureTokenStore(),
      biometric: FakeBiometricAuthenticator(false),
    );
    await tester.pumpWidget(_wrap(LoginScreen(authService: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(CampoHomeScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
  });

  testWidgets(
      'login con SOCIO navega a MainNavigationScreen (/dashboard)',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();
    final service = FakeRoleAuthService(
      'SOCIO',
      tokenStore: InMemorySecureTokenStore(),
      biometric: FakeBiometricAuthenticator(false),
    );
    await tester.pumpWidget(_wrap(LoginScreen(authService: service)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(CampoHomeScreen), findsNothing);
  });

  testWidgets(
      'login con SOCIO sin banca_movil navega a PlanBloqueadoScreen (S5)',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();
    final authService = FakeRoleAuthService(
      'SOCIO',
      tokenStore: InMemorySecureTokenStore(),
      biometric: FakeBiometricAuthenticator(false),
    );
    final planService = FakePlanService(const PlanModulosInfo(
      plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
      modulos: ['reportes_gerenciales'],
      sinRestriccion: false,
    ));

    await tester.pumpWidget(_wrap(LoginScreen(
      authService: authService,
      planService: planService,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanBloqueadoScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
    expect(
      find.text(
          'Tu plan Básico no incluye banca móvil y comprobantes digitales.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'ingreso biométrico con SOCIO sin banca_movil navega a PlanBloqueadoScreen (S5)',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();
    final store = InMemorySecureTokenStore();
    await store.saveToken('stored-jwt');
    await store.setBiometricsEnabled(true);

    final authService = FakeRoleAuthService(
      'SOCIO',
      bioAvailable: true,
      tokenStore: store,
      biometric: FakeBiometricAuthenticator(true),
    );
    final planService = FakePlanService(const PlanModulosInfo(
      plan: PlanInfo(codigo: 'BASICO', nombre: 'Básico'),
      modulos: ['reportes_gerenciales'],
      sinRestriccion: false,
    ));

    await tester.pumpWidget(_wrap(LoginScreen(
      authService: authService,
      planService: planService,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar con Biometría'), findsOneWidget);
    await tester.tap(find.text('Ingresar con Biometría'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanBloqueadoScreen), findsOneWidget);
    expect(find.byType(MainNavigationScreen), findsNothing);
  });

  testWidgets(
      'iniciar login limpia PlanService.currentInfo al empezar (Defecto 4)',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();
    PlanService.currentInfo = const PlanModulosInfo(
      plan: PlanInfo(codigo: 'RED_ENTERPRISE', nombre: 'Enterprise'),
      modulos: ['banca_movil', 'recredito_ia'],
    );
    expect(PlanService.currentInfo, isNotNull);

    final authService = FakeRoleAuthService(
      'SOCIO',
      tokenStore: InMemorySecureTokenStore(),
      biometric: FakeBiometricAuthenticator(false),
    );

    await tester.pumpWidget(_wrap(LoginScreen(
      authService: authService,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();

    expect(PlanService.currentInfo?.plan?.codigo, isNot('RED_ENTERPRISE'));
  });
}
