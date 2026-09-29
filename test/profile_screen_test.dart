import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/login_screen.dart';
import 'package:forest_microfinance/screens/profile_screen.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/secure_token_store.dart';

/// profile_screen.dart envuelve ListTiles en Containers con color de fondo,
/// lo que dispara un FlutterError informativo en modo debug
/// ("ink splashes may be invisible"). Es un aviso preexistente de la UI,
/// ajeno al comportamiento de navegación que verifica este test, así que
/// se ignora solo ese aviso y se conserva el resto del manejo de errores.
void _ignorarAvisoListTileConFondo() {
  final originalOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = originalOnError);
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('ink splashes may be invisible')) return;
    originalOnError?.call(details);
  };
}

void main() {
  testWidgets('Tocar CERRAR SESIÓN navega a la ruta /login',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: SocioProfileScreen(
            authService: AuthService(
              tokenStore: InMemorySecureTokenStore(),
              biometric: FakeBiometricAuthenticator(false),
            ),
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final logoutButton = find.text('CERRAR SESIÓN');
    expect(logoutButton, findsOneWidget);

    // El botón puede estar fuera de la vista (scroll): llevarlo a pantalla.
    await tester.scrollUntilVisible(logoutButton, 300.0);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();

    // pushNamedAndRemoveUntil('/login') muestra el LoginScreen.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });

  testWidgets('logout confirms, clears session and removes back navigation',
      (WidgetTester tester) async {
    _ignorarAvisoListTileConFondo();
    final store = InMemorySecureTokenStore();
    AuthService.tokenJWT = 'token';
    final service = AuthService(
      tokenStore: store,
      biometric: FakeBiometricAuthenticator(false),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: SocioProfileScreen(authService: service),
          routes: {'/login': (_) => const LoginScreen()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CERRAR SESIÓN'), 300);
    await tester.tap(find.text('CERRAR SESIÓN'));
    await tester.pumpAndSettle();

    expect(find.text('¿Deseas cerrar tu sesión?'), findsOneWidget);
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(AuthService.tokenJWT, isNull);
  });
}
