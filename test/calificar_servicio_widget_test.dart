import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/screens/calificar_servicio_screen.dart';
import 'package:forest_microfinance/services/feedback_service.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

Widget _buildTestApp({required Widget child}) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  final previousToken = AuthService.tokenJWT;

  setUp(() {
    AuthService.tokenJWT = 'test-token-jwt';
  });

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  testWidgets('CalificarServicioScreen renderiza formulario y lista de historial',
      (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/feedback/mias')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'servicio': 'CREDITO',
              'calificacion': 5,
              'recomendaria': 10,
              'comentario': 'Muy buen trato del oficial',
              'canal': 'MOVIL',
              'fecha': '2026-11-20T12:00:00Z',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });

    final service = FeedbackService(client: mockClient);

    await tester.pumpWidget(
      _buildTestApp(
        child: CalificarServicioScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    // Verifica elementos clave del formulario
    expect(find.text('Calificar servicio'), findsOneWidget);
    expect(find.text('Tu experiencia nos importa'), findsOneWidget);
    expect(find.text('SERVICIO A EVALUAR'), findsOneWidget);
    expect(find.text('CALIFICACIÓN GENERAL'), findsOneWidget);
    expect(find.text('¿NOS RECOMENDARÍAS? (0-10)'), findsOneWidget);
    expect(find.text('ENVIAR CALIFICACIÓN'), findsOneWidget);

    // Verifica que se cargó el historial de calificaciones anteriores
    expect(find.text('MIS CALIFICACIONES ANTERIORES'), findsOneWidget);
    expect(find.text('Crédito'), findsWidgets);
    expect(find.text('"Muy buen trato del oficial"'), findsOneWidget);
    expect(find.text('10/10'), findsOneWidget);
  });

  testWidgets('Envío de calificación envía canal MOVIL y actualiza historial',
      (WidgetTester tester) async {
    String? requestBody;
    int postCount = 0;

    final mockClient = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/feedback')) {
        postCount++;
        requestBody = request.body;
        return http.Response(
          jsonEncode({
            'id': 99,
            'servicio': 'AHORRO',
            'calificacion': 4,
            'recomendaria': 9,
            'comentario': 'Rápido depósito',
            'canal': 'MOVIL',
            'fecha': '2026-11-20T21:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'GET' && request.url.path.endsWith('/feedback/mias')) {
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('{}', 404);
    });

    final service = FeedbackService(client: mockClient);

    await tester.pumpWidget(
      _buildTestApp(
        child: CalificarServicioScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();

    // Selecciona recomendación 9
    final chip9 = find.text('9');
    expect(chip9, findsOneWidget);
    await tester.tap(chip9);
    await tester.pumpAndSettle();

    // Escribe comentario
    final comentarioInput = find.byType(TextField);
    expect(comentarioInput, findsOneWidget);
    await tester.enterText(comentarioInput, 'Rápido depósito');
    await tester.pumpAndSettle();

    // Scroll hasta el botón enviar y enviar
    final submitButton = find.text('ENVIAR CALIFICACIÓN');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump(); // Inicia envío

    await tester.pumpAndSettle(); // Completa envío y respuesta

    expect(postCount, 1);
    expect(requestBody, isNotNull);
    final sent = jsonDecode(requestBody!);
    expect(sent['canal'], 'MOVIL');
    expect(sent['recomendaria'], 9);
    expect(sent['comentario'], 'Rápido depósito');

    // Verifica que se mostró el SnackBar de éxito
    expect(find.text('¡Gracias por tu opinión! Tu calificación ha sido registrada.'), findsOneWidget);
  });
}
