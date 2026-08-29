/// Tests for the 042 working-slice model extensions (DiChoice, EntityField,
/// identifier normalization).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U6: DiChoice resolves auto → mock fallback with recorded source
///   042-U7: EntityField exposes nullable flag + supported type set
///   042-U8: leading digit prefixes stripped from slug-derived identifiers
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  group('DiChoice (042-U6)', () {
    test(
      '042-U6: auto without detection resolves to mock with auto-fallback',
      () {
        final choice = DiChoice.auto().resolve(detectedBackend: null);
        expect(choice.backend, equals(BoneBackendKind.mock));
        expect(choice.source, equals(DiChoiceSource.autoFallback));
        expect(choice.wasRequested('auto'), isTrue);
      },
    );

    test('042-U6: auto with firebase detection resolves to firebase', () {
      final choice = DiChoice.auto().resolve(
        detectedBackend: BoneBackendKind.firebase,
      );
      expect(choice.backend, equals(BoneBackendKind.firebase));
      expect(choice.source, equals(DiChoiceSource.autoDetected));
    });

    test(
      '042-U6: explicit flag choice keeps flag source regardless of detection',
      () {
        final choice = DiChoice.fromFlag(
          'firebase',
        ).resolve(detectedBackend: BoneBackendKind.mock);
        expect(choice.backend, equals(BoneBackendKind.firebase));
        expect(choice.source, equals(DiChoiceSource.flag));
      },
    );

    test('DiChoice.fromFlag rejects unknown values', () {
      expect(() => DiChoice.fromFlag('redis'), throwsArgumentError);
    });
  });

  group('EntityField (042-U7)', () {
    test('042-U7: exposes nullable flag', () {
      const field = EntityField(name: 'email', type: 'String', nullable: true);
      expect(field.nullable, isTrue);
      const required = EntityField(name: 'id', type: 'String');
      expect(required.nullable, isFalse);
    });

    test('EntityField.isSupportedType accepts the documented type set', () {
      const supported = [
        'String',
        'int',
        'double',
        'num',
        'bool',
        'List<String>',
        'Map<String, dynamic>',
        'DateTime',
      ];
      for (final type in supported) {
        expect(
          EntityField.isSupportedType(type),
          isTrue,
          reason: '$type must be supported',
        );
      }
      expect(EntityField.isSupportedType('UIImage'), isFalse);
      expect(EntityField.isSupportedType('dynamic'), isFalse);
    });
  });

  group('slug identifier normalization (042-U8)', () {
    test(
      '042-U8: leading digit prefixes are stripped for Dart identifiers',
      () {
        expect(
          stripSlugPrefix('042-bone-working-slice'),
          equals('bone-working-slice'),
        );
        expect(stripSlugPrefix('sample-feature'), equals('sample-feature'));
        expect(stripSlugPrefix('007'), isEmpty);
      },
    );

    test('slugToPascalCase strips digits and PascalCases', () {
      expect(
        slugToPascalCase('042-bone-working-slice'),
        equals('BoneWorkingSlice'),
      );
      expect(slugToPascalCase('profile-feature'), equals('ProfileFeature'));
    });

    test('slugToSnakeCase strips digits and snake_cases', () {
      expect(
        slugToSnakeCase('042-bone-working-slice'),
        equals('bone_working_slice'),
      );
      expect(slugToSnakeCase('profile-feature'), equals('profile_feature'));
    });

    test('slugToDisplayName strips digits and title-cases with spaces', () {
      expect(
        slugToDisplayName('042-bone-working-slice'),
        equals('Bone Working Slice'),
      );
      expect(slugToDisplayName('profile-feature'), equals('Profile Feature'));
    });
  });
}
