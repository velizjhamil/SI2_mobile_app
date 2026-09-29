import 'package:flutter/material.dart';

import 'mock_auth_service.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class SessionManager {
  static Future<void> onUnauthorized() async {
    try {
      AuthService.tokenJWT = null;
      await AuthService.currentStore.clearToken();
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: 'Tu sesión expiró. Ingresá nuevamente.',
      );
    } catch (_) {
      // An expired session must still be treated as unauthorized if storage or
      // navigation is unavailable.
    }
  }
}
