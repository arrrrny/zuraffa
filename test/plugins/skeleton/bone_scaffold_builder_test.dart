/// Tests for BoneScaffoldBuilder (042 working slice).
///
/// The 020-era behaviors (empty entity stubs, layer README placeholders,
/// TODO-only test stubs, barrel file) were retired by feature 042: issue #592
/// calls that output "barely more useful than the spec itself". The scaffold
/// now writes the working slice: real entities, domain, data, DI, tests — and
/// presentation/pubspec/main only in --flutter mode.
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   042 (FR-015): no README placeholders, no TODO-only test stubs
///   042 (FR-001..006, FR-008, FR-012): full working-slice file set
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/bone_scaffold_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('scaffold_builder_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Bone buildBone({bool flutter = false, List<EntityStub> inlined = const []}) {
    return Bone(
      featureSlug: 'profile-feature',
      featureName: 'ProfileFeature',
      rootDir: '${tmpDir.path}/profile-feature',
      manifest: BoneManifest(
        version: 1,
        feature: 'profile-feature',
        generatedAt: '2026-08-29T12:00:00.000Z',
        specVersion: 'sha256:${'a' * 64}',
        entities: const ['User'],
        dependencies: const [],
        layers: const ['domain', 'data', 'presentation'],
        diChoice: DiChoice.fromFlag('mock').resolve(),
        flutter: flutter,
      ),
      entityStubs: const [
        EntityStub(
          name: 'User',
          fields: [
            EntityField(name: 'id', type: 'String'),
            EntityField(name: 'displayName', type: 'String'),
          ],
          sourcePath: 'entities/user.dart',
        ),
      ],
      inlinedEntities: inlined,
      layers: const [
        LayerPlaceholder(layer: 'domain', path: 'domain/'),
        LayerPlaceholder(layer: 'data', path: 'data/'),
        LayerPlaceholder(layer: 'presentation', path: 'presentation/'),
      ],
    );
  }

  group('BoneScaffoldBuilder.build (042 working slice)', () {
    test('writes the library working slice (no flutter files)', () async {
      final bone = buildBone();
      final builder = BoneScaffoldBuilder();
      final boneDir = '${tmpDir.path}/profile-feature';

      await builder.build(bone, boneDir);

      // Core slice.
      expect(await File('$boneDir/bone.yaml').exists(), isTrue);
      expect(await File('$boneDir/entities/user.dart').exists(), isTrue);
      expect(
        await File(
          '$boneDir/domain/repositories/user_repository.dart',
        ).exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/domain/usecases/get_user_usecase.dart').exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/data/datasources/user_datasource.dart').exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/data/datasources/user_mock.dart').exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/data/datasources/user_firebase.dart').exists(),
        isTrue,
      );
      expect(
        await File(
          '$boneDir/data/repositories/data_user_repository.dart',
        ).exists(),
        isTrue,
      );
      expect(await File('$boneDir/di/injection.dart').exists(), isTrue);
      expect(await File('$boneDir/test/user_test.dart').exists(), isTrue);
      expect(await File('$boneDir/test/di_test.dart').exists(), isTrue);

      // Library mode: no flutter-only files.
      expect(await File('$boneDir/pubspec.yaml').exists(), isFalse);
      expect(await File('$boneDir/lib/main.dart').exists(), isFalse);
      expect(
        await File('$boneDir/presentation/profile_feature_page.dart').exists(),
        isFalse,
      );
    });

    test('flutter mode writes pubspec, main, page, and widget test', () async {
      final bone = buildBone(flutter: true);
      final builder = BoneScaffoldBuilder();
      final boneDir = '${tmpDir.path}/profile-feature-fl';

      await builder.build(bone, boneDir);

      expect(await File('$boneDir/pubspec.yaml').exists(), isTrue);
      expect(await File('$boneDir/lib/main.dart').exists(), isTrue);
      expect(
        await File('$boneDir/presentation/profile_feature_page.dart').exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/test/profile_feature_page_test.dart').exists(),
        isTrue,
      );
    });

    test(
      'FR-015: no README placeholders, no TODO-only test stubs anywhere',
      () async {
        final bone = buildBone(flutter: true);
        final builder = BoneScaffoldBuilder();
        final boneDir = '${tmpDir.path}/profile-feature-nph';

        await builder.build(bone, boneDir);

        final files = Directory(
          boneDir,
        ).listSync(recursive: true).whereType<File>().toList();
        expect(files, isNotEmpty);
        for (final file in files) {
          expect(
            file.path.endsWith('README.md'),
            isFalse,
            reason: '${file.path} must not be a README placeholder',
          );
          final content = file.readAsStringSync();
          if (file.path.endsWith('_test.dart')) {
            expect(
              content.contains('TODO'),
              isFalse,
              reason: '${file.path} must not be a TODO-only stub',
            );
            expect(
              content.contains(' main()'),
              isTrue,
              reason: '${file.path} must be a real runnable test',
            );
          }
        }
      },
    );

    test('inlined dependency entities are written into entities/', () async {
      final bone = buildBone(
        inlined: const [
          EntityStub(
            name: 'Account',
            fields: [EntityField(name: 'accountId', type: 'String')],
            sourcePath: 'entities/account.dart',
          ),
        ],
      );
      final builder = BoneScaffoldBuilder();
      final boneDir = '${tmpDir.path}/profile-feature-deps';

      await builder.build(bone, boneDir);

      expect(await File('$boneDir/entities/account.dart').exists(), isTrue);
    });
  });
}
