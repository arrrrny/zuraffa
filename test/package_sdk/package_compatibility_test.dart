import 'package:test/test.dart';
import 'package:zuraffa/src/package/package_compatibility.dart';

void main() {
  group('PackageCompatibility.check (FR-015)', () {
    test('U10: same-major caret constraint → compatible', () {
      final r = PackageCompatibility.check(
        packageConstraint: '^6.0.0',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.compatible);
    });

    test('U10: exact version → compatible', () {
      final r = PackageCompatibility.check(
        packageConstraint: '6.1.0',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.compatible);
    });

    test('U10: range constraint → compatible when within same major', () {
      final r = PackageCompatibility.check(
        packageConstraint: '>=6.0.0 <7.0.0',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.compatible);
    });

    test(
      'U10: major mismatch (caret) → incompatible with both versions named',
      () {
        final r = PackageCompatibility.check(
          packageConstraint: '^7.0.0',
          appVersion: '6.1.0',
        );
        expect(r.status, PackageCompatibilityStatus.incompatible);
        expect(r.isCompatible, isFalse);
        expect(r.message, contains('^7.0.0'));
        expect(r.message, contains('6.1.0'));
      },
    );

    test('U10: major mismatch in the other direction → incompatible', () {
      final r = PackageCompatibility.check(
        packageConstraint: '^5.0.0',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.incompatible);
    });

    test('U10: short caret forms parse (^6.1)', () {
      final r = PackageCompatibility.check(
        packageConstraint: '^6.1',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.compatible);
    });

    test('U11: newer minor in same major → warning, not error', () {
      final r = PackageCompatibility.check(
        packageConstraint: '^6.2.0',
        appVersion: '6.1.0',
      );
      expect(r.status, PackageCompatibilityStatus.warning);
      expect(r.isCompatible, isTrue);
      expect(r.message, contains('6.2.0'));
    });

    test('U11: older minor in same major → compatible', () {
      final r = PackageCompatibility.check(
        packageConstraint: '^6.0.0',
        appVersion: '6.9.3',
      );
      expect(r.status, PackageCompatibilityStatus.compatible);
    });

    test(
      'edge: unparseable constraint → warning (never crashes, never silent-passes a mismatch)',
      () {
        final r = PackageCompatibility.check(
          packageConstraint: 'not-a-version',
          appVersion: '6.1.0',
        );
        expect(r.status, PackageCompatibilityStatus.warning);
        expect(r.isCompatible, isTrue);
      },
    );
  });
}
