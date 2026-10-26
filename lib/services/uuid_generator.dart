import 'dart:math';

class UuidGenerator {
  static final Random _secureRandom = Random.secure();

  /// Generates an RFC 4122 compliant version 4 UUID.
  static String v4({Random? random}) {
    final r = random ?? _secureRandom;
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));

    // Version 4 (0100xxxx -> 0x40 | (b & 0x0f))
    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    // Variant RFC 4122 (10xxxxxx -> 0x80 | (b & 0x3f))
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
