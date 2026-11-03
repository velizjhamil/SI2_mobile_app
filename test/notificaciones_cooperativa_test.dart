import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:forest_microfinance/services/mock_auth_service.dart';
import 'package:forest_microfinance/services/notification_service.dart';
import 'package:forest_microfinance/services/notificaciones_cooperativa_service.dart';

Map<String, dynamic> _item(int id, {bool leida = false, String titulo = 'Aviso'}) => {
      'id': id,
      'tipo': 'RECORDATORIO_PAGO',
      'titulo': titulo,
      'mensaje': 'Hola Sofía, tu cuota vence pronto',
      'fecha': '2026-11-03T12:00:00Z',
      'leida': leida,
    };

/// Bandeja del backend en memoria; registra lo marcado como leído.
class _FakeService extends NotificacionesCooperativaService {
  List<NotificacionCooperativa>? bandeja = [];
  final List<int> leidas = [];
  int todas = 0;

  void poner(List<Map<String, dynamic>> items) =>
      bandeja = items.map(NotificacionCooperativa.fromJson).toList();

  @override
  Future<List<NotificacionCooperativa>?> listar() async => bandeja;

  @override
  Future<bool> marcarLeida(int id) async {
    leidas.add(id);
    return true;
  }

  @override
  Future<bool> marcarTodas() async {
    todas++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousToken = AuthService.tokenJWT;

  void login(String userId) {
    AuthService.tokenJWT = 'jwt-de-prueba';
    AuthService.currentUserId = userId;
  }

  tearDown(() {
    AuthService.tokenJWT = previousToken;
  });

  group('NotificacionesCooperativaService', () {
    test('lista /notificaciones/mias con el token y decodifica UTF-8', () async {
      login('7');
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'no_leidas': 1, 'items': [_item(5)]})),
          200,
        );
      });

      final items = await NotificacionesCooperativaService(client: client).listar();

      expect(captured.url.path, endsWith('/notificaciones/mias'));
      expect(captured.headers['Authorization'], 'Bearer jwt-de-prueba');
      expect(items, hasLength(1));
      expect(items!.first.id, 5);
      expect(items.first.mensaje, contains('Sofía'));
      expect(items.first.leida, isFalse);
    });

    test('sin sesión o con error devuelve null/false sin lanzar', () async {
      AuthService.tokenJWT = null;
      expect(await NotificacionesCooperativaService().listar(), isNull);

      login('7');
      final failing = MockClient((_) async => http.Response('boom', 500));
      final service = NotificacionesCooperativaService(client: failing);
      expect(await service.listar(), isNull);
      expect(await service.marcarLeida(1), isFalse);
    });

    test('marcar leída llama al endpoint del destinatario', () async {
      login('7');
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        return http.Response('{}', 200);
      });
      final service = NotificacionesCooperativaService(client: client);

      expect(await service.marcarLeida(9), isTrue);
      expect(await service.marcarTodas(), isTrue);
      expect(calls, [
        'POST /api/v1/notificaciones/mias/9/leer',
        'POST /api/v1/notificaciones/mias/leer-todas',
      ].map((path) => path.replaceFirst('/api/v1', Uri.parse(AuthService.baseUrl).path)));
    });
  });

  group('NotificationProvider + cooperativa', () {
    test('la primera sincronización carga la bandeja; las nuevas se agregan sin leer', () async {
      login('7');
      final fake = _FakeService()..poner([_item(2, leida: true), _item(1)]);
      final provider = NotificationProvider(cooperativaService: fake);

      await provider.checkCooperativa();
      expect(provider.notifications.map((n) => n.remoteId), [2, 1]);
      expect(provider.unreadCount, 1);

      fake.poner([_item(3, titulo: 'Promo'), _item(2, leida: true), _item(1)]);
      await provider.checkCooperativa();
      expect(provider.notifications.first.title, 'Promo');
      expect(provider.notifications.first.type, NotificationType.cooperativa);
      expect(provider.unreadCount, 2);

      // Repeated polls never duplicate notifications.
      await provider.checkCooperativa();
      expect(provider.notifications, hasLength(3));
    });

    test('leer en la app también la marca leída en el backend', () async {
      login('7');
      final fake = _FakeService()..poner([_item(4), _item(3)]);
      final provider = NotificationProvider(cooperativaService: fake);
      await provider.checkCooperativa();

      provider.markAsRead(provider.notifications.first.id);
      expect(fake.leidas, [4]);
      provider.markAllAsRead();
      expect(fake.todas, 1);
      expect(provider.unreadCount, 0);

      // Nothing left unread: no extra backend call.
      provider.markAllAsRead();
      expect(fake.todas, 1);
    });

    test('otro usuario no ve la bandeja del anterior', () async {
      login('7');
      final fake = _FakeService()..poner([_item(1)]);
      final provider = NotificationProvider(cooperativaService: fake);
      await provider.checkCooperativa();
      expect(provider.notifications, hasLength(1));

      login('8');
      fake.poner([_item(20)]);
      await provider.checkCooperativa();
      expect(provider.notifications.map((n) => n.remoteId), [20]);
    });
  });
}
