// Tests for the TddProfile model (spec 041-tdd-setup-plugin, U3-U5).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/tdd_profile.dart';

void main() {
  group('TddProfile', () {
    test('flutter profile has all five keys', () {
      const p = TddProfile.flutter;
      expect(p.runner, 'flutter_test');
      expect(p.single, contains('{file}'));
      expect(p.single, contains('{name}'));
      expect(p.file, contains('{file}'));
      expect(p.suite, isNotEmpty);
      expect(p.coverage, isNotEmpty);
    });

    test('resolveSingle substitutes both placeholders', () {
      const p = TddProfile.flutter;
      final resolved = p.resolveSingle(file: 'test/foo_test.dart', name: 'foo');
      expect(resolved, contains('test/foo_test.dart'));
      expect(resolved, contains('foo'));
      expect(resolved, isNot(contains('{file}')));
      expect(resolved, isNot(contains('{name}')));
    });

    test('resolveFile substitutes the file placeholder', () {
      const p = TddProfile.flutter;
      final resolved = p.resolveFile('test/foo_test.dart');
      expect(resolved, contains('test/foo_test.dart'));
      expect(resolved, isNot(contains('{file}')));
    });

    test('resolveSuite and resolveCoverage return the literal commands', () {
      const p = TddProfile.flutter;
      expect(p.resolveSuite(), equals('flutter test'));
      expect(p.resolveCoverage(), equals('flutter test --coverage'));
    });

    test('dart profile resolves single with -P filter', () {
      const p = TddProfile.dart;
      final resolved = p.resolveSingle(file: 'test/foo_test.dart', name: 'foo');
      expect(resolved, contains('--name "foo"'));
      expect(resolved, contains('test/foo_test.dart'));
    });
  });
}
