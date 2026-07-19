import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 password storage with legacy plaintext verification.
class PasswordHasher {
  PasswordHasher._();

  static const _algorithm = 'pbkdf2_sha256';
  static const _iterations = 100000;
  static final Random _random = Random.secure();

  static String hash(String password) {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Password is required.');
    }
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final derived = _derive(password, salt, _iterations);
    return '$_algorithm\$$_iterations\$${base64Url.encode(salt)}\$'
        '${base64Url.encode(derived)}';
  }

  static bool verify(String password, String storedValue) {
    if (!isEncoded(storedValue)) {
      return _constantTimeEquals(
          utf8.encode(password), utf8.encode(storedValue));
    }
    final parts = storedValue.split(r'$');
    if (parts.length != 4) return false;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return false;
    try {
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      return _constantTimeEquals(
        _derive(password, salt, iterations, length: expected.length),
        expected,
      );
    } on FormatException {
      return false;
    }
  }

  static bool isEncoded(String value) => value.startsWith('$_algorithm\$');

  static List<int> _derive(
    String password,
    List<int> salt,
    int iterations, {
    int length = 32,
  }) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final result = <int>[];
    var blockIndex = 1;
    while (result.length < length) {
      final block = [
        ...salt,
        (blockIndex >> 24) & 0xff,
        (blockIndex >> 16) & 0xff,
        (blockIndex >> 8) & 0xff,
        blockIndex & 0xff,
      ];
      var u = hmac.convert(block).bytes;
      final output = List<int>.from(u);
      for (var iteration = 1; iteration < iterations; iteration++) {
        u = hmac.convert(u).bytes;
        for (var index = 0; index < output.length; index++) {
          output[index] ^= u[index];
        }
      }
      result.addAll(output);
      blockIndex++;
    }
    return result.sublist(0, length);
  }

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final count = max(left.length, right.length);
    for (var index = 0; index < count; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      difference |= a ^ b;
    }
    return difference == 0;
  }
}
