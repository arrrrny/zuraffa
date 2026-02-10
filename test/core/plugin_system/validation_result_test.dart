import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_lifecycle.dart';

void main() {
  group('ValidationResult', () {
    test('success merges with success', () {
      final a = ValidationResult.success('ok');
      final b = ValidationResult.success('ok2');
      final merged = a.merge(b);

      expect(merged.isValid, isTrue);
      expect(merged.reasons, isEmpty);
      expect(merged.message, equals('ok'));
    });

    test('failure merges reasons', () {
      final a = ValidationResult.failure(['a']);
      final b = ValidationResult.failure(['b', 'c']);
      final merged = a.merge(b);

      expect(merged.isValid, isFalse);
      expect(merged.reasons, equals(['a', 'b', 'c']));
    });
  });
}
