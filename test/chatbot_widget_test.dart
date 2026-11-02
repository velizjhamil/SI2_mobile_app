import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:forest_microfinance/core/theme/theme_provider.dart';
import 'package:forest_microfinance/models/chat_model.dart';
import 'package:forest_microfinance/models/solicitud_credito_model.dart';
import 'package:forest_microfinance/screens/chatbot_screen.dart';
import 'package:forest_microfinance/services/chatbot_service.dart';
import 'package:forest_microfinance/services/chatbot_audio_service.dart';
import 'package:forest_microfinance/services/socio_service.dart';

/// Fake que responde sin red, con sugerencias propias del backend.
class FakeChatbotService extends ChatbotService {
  final List<String> sentMessages = [];
  final List<List<ChatMessage>> sentHistories = [];

  @override
  Future<ChatbotResult> enviarMensaje({
    required String mensaje,
    required List<ChatMessage> historial,
    http.Client? client,
  }) async {
    sentMessages.add(mensaje);
    sentHistories.add(List<ChatMessage>.of(historial));
    if (mensaje.contains('saldo')) {
      return const ChatbotResult.success(
        ChatbotReply(
          respuesta: 'Tu ahorro total es 1 250.50.',
          intent: 'ahorro',
          fuente: 'PLANTILLA',
          sugerencias: ['¿Tengo cuotas vencidas?'],
        ),
      );
    }
    return const ChatbotResult.success(
      ChatbotReply(
        respuesta: 'No tienes cuotas vencidas. ¡Buen historial de pago!',
        intent: 'mora',
        fuente: 'PLANTILLA',
        sugerencias: [],
      ),
    );
  }
}

/// Fake que siempre falla (simula error de red).
class FakeChatbotServiceError extends ChatbotService {
  @override
  Future<ChatbotResult> enviarMensaje({
    required String mensaje,
    required List<ChatMessage> historial,
    http.Client? client,
  }) async {
    return const ChatbotResult.failure(
      'No se pudo conectar con el servidor. Verifique su conexión.',
    );
  }
}

class FakeChatbotAudioService extends ChatbotAudioService {
  @override
  Future<bool> startDictation() async {
    onTranscript?.call('Consulta dictada');
    return true;
  }

  @override
  Future<void> stopDictation() async {}

  @override
  Future<void> cancelDictation() async {}

  @override
  Future<void> speak(String text) async {
    onPlaybackComplete?.call();
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeCreditRequestService extends SocioService {
  int catalogLoads = 0;
  int submissionAttempts = 0;

  @override
  Future<SocioResult<List<ProductoCreditoSocio>>> creditProducts({
    http.Client? client,
  }) async {
    catalogLoads++;
    return const SocioResult.success([]);
  }

  @override
  Future<SocioResult<SolicitudCreditoItem>> createCreditRequest({
    required int productId,
    required String amount,
    required int termMonths,
    required String destination,
    String? destinationDetail,
    required DatosDeclarados declaredData,
    http.Client? client,
  }) async {
    submissionAttempts++;
    return const SocioResult.failure('Unexpected request submission');
  }
}

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  group('ChatbotScreen', () {
    testWidgets('muestra el mensaje inicial y el título de Castor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(chatbotService: FakeChatbotService())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Castor Asistente IA'), findsOneWidget);
      expect(find.textContaining('copiloto financiero'), findsOneWidget);
      expect(find.text('¿Cuál es mi saldo?'), findsOneWidget);
    });

    testWidgets('enviar mensaje muestra la respuesta del asistente',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(chatbotService: FakeChatbotService())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '¿Cuál es mi saldo?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Burbuja del usuario y respuesta de Castor.
      expect(find.text('¿Cuál es mi saldo?'), findsWidgets);
      expect(find.textContaining('ahorro total es 1 250.50'), findsOneWidget);
      // Las sugerencias se reemplazan por las del backend.
      expect(find.text('¿Tengo cuotas vencidas?'), findsOneWidget);
    });

    testWidgets('el historial enviado contiene solo turnos anteriores',
        (WidgetTester tester) async {
      final chatbot = FakeChatbotService();
      await tester.pumpWidget(_wrap(ChatbotScreen(chatbotService: chatbot)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Consulta anterior');
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Consulta actual');
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();

      expect(chatbot.sentHistories, hasLength(2));
      expect(chatbot.sentHistories[0], hasLength(1));
      expect(chatbot.sentHistories[0].single.role, 'assistant');
      expect(
        chatbot.sentHistories[1].map((message) => message.content),
        contains('Consulta anterior'),
      );
      expect(
        chatbot.sentHistories[1].map((message) => message.content),
        isNot(contains('Consulta actual')),
      );
    });

    testWidgets('el campo permanece sobre el teclado sin desbordamiento',
        (WidgetTester tester) async {
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);

      await tester.pumpWidget(
        _wrap(ChatbotScreen(chatbotService: FakeChatbotService())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();

      final inputBottom = tester.getBottomLeft(find.byType(TextField)).dy;
      expect(inputBottom, lessThanOrEqualTo(800 - 300));
      expect(inputBottom, greaterThan(800 - 300 - 64));
      expect(tester.takeException(), isNull);
    });

    testWidgets('un fallo muestra burbuja de error en español',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(chatbotService: FakeChatbotServiceError())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hola');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'No se pudo conectar con el servidor. Verifique su conexión.'),
        findsOneWidget,
      );
    });

    testWidgets('tocar una sugerencia la envía como mensaje',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(chatbotService: FakeChatbotService())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Cuál es mi saldo?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ahorro total es 1 250.50'), findsOneWidget);
    });

    testWidgets('dictado coloca la transcripción en el campo de texto',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(
          chatbotService: FakeChatbotService(),
          audioService: FakeChatbotAudioService(),
        )),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Tengo una consulta:');
      await tester.tap(find.byTooltip('Dictar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Tengo una consulta: Consulta dictada'), findsOneWidget);
      expect(find.byTooltip('Detener dictado'), findsOneWidget);
    });

    testWidgets('respuesta ofrece reproducción explícita',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(ChatbotScreen(
          chatbotService: FakeChatbotService(),
          audioService: FakeChatbotAudioService(),
        )),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hola');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Escuchar respuesta'), findsWidgets);
    });

    testWidgets('dictated text uses the same chatbot send flow',
        (WidgetTester tester) async {
      final chatbot = FakeChatbotService();
      await tester.pumpWidget(
        _wrap(ChatbotScreen(
          chatbotService: chatbot,
          audioService: FakeChatbotAudioService(),
        )),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dictar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();

      expect(chatbot.sentMessages, ['Consulta dictada']);
    });

    testWidgets('credit action opens the existing catalog and does not submit',
        (WidgetTester tester) async {
      final chatbot = FakeChatbotService();
      final creditService = FakeCreditRequestService();
      await tester.pumpWidget(
        _wrap(ChatbotScreen(
          chatbotService: chatbot,
          audioService: FakeChatbotAudioService(),
          creditRequestService: creditService,
        )),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sí');
      await tester.tap(find.byTooltip('Enviar mensaje'));
      await tester.pumpAndSettle();
      expect(creditService.submissionAttempts, 0);

      await tester.tap(find.text('Solicitar crédito'));
      await tester.pumpAndSettle();

      expect(
        find.text('No hay productos crediticios disponibles por el momento.'),
        findsOneWidget,
      );
      expect(creditService.catalogLoads, 1);
      expect(creditService.submissionAttempts, 0);
      expect(chatbot.sentMessages, ['sí']);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Castor Asistente IA'), findsOneWidget);
      expect(creditService.submissionAttempts, 0);
    });
  });
}
