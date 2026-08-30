/// Tests for InjectionBuilder (042 working slice).
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042-U25: container default backend follows DiChoice
///   042-U26: runtime backend override selects the other datasource
///   042-U27: all entities registered with getters
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/slice/injection_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  const userFields = [
    EntityField(name: 'id', type: 'String'),
    EntityField(name: 'displayName', type: 'String'),
  ];

  group('InjectionBuilder (042)', () {
    final builder = InjectionBuilder();

    test('042-U25: container default backend follows the resolved DiChoice '
        '(mock)', () {
      final choice = DiChoice.auto().resolve(detectedBackend: null);
      final source = builder.build(
        featureSlug: 'profile-feature',
        entities: const [('User', userFields), ('Post', [])],
        diChoice: choice,
      );
      expect(source, contains('enum BoneBackend'));
      expect(source, contains('BoneBackend.mock'));
      // Default baked from the resolved choice.
      expect(source, contains('backend ?? BoneBackend.mock'));
      expect(source, contains('class ProfileFeatureServices'));
    });

    test('042-U25: firebase choice bakes a firebase default', () {
      final choice = DiChoice.fromFlag('firebase').resolve();
      final source = builder.build(
        featureSlug: 'profile-feature',
        entities: const [('User', userFields)],
        diChoice: choice,
      );
      expect(source, contains('backend ?? BoneBackend.firebase'));
    });

    test(
      '042-U26: runtime backend override + credential guard for firebase',
      () {
        final choice = DiChoice.fromFlag('mock').resolve();
        final source = builder.build(
          featureSlug: 'profile-feature',
          entities: const [('User', userFields)],
          diChoice: choice,
        );
        // create() accepts a runtime override and a FirebaseConfig.
        expect(source, contains('BoneBackend? backend'));
        expect(source, contains('FirebaseConfig? firebaseConfig'));
        // Selecting firebase without credentials is a StateError.
        expect(source, contains('StateError'));
        expect(source, contains('UserMockDataSource'));
        expect(source, contains('UserFirebaseDataSource'));
      },
    );

    test(
      '042-U27: every entity gets a repository getter + usecase getters',
      () {
        final choice = DiChoice.fromFlag('mock').resolve();
        final source = builder.build(
          featureSlug: 'profile-feature',
          entities: const [('User', userFields), ('Post', [])],
          diChoice: choice,
        );
        expect(source, contains('UserRepository get userRepository'));
        expect(source, contains('PostRepository get postRepository'));
        expect(source, contains('GetUserUseCase get getUser'));
        expect(source, contains('UpdateUserUseCase get updateUser'));
        expect(source, contains('CreatePostUseCase get createPost'));
        expect(source, contains('DeleteUserUseCase get deleteUser'));
        // Self-contained: dart:* and relative imports only.
        final imports = RegExp(
          r"^import\s+'([^']+)';",
          multiLine: true,
        ).allMatches(source).map((m) => m.group(1)!);
        expect(imports, isNotEmpty);
        for (final import in imports) {
          expect(
            import.startsWith('dart:') || import.startsWith('../'),
            isTrue,
            reason: 'injection must stay self-contained, found "$import"',
          );
        }
      },
    );
  });
}
