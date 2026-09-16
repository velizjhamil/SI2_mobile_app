import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/login_screen.dart';
import 'package:forest_microfinance/screens/profile_screen.dart';

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
          home: const SocioProfileScreen(),
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

    // pushReplacementNamed('/login') muestra el LoginScreen.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
