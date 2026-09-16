import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/login_screen.dart';
import 'package:forest_microfinance/screens/main_navigation_screen.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
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
}
