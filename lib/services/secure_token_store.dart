import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

abstract class SecureTokenStore {
  Future<String?> readToken();
  Future<DateTime?> readExpiry();
  Future<bool> biometricsEnabled();
  Future<void> saveToken(String token, {DateTime? expiresAt, String? email});
  Future<void> clearToken();
  Future<void> setBiometricsEnabled(bool enabled);
}

class FlutterSecureTokenStore implements SecureTokenStore {
  static const _tokenKey = 'auth_token';
  static const _expiryKey = 'auth_token_expiry';
  static const _emailKey = 'auth_email';
  static const _biometricKey = 'biometria_habilitada';

  final FlutterSecureStorage storage;
  const FlutterSecureTokenStore({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() async {
    try {
      return await storage.read(key: _tokenKey);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<DateTime?> readExpiry() async {
    String? value;
    try {
      value = await storage.read(key: _expiryKey);
    } on MissingPluginException {
      return null;
    }
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<bool> biometricsEnabled() async {
    try {
      return (await storage.read(key: _biometricKey)) == 'true';
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> saveToken(
    String token, {
    DateTime? expiresAt,
    String? email,
  }) async {
    await storage.write(key: _tokenKey, value: token);
    if (expiresAt != null) {
      await storage.write(key: _expiryKey, value: expiresAt.toIso8601String());
    }
    if (email != null) await storage.write(key: _emailKey, value: email);
  }

  @override
  Future<void> clearToken() async {
    try {
      await storage.delete(key: _tokenKey);
      await storage.delete(key: _expiryKey);
      await storage.delete(key: _emailKey);
    } on MissingPluginException {
      return;
    }
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) => _writeBiometric(enabled);

  Future<void> _writeBiometric(bool enabled) async {
    try {
      await storage.write(key: _biometricKey, value: enabled.toString());
    } on MissingPluginException {
      return;
    }
  }
}

class InMemorySecureTokenStore implements SecureTokenStore {
  String? _token;
  DateTime? _expiry;
  bool _enabled = false;
  String? email;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<DateTime?> readExpiry() async => _expiry;

  @override
  Future<bool> biometricsEnabled() async => _enabled;

  @override
  Future<void> saveToken(
    String token, {
    DateTime? expiresAt,
    String? email,
  }) async {
    _token = token;
    _expiry = expiresAt;
    this.email = email;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
    _expiry = null;
    email = null;
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async => _enabled = enabled;
}
