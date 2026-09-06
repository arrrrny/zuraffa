// Spec 1115 — FeatureId, the typed feature identifier.
//
// Issue #1115: xray takes a raw `String` everywhere a feature travels —
// the same class of unvalidated-string bug spec 1098 removed from the
// contract. FeatureId is the typed wire value: parsed once, validated
// (kebab/numeric segment ids like `004-login-ui`), and compared by value.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_id.dart';

void main() {
  group('FeatureId', () {
    test('parse accepts a plain kebab-case id', () {
      expect(FeatureId.parse('login').value, 'login');
    });

    test('parse accepts the spec-1115 shape: numeric prefix + segments', () {
      expect(FeatureId.parse('004-login-ui').value, '004-login-ui');
    });

    test('parse trims surrounding whitespace', () {
      expect(FeatureId.parse('  login  ').value, 'login');
    });

    test('parse rejects empty', () {
      expect(() => FeatureId.parse(''), throwsArgumentError);
      expect(() => FeatureId.parse('   '), throwsArgumentError);
    });

    test('parse rejects spaces and path separators', () {
      expect(() => FeatureId.parse('log in'), throwsArgumentError);
      expect(() => FeatureId.parse('../etc'), throwsArgumentError);
      expect(() => FeatureId.parse('a/b'), throwsArgumentError);
    });

    test('parse rejects uppercase (ids are normalized kebab-case)', () {
      expect(() => FeatureId.parse('Login'), throwsArgumentError);
    });

    test('tryParse returns null instead of throwing', () {
      expect(FeatureId.tryParse('004-login-ui')?.value, '004-login-ui');
      expect(FeatureId.tryParse('not a feature'), isNull);
      expect(FeatureId.tryParse(''), isNull);
    });

    test('value equality: two ids with the same value are equal', () {
      expect(FeatureId.parse('login'), FeatureId.parse('login'));
      expect(
        FeatureId.parse('login').hashCode,
        FeatureId.parse('login').hashCode,
      );
      expect(FeatureId.parse('login'), isNot(FeatureId.parse('logout')));
    });

    test('toString is the id value', () {
      expect(FeatureId.parse('004-login-ui').toString(), '004-login-ui');
    });
  });
}
