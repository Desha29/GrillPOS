import 'package:flutter_test/flutter_test.dart';
import 'package:grill_pos/core/security/password_hasher.dart';

void main() {
  group('PasswordHasher', () {
    test('hashes and verifies without storing plaintext', () {
      final encoded = PasswordHasher.hash('strong password');

      expect(encoded, isNot(contains('strong password')));
      expect(PasswordHasher.isEncoded(encoded), isTrue);
      expect(PasswordHasher.verify('strong password', encoded), isTrue);
      expect(PasswordHasher.verify('wrong password', encoded), isFalse);
    });

    test('supports legacy plaintext during migration', () {
      expect(PasswordHasher.verify('legacy', 'legacy'), isTrue);
      expect(PasswordHasher.verify('wrong', 'legacy'), isFalse);
    });
  });
}
