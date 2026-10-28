import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/validators.dart';

void main() {
  group('Validators.fullName', () {
    test('rejects empty and too short names', () {
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('  '), isNotNull);
      expect(Validators.fullName('A'), isNotNull);
    });
    test('accepts a normal name', () {
      expect(Validators.fullName('Rahim Uddin'), isNull);
    });
  });

  group('Validators.email', () {
    test('rejects invalid emails', () {
      for (final bad in ['', 'abc', 'a@b', '@x.com', 'a b@x.com']) {
        expect(Validators.email(bad), isNotNull, reason: bad);
      }
    });
    test('accepts valid emails', () {
      expect(Validators.email('user@example.com'), isNull);
      expect(Validators.email(' first.last+tag@mail.co.uk '), isNull);
    });
  });

  group('Validators.phone', () {
    test('rejects bad numbers', () {
      for (final bad in ['', 'abc', '12345', '+88017', '0171234567890123456']) {
        expect(Validators.phone(bad), isNotNull, reason: bad);
      }
    });
    test('accepts numbers with + spaces and dashes', () {
      expect(Validators.phone('+880 1712-345678'), isNull);
      expect(Validators.phone('01712345678'), isNull);
    });
  });

  group('Validators.password', () {
    test('requires 8+ characters with a letter and a number', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('goodpass1'), isNull);
    });
    test('confirm password must match', () {
      expect(Validators.confirmPassword('', 'goodpass1'), isNotNull);
      expect(Validators.confirmPassword('different1', 'goodpass1'), isNotNull);
      expect(Validators.confirmPassword('goodpass1', 'goodpass1'), isNull);
    });
  });

  group('Validators.gender and terms', () {
    test('gender is required', () {
      expect(Validators.gender(null), isNotNull);
      expect(Validators.gender('Female'), isNull);
    });
    test('terms must be accepted', () {
      expect(Validators.terms(false), isNotNull);
      expect(Validators.terms(null), isNotNull);
      expect(Validators.terms(true), isNull);
    });
  });
}
