import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificaciones del sistema (barra de Android) con sonido y vibración.
///
/// Best-effort: si el plugin no está disponible (tests, plataforma sin
/// soporte) o el usuario negó el permiso, simplemente no se muestra nada.
class SystemNotifications {
  SystemNotifications._();

  static final SystemNotifications instance = SystemNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _nextId = 0;

  /// Se ejecuta cuando el usuario toca una notificación de la barra.
  VoidCallback? onTap;

  // Importance.max + Priority.high: aviso emergente (heads-up) con el sonido
  // y la vibración por defecto del teléfono.
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'nexacoop_avisos',
      'Avisos de la cooperativa',
      channelDescription: 'Recordatorios de pago, promociones y movimientos de tus cuentas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  /// Inicializa el plugin y pide el permiso de notificaciones (Android 13+).
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => onTap?.call(),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Sin plugin (p. ej. en `flutter test`): las notificaciones quedan solo dentro de la app.
    }
  }

  Future<void> show({required String title, required String body}) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: _details,
      );
    } catch (_) {}
  }
}
