import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/main.dart';
import 'package:forest_microfinance/screens/login_screen.dart';

void main() {
  testWidgets('La app arranca en LoginScreen sin crashear',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const ForestMicrofinanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
