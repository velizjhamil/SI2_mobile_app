import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'mock_auth_service.dart';
import 'notification_service.dart';

const _backgroundNotificationsKey = 'pending_background_notifications';
const _notificationOwnerKey = 'notification_user_id';
const _maxPendingBackgroundNotifications = 50;

@pragma('vm:entry-point')
Future<void> handleFcmBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // FCM is optional until Firebase project configuration is supplied.
  }
  try {
    const storage = FlutterSecureStorage();
    final owner = await storage.read(key: _notificationOwnerKey);
    if (owner == null || owner.isEmpty) return;

    final encoded = await storage.read(key: _backgroundNotificationsKey);
    final pending = encoded == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(encoded) as List)
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    final data = message.data;
    pending.add({
      'owner': owner,
      'id': '${data['installment_id']}:${data['event_key']}',
      'title': message.notification?.title ?? 'Notificación',
      'body': message.notification?.body ?? '',
      'credit_id': data['credit_id']?.toString(),
    });
    final bounded = pending.length > _maxPendingBackgroundNotifications
        ? pending.sublist(pending.length - _maxPendingBackgroundNotifications)
        : pending;
    await storage.write(
      key: _backgroundNotificationsKey,
      value: jsonEncode(bounded),
    );
  } catch (_) {
    // Background persistence must never prevent the system push from showing.
  }
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _channelId = 'credit_reminders';
  static const _registeredTokenKey = 'registered_fcm_token';
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  NotificationProvider? _provider;
  bool _available = false;
  bool _revoking = false;
  Map<String, dynamic>? _pendingTap;

  Future<void> initialize() async {
const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          _open(jsonDecode(response.payload!) as Map<String, dynamic>);
        } catch (_) {}
      },
    );
    final localLaunch = await _local.getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true) {
      try {
        _pendingTap = jsonDecode(
          localLaunch?.notificationResponse?.payload ?? '{}',
        ) as Map<String, dynamic>;
      } catch (_) {}
    }
    const channel = AndroidNotificationChannel(
      _channelId,
      'Recordatorios de crédito',
      description: 'Avisos de pagos y vencimientos de cuotas.',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    try {
      await Firebase.initializeApp();
      _available = true;
      FirebaseMessaging.onBackgroundMessage(handleFcmBackgroundMessage);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _pendingTap = {
          ...initial.data,
          'title': initial.notification?.title ?? 'Notificación',
          'body': initial.notification?.body ?? '',
        };
      }
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      await refreshToken();
    } catch (_) {
      _available = false;
    }
  }

  void bindProvider(NotificationProvider provider) {
    _provider = provider;
    final owner = AuthService.currentUserId;
    if (owner != null && owner.isNotEmpty) {
      unawaited(_hydrateBackgroundNotifications(owner));
    }
    final pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) _open(pending);
  }

  Future<void> refreshToken() async {
    if (!_available || AuthService.tokenJWT == null) return;
    _revoking = false;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> onAuthenticated() async {
    final owner = AuthService.currentUserId;
    if (owner == null || owner.isEmpty) {
      _provider?.clearAll();
      await _clearPendingBackgroundNotifications();
      return;
    }

    try {
      final previousOwner =
          await _secureStorage.read(key: _notificationOwnerKey);
      if (previousOwner != owner) {
        _provider?.clearAll();
        await _secureStorage.delete(key: _backgroundNotificationsKey);
      } else {
        await _hydrateBackgroundNotifications(owner);
      }
      await _secureStorage.write(key: _notificationOwnerKey, value: owner);
    } catch (_) {}
    await refreshToken();
  }

  Future<void> revokeCurrentToken() async {
    _provider?.clearAll();
    await _clearPendingBackgroundNotifications();
    if (!_available) return;
    _revoking = true;
    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {}
    String? previousToken;
    try {
      previousToken = await _secureStorage.read(key: _registeredTokenKey);
    } catch (_) {}
    final auth = AuthService.tokenJWT;
    final tokens = {
      if (token != null) token,
      if (previousToken != null) previousToken
    };
    if (tokens.isNotEmpty && auth != null) {
      try {
        await http
            .delete(
              Uri.parse('${AuthService.baseUrl}/notifications/devices/fcm'),
              headers: {
                'Authorization': 'Bearer $auth',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'token': tokens.first,
                'previous_token': tokens.length > 1 ? tokens.last : null,
                'platform': 'android',
              }),
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    try {
      await _secureStorage.delete(key: _registeredTokenKey);
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _hydrateBackgroundNotifications(String owner) async {
    final provider = _provider;
    if (provider == null) return;
    try {
      final encoded =
          await _secureStorage.read(key: _backgroundNotificationsKey);
      if (encoded == null) return;
      final pending = jsonDecode(encoded);
      if (pending is List) {
        for (final entry in pending.whereType<Map>()) {
          final item = entry.cast<String, dynamic>();
          if (item['owner'] != owner) continue;
          provider.addRemoteNotification(
            id: item['id']?.toString() ?? '',
            title: item['title']?.toString() ?? 'Notificación',
            message: item['body']?.toString() ?? '',
            creditId: int.tryParse(item['credit_id']?.toString() ?? ''),
          );
        }
      }
    } catch (_) {
      // Invalid or unavailable pending data is discarded below.
    } finally {
      await _secureStorage.delete(key: _backgroundNotificationsKey);
    }
  }

  Future<void> _clearPendingBackgroundNotifications() async {
    try {
      await _secureStorage.delete(key: _backgroundNotificationsKey);
    } catch (_) {}
    try {
      await _secureStorage.delete(key: _notificationOwnerKey);
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final auth = AuthService.tokenJWT;
    if (_revoking || auth == null || auth.isEmpty) return;
    try {
      final previousToken = await _secureStorage.read(key: _registeredTokenKey);
      final response = await http
          .put(
            Uri.parse('${AuthService.baseUrl}/notifications/devices/fcm'),
            headers: {
              'Authorization': 'Bearer $auth',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'token': token,
              'platform': 'android',
              if (previousToken != null && previousToken != token)
                'previous_token': previousToken,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 204) {
        await _secureStorage.write(key: _registeredTokenKey, value: token);
      }
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? 'Notificación';
    final body = message.notification?.body ?? '';
    final creditId = int.tryParse(data['credit_id']?.toString() ?? '');
    _provider?.addRemoteNotification(
      id: '${data['installment_id']}:${data['event_key']}',
      title: title,
      message: body,
      creditId: creditId,
    );
    if (_provider?.notificationsEnabled ?? true) {
      _showSystemNotification(title, body, data);
    }
  }

  void _onNotificationOpened(RemoteMessage message) {
    _open({
      ...message.data,
      'title': message.notification?.title ?? 'Notificación',
      'body': message.notification?.body ?? '',
    });
  }

  Future<void> _showSystemNotification(
      String title, String body, Map<String, dynamic> data) async {
    await _local.show(
      data['installment_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Recordatorios de crédito',
          channelDescription: 'Avisos de pagos y vencimientos de cuotas.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  void _open(Map<String, dynamic> data) {
    if (data['screen'] != 'credit_schedule') return;
    final creditId = int.tryParse(data['credit_id']?.toString() ?? '');
    if (creditId == null) return;
    _provider?.addRemoteNotification(
      id: '${data['installment_id']}:${data['event_key']}',
      title: data['title']?.toString() ?? 'Notificación',
      message: data['body']?.toString() ?? '',
      creditId: creditId,
    );
    if (_provider == null) {
      _pendingTap = data;
      return;
    }
    _provider?.openCreditSchedule(creditId);
  }
}
