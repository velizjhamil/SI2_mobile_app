import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import 'secure_token_store.dart';

class AuthResult {
  final bool success;
  final String? error;
  final String? token;
  final String? role;
  final Map<String, dynamic>? user;

  const AuthResult.success({this.token, this.role})
      : success = true,
        error = null,
        user = null;
  const AuthResult.failure(this.error)
      : success = false,
        token = null,
        role = null,
        user = null;
  const AuthResult._user(Map<String, dynamic> this.user)
      : success = true,
        error = null,
        token = null,
        role = null;
}

abstract class BiometricAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate();
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication localAuth;
  LocalBiometricAuthenticator({LocalAuthentication? localAuth})
      : localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await localAuth.canCheckBiometrics &&
          await localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() => localAuth.authenticate(
        localizedReason: 'Autentícate para ingresar a CoopIA.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
}

class FakeBiometricAuthenticator implements BiometricAuthenticator {
  final bool available;
  bool prompted = false;
  bool result;
  FakeBiometricAuthenticator(this.available, {this.result = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    prompted = true;
    return result;
  }
}

class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static String? tokenJWT;
  static final SecureTokenStore defaultStore = FlutterSecureTokenStore();
  static SecureTokenStore currentStore = defaultStore;

  final SecureTokenStore tokenStore;
  final BiometricAuthenticator biometric;

  AuthService({
    SecureTokenStore? tokenStore,
    BiometricAuthenticator? biometric,
  })  : tokenStore = tokenStore ?? defaultStore,
        biometric = biometric ?? LocalBiometricAuthenticator() {
    currentStore = this.tokenStore;
  }

  Future<AuthResult> login(
    String email,
    String password, {
    http.Client? client,
  }) async {
    tokenJWT = null;
    final httpClient = client ?? http.Client();
    final close = client == null;
    try {
      final response = await httpClient
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'correo': email.trim(),
              'contrasena': password,
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        if (response.statusCode == 400 || response.statusCode == 401) {
          return const AuthResult.failure(
            'Credenciales inválidas. Verifique su correo y contraseña.',
          );
        }
        return AuthResult.failure(
          'Error en el servidor (${response.statusCode}). Intente más tarde.',
        );
      }
      final decoded = _map(response.body);
      final token = decoded['access_token']?.toString();
      if (token == null || token.isEmpty) {
        return const AuthResult.failure(
            'El servidor no entregó un token válido.');
      }
      final me = await _currentUser(token, client: httpClient);
      if (!me.success) return me;
      final role = _role(me.user!);
      if (role != 'SOCIO' && role != 'OFICIAL_CREDITO') {
        return const AuthResult.failure(
          'Esta aplicación es para socios y oficiales de crédito',
        );
      }
      tokenJWT = token;
      if (await tokenStore.biometricsEnabled()) {
        await tokenStore.saveToken(
          token,
          expiresAt: _expiryFromToken(token) ??
              _expiryFromLogin(decoded['expires_in']),
          email: email.trim(),
        );
      }
      return AuthResult.success(token: token, role: role);
    } on TimeoutException {
      return const AuthResult.failure(
          'Tiempo de espera agotado. Intente nuevamente.');
    } catch (_) {
      return const AuthResult.failure(
        'No se pudo conectar con el servidor. Verifique su conexión.',
      );
    } finally {
      if (close) httpClient.close();
    }
  }

  Future<AuthResult> authenticateWithBiometrics({
    http.Client? client,
  }) async {
    if (!await tokenStore.biometricsEnabled()) {
      return const AuthResult.failure(
        'Ingrese con su contraseña para habilitar la biometría.',
      );
    }
    final storedToken = await tokenStore.readToken();
    if (storedToken == null || storedToken.isEmpty) {
      return const AuthResult.failure(
        'No hay una sesión biométrica guardada. Ingrese con su contraseña.',
      );
    }
    final expiry =
        await tokenStore.readExpiry() ?? _expiryFromToken(storedToken);
    if (expiry != null && expiry.isBefore(DateTime.now().toUtc())) {
      await _disableStoredBiometrics();
      return const AuthResult.failure(
        'La sesión biométrica expiró. Ingrese con su contraseña.',
      );
    }
    if (!await biometric.isAvailable() || !await biometric.authenticate()) {
      return const AuthResult.failure(
          'Autenticación biométrica cancelada o fallida.');
    }
    final me = await _currentUser(storedToken, client: client);
    if (!me.success) {
      await _disableStoredBiometrics();
      return AuthResult.failure(
        me.error ??
            'La sesión biométrica ya no es válida. Ingrese con su contraseña.',
      );
    }
    final role = _role(me.user!);
    if (role != 'SOCIO' && role != 'OFICIAL_CREDITO') {
      await _disableStoredBiometrics();
      return const AuthResult.failure(
        'Esta aplicación es para socios y oficiales de crédito',
      );
    }
    tokenJWT = storedToken;
    return AuthResult.success(token: storedToken, role: role);
  }

  Future<AuthResult> _currentUser(
    String token, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final close = client == null;
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return AuthResult._user(_map(response.body));
      }
      if (response.statusCode == 401) {
        return const AuthResult.failure(
          'La sesión no es válida. Ingrese con su contraseña.',
        );
      }
      final detail = _map(response.body)['detail'];
      return AuthResult.failure(
        detail is String ? detail : 'No se pudo validar la sesión.',
      );
    } catch (_) {
      return const AuthResult.failure(
        'No se pudo validar la sesión. Verifique su conexión.',
      );
    } finally {
      if (close) httpClient.close();
    }
  }

  Future<void> enableBiometrics({String? email}) async {
    final token = tokenJWT;
    if (token == null || token.isEmpty) return;
    await tokenStore.setBiometricsEnabled(true);
    await tokenStore.saveToken(
      token,
      expiresAt: _expiryFromToken(token),
      email: email,
    );
  }

  Future<void> disableBiometrics() => _disableStoredBiometrics();

  Future<bool> isBiometricAvailable() => biometric.isAvailable();

  Future<void> logout({http.Client? client}) async {
    final token = tokenJWT;
    final httpClient = client ?? http.Client();
    final close = client == null;
    try {
      if (token != null && token.isNotEmpty) {
        await httpClient.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      // Logout is best-effort; local session cleanup must always happen.
    } finally {
      if (close) httpClient.close();
      tokenJWT = null;
      await tokenStore.clearToken();
    }
  }

  Future<void> _disableStoredBiometrics() async {
    await tokenStore.clearToken();
    await tokenStore.setBiometricsEnabled(false);
    tokenJWT = null;
  }

  static Map<String, dynamic> _map(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map ? value.cast<String, dynamic>() : {};
    } catch (_) {
      return {};
    }
  }

  static String? _role(Map<String, dynamic> data) {
    final role = data['rol'] ?? data['role'];
    if (role is Map) {
      return role['nombre']?.toString().toUpperCase();
    }
    final nested = data['usuario'];
    if (nested is Map) return _role(nested.cast<String, dynamic>());
    return role?.toString().toUpperCase();
  }

  static DateTime? _expiryFromLogin(dynamic expiresIn) {
    if (expiresIn is num) {
      return DateTime.now().toUtc().add(
            Duration(seconds: expiresIn.toInt()),
          );
    }
    return null;
  }

  static DateTime? _expiryFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      return exp is num
          ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true)
          : null;
    } catch (_) {
      return null;
    }
  }
}
