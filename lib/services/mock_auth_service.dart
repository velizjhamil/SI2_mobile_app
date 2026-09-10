import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

/// Result of an authentication attempt.
class AuthResult {
  final bool success;
  final String? error;
  final String? token;

  const AuthResult.success({this.token}) : success = true, error = null;
  const AuthResult.failure(this.error) : success = false, token = null;
}

/// Real Auth Service connected to FastAPI backend in Docker.
class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  static String? tokenJWT;

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<AuthResult> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'username': email.trim(),
          'password': password,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        tokenJWT = data['access_token']; // O el nombre del campo del token en tu API
        
        return AuthResult.success(token: tokenJWT);
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        return const AuthResult.failure(
          'Credenciales inválidas. Verifique su correo y contraseña.',
        );
      } else {
        return AuthResult.failure(
          'Error en el servidor (${response.statusCode}). Intente más tarde.',
        );
      }
    } catch (e) {
      return AuthResult.failure(
        'No se pudo conectar con el servidor. Verifique si Docker está activo.',
      );
    }
  }

  /// Checks if the device has enrolled biometrics (fingerprint / Face ID).
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuth = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuth && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Triggers the native biometric prompt (Huella / Face ID).
  Future<AuthResult> authenticateWithBiometrics() async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        return const AuthResult.failure(
          'Este dispositivo no tiene biometría configurada.',
        );
      }

      final didAuth = await _localAuth.authenticate(
        localizedReason:
            'Autentícate con tu huella o Face ID para ingresar a COOPIA.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuth) {
        // NOTA: Si usas biometría, deberías recuperar un token guardado previamente.
        if (tokenJWT != null) {
          return AuthResult.success(token: tokenJWT);
        }
        return const AuthResult.success();
      }

      return const AuthResult.failure(
        'Autenticación biométrica cancelada o fallida.',
      );
    } on PlatformException catch (e) {
      return AuthResult.failure(
        'Error de biometría: ${e.message ?? 'desconocido'}',
      );
    }
  }
}