import 'package:flutter/material.dart';

import 'mock_auth_service.dart';
import 'secure_token_store.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

class SessionManager {
  // Configured once by the app; injected AuthService instances never replace it.
  static void configure(SecureTokenStore store) {
    AuthService.currentStore = store;
  }

  static Future<void> onUnauthorized() async {
    try {
      AuthService.tokenJWT = null;
      AuthService.currentRole = null;
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
