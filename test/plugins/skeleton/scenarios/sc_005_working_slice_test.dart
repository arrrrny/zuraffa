@Tags(['slow'])

/// SC-005 acceptance test (feature 042): the Bone Working Slice end to end.
///
/// Behaviors traced to specs/042-bone-working-slice/tdd/test-list.md:
///   A1..A28 — see the per-test annotations below.
///
/// This scenario goes beyond content assertions: it executes the generated
/// bone's own self-contained tests with the real Dart toolchain
/// (`dart <file>`), analyzes the pure-Dart core with `dart analyze` inside a scratch
/// package (zero external dependencies), and unpacks exported artifacts.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/bone_command.dart';

import '../helpers/capture_output.dart';
import '../helpers/copy_fixture.dart';

const _profileSpec = '''
# Feature: Profile Feature

## Key Entities

- **User** — the profile owner
  - id: String
  - displayName: String
  - email: String?
  - age: int
  - rating: double
  - isActive: bool
  - tags: List<String>
  - meta: Map<String, dynamic>
  - createdAt: DateTime
- **Post** — content authored by the user
  - id: String
  - title: String

## Requirements

- Users own their profile
- Posts belong to a User
''';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sc_005_slice_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<String> generateBone({
    required String slug,
    String spec = _profileSpec,
    List<String> extraFlags = const [],
    String? specsRoot,
    String outputSuffix = 'bones',
  }) async {
    final specs = specsRoot ?? '${tmpDir.path}/specs';
    await Directory('$specs/$slug').create(recursive: true);
    await File('$specs/$slug/spec.md').writeAsString(spec);

    final outputDir = '${tmpDir.path}/$outputSuffix';
    final command = BoneCommand(specsRoot: specs);
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

    final out = await captureOutput(
      () => runner.run([
        'bone',
        'generate',
        slug,
        '--spec',
        '$specs/$slug/spec.md',
        '--output',
        outputDir,
        ...extraFlags,
      ]),
    );
    return out;
  }

  ProcessResult runDart(List<String> args, {String? cwd}) =>
      Process.runSync(Platform.resolvedExecutable, args, workingDirectory: cwd);

  /// Copies the pure-Dart core of a bone into a scratch package and runs
  /// `dart analyze` there (SC-002). [skip] filters flutter-only files.
  Future<ProcessResult> analyzeCore(String boneDir) async {
    final scratch = await Directory.systemTemp.createTemp('sc005_analyze_');
    try {
      for (final dir in ['entities', 'domain', 'data', 'di']) {
        final src = Directory('$boneDir/$dir');
        if (!await src.exists()) continue;
        await _copyTree(src, '${scratch.path}/${p.basename(src.path)}');
      }
      final testSrc = Directory('$boneDir/test');
      if (await testSrc.exists()) {
        await _copyTree(
          testSrc,
          '${scratch.path}/test',
          skipName: '_page_test.dart',
        );
      }
      await File(
        '${scratch.path}/pubspec.yaml',
      ).writeAsString('name: bone_core_check\nenvironment:\n  sdk: ^3.11.0\n');
      final pubGet = runDart(['pub', 'get', '--offline'], cwd: scratch.path);
      expect(
        pubGet.exitCode,
        0,
        reason: 'scratch pub get failed: ${pubGet.stderr}',
      );
      return runDart(['analyze', '--no-fatal-warnings'], cwd: scratch.path);
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  group('SC-005: bone working slice', () {
    test('A1: entities have real fields, fromJson, toJson, copyWith, validate '
        '— no empty class stubs', () async {
      await generateBone(slug: 'profile-feature');
      final entity = await File(
        '${tmpDir.path}/bones/profile-feature/entities/user.dart',
      ).readAsString();
      expect(entity, contains('final String id;'));
      expect(entity, contains('final String? email;'));
      expect(entity, contains('factory User.fromJson'));
      expect(entity, contains('toJson()'));
      expect(entity, contains('User copyWith('));
      expect(entity, contains('validateUser(User instance)'));
      expect(entity, isNot(contains('class User {}')));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A2: abstract repository + data implementation + datasource interface '
        'exist per entity', () async {
      await generateBone(slug: 'profile-feature');
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      expect(
        await File(
          '$boneDir/domain/repositories/user_repository.dart',
        ).exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/data/datasources/user_datasource.dart').exists(),
        isTrue,
      );
      expect(
        await File(
          '$boneDir/data/repositories/data_user_repository.dart',
        ).exists(),
        isTrue,
      );
      final repo = await File(
        '$boneDir/domain/repositories/user_repository.dart',
      ).readAsString();
      expect(repo, contains('abstract class UserRepository'));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A3: CRUD use cases receive the repository via DI', () async {
      await generateBone(slug: 'profile-feature');
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      for (final op in ['get', 'create', 'update', 'delete']) {
        final file = File('$boneDir/domain/usecases/${op}_user_usecase.dart');
        expect(await file.exists(), isTrue, reason: '$op use case missing');
        final src = await file.readAsString();
        expect(src, contains('this.repository'));
        expect(src, contains('=> repository.'));
      }
      final injection = await File('$boneDir/di/injection.dart').readAsString();
      expect(injection, contains('GetUserUseCase get getUser'));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'A4: field-less entities still emit real fromJson/validate shape',
      () async {
        await generateBone(
          slug: 'legacy-feature',
          spec:
              '# Feature: Legacy\n\n## Key Entities\n\n- **Product** — item\n'
              '\n## Requirements\n\n- Something\n',
          outputSuffix: 'bones_legacy',
        );
        final entity = await File(
          '${tmpDir.path}/bones_legacy/legacy-feature/entities/product.dart',
        ).readAsString();
        expect(entity, contains('factory Product.fromJson'));
        expect(entity, contains('validateProduct(Product instance)'));
        expect(entity, isNot(contains('class Product {}')));
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('A5: --di mock wires mock default and records di: mock', () async {
      await generateBone(slug: 'profile-feature', extraFlags: ['--di', 'mock']);
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      final manifest = await File('$boneDir/bone.yaml').readAsString();
      expect(manifest, contains('di: mock'));
      expect(manifest, contains('di_source:'));
      final injection = await File('$boneDir/di/injection.dart').readAsString();
      expect(injection, contains('backend ?? BoneBackend.mock'));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A6: --di firebase wires firebase default + credentials', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--di', 'firebase'],
      );
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      final manifest = await File('$boneDir/bone.yaml').readAsString();
      expect(manifest, contains('di: firebase'));
      final injection = await File('$boneDir/di/injection.dart').readAsString();
      expect(injection, contains('backend ?? BoneBackend.firebase'));
      final firebase = await File(
        '$boneDir/data/datasources/user_firebase.dart',
      ).readAsString();
      expect(firebase, contains('firestore.googleapis.com'));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'A9: invalid --di prints a usage error and generates nothing',
      () async {
        final out = await generateBone(
          slug: 'profile-feature',
          extraFlags: ['--di', 'redis'],
          outputSuffix: 'bones_invalid',
        );
        expect(out, contains('--di'));
        expect(exitCode, isNot(0));
        expect(
          await Directory(
            '${tmpDir.path}/bones_invalid/profile-feature',
          ).exists(),
          isFalse,
        );
        exitCode = 0;
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('A10: --flutter emits minimal pubspec + runnable main.dart', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--flutter'],
        outputSuffix: 'bones_flutter',
      );
      final boneDir = '${tmpDir.path}/bones_flutter/profile-feature';
      final pubspec = await File('$boneDir/pubspec.yaml').readAsString();
      expect(pubspec, contains('environment:'));
      expect(pubspec, contains('sdk: flutter'));
      final main = await File('$boneDir/lib/main.dart').readAsString();
      expect(main, contains('void main()'));
      expect(main, contains('runApp('));
      expect(main, contains('Services.create()'));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A11/A13: --flutter emits presentation page + widget test', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--flutter'],
        outputSuffix: 'bones_flutter',
      );
      final boneDir = '${tmpDir.path}/bones_flutter/profile-feature';
      final page = await File(
        '$boneDir/presentation/profile_feature_page.dart',
      ).readAsString();
      expect(page, contains('class ProfileFeaturePage'));
      expect(page, contains('Scaffold'));
      expect(page, contains('ProfileFeatureServices'));
      final widgetTest = await File(
        '$boneDir/test/profile_feature_page_test.dart',
      ).readAsString();
      expect(
        widgetTest,
        contains("import 'package:flutter_test/flutter_test.dart'"),
      );
      expect(widgetTest, contains('testWidgets('));
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'A12: without --flutter no pubspec, main.dart, or widget page exists',
      () async {
        await generateBone(slug: 'profile-feature');
        final boneDir = '${tmpDir.path}/bones/profile-feature';
        expect(await File('$boneDir/pubspec.yaml').exists(), isFalse);
        expect(await File('$boneDir/lib/main.dart').exists(), isFalse);
        expect(
          await File(
            '$boneDir/presentation/profile_feature_page.dart',
          ).exists(),
          isFalse,
        );
        expect(await Directory('$boneDir/lib').exists(), isFalse);
        expect(await Directory('$boneDir/presentation').exists(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'A14/A15/A16/A17: dependency graph drives minimal inclusion',
      () async {
        // feature-c → feature-b (Order) → feature-a (Product); standalone
        // (Widget) is unrelated.
        final specsRoot = '${tmpDir.path}/dep_specs';
        for (final fixture in [
          'feature-a',
          'feature-b',
          'feature-c',
          'standalone',
        ]) {
          await copyFixture(fixture, specsRoot);
        }

        // Default: declare only (A17).
        final declared = await generateBone(
          slug: 'feature-c',
          spec: await File('$specsRoot/feature-c/spec.md').readAsString(),
          specsRoot: specsRoot,
          outputSuffix: 'bones_declared',
        );
        expect(declared, isNotEmpty);
        expect(
          await File(
            '${tmpDir.path}/bones_declared/feature-c/entities/order.dart',
          ).exists(),
          isFalse,
          reason: 'default generation must not inline dep files',
        );
        final manifest = await File(
          '${tmpDir.path}/bones_declared/feature-c/bone.yaml',
        ).readAsString();
        expect(manifest, contains('bone: feature-b'));

        // --include-deps: minimal transitive closure inlined (A14/A15).
        await generateBone(
          slug: 'feature-c',
          spec: await File('$specsRoot/feature-c/spec.md').readAsString(),
          specsRoot: specsRoot,
          extraFlags: ['--include-deps'],
          outputSuffix: 'bones_included',
        );
        final included = '${tmpDir.path}/bones_included/feature-c';
        expect(await File('$included/entities/review.dart').exists(), isTrue);
        expect(await File('$included/entities/order.dart').exists(), isTrue);
        expect(await File('$included/entities/product.dart').exists(), isTrue);
        // Unrelated feature's entity absent (A16).
        expect(await File('$included/entities/widget.dart').exists(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('A18: dependency cycles are refused with no partial output', () async {
      final specsRoot = '${tmpDir.path}/cycle_specs';
      for (final fixture in ['cycle-a', 'cycle-b']) {
        await copyFixture(fixture, specsRoot);
      }
      final out = await generateBone(
        slug: 'cycle-a',
        spec: await File('$specsRoot/cycle-a/spec.md').readAsString(),
        specsRoot: specsRoot,
        extraFlags: ['--include-deps'],
        outputSuffix: 'bones_cycle',
      );
      expect(out.toLowerCase(), contains('error'));
      expect(
        await Directory('${tmpDir.path}/bones_cycle/cycle-a').exists(),
        isFalse,
        reason: 'cycle refusal must leave no partial bone',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A19: --export produces <feature>-<di>.tar.gz unpacking to the bone '
        'tree', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--di', 'mock', '--export'],
        outputSuffix: 'bones_export',
      );
      final artifact = File(
        '${tmpDir.path}/bones_export/profile-feature-mock.tar.gz',
      );
      expect(await artifact.exists(), isTrue);

      final boneDir = Directory('${tmpDir.path}/bones_export/profile-feature');
      final boneFiles = boneDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: boneDir.path))
          .toSet();

      final archive = TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(await artifact.readAsBytes()),
      );
      final archived = archive.files
          .where((f) => !f.isFile ? false : true)
          .map((f) => f.name)
          .toSet();

      expect(
        archived,
        equals(boneFiles),
        reason: 'artifact must contain exactly the bone file tree',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'A20: two features export into the same bones dir without conflicts',
      () async {
        final specsRoot = '${tmpDir.path}/multi_specs';
        await copyFixture('profile-feature', specsRoot);
        await copyFixture('standalone', specsRoot);

        await generateBone(
          slug: 'profile-feature',
          spec: await File('$specsRoot/profile-feature/spec.md').readAsString(),
          specsRoot: specsRoot,
          extraFlags: ['--di', 'mock', '--export'],
          outputSuffix: 'bones_multi',
        );
        await generateBone(
          slug: 'standalone',
          spec: await File('$specsRoot/standalone/spec.md').readAsString(),
          specsRoot: specsRoot,
          extraFlags: ['--di', 'mock', '--export'],
          outputSuffix: 'bones_multi',
        );

        expect(
          await File(
            '${tmpDir.path}/bones_multi/profile-feature-mock.tar.gz',
          ).exists(),
          isTrue,
        );
        expect(
          await File(
            '${tmpDir.path}/bones_multi/standalone-mock.tar.gz',
          ).exists(),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'A21: failed generation leaves no artifact and no partial bone',
      () async {
        final out = await generateBone(
          slug: 'empty-feature',
          spec: '# Feature: Empty\n\n## Requirements\n\nNo entities.\n',
          extraFlags: ['--di', 'mock', '--export'],
          outputSuffix: 'bones_failed',
        );
        expect(out.toLowerCase(), contains('error'));
        expect(
          await Directory('${tmpDir.path}/bones_failed/empty-feature').exists(),
          isFalse,
        );
        final bonesFailed = Directory('${tmpDir.path}/bones_failed');
        final artifacts = await bonesFailed.exists()
            ? bonesFailed
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.tar.gz'))
                  .toList()
            : const <File>[];
        expect(
          artifacts,
          isEmpty,
          reason: 'no artifact may remain after a failed generation',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('A22/A24: generated tests pass with `dart run` — no pub get, no '
        'network; firebase-without-credentials is a clear error', () async {
      await generateBone(slug: 'profile-feature', extraFlags: ['--di', 'mock']);
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      for (final testFile in [
        'user_test.dart',
        'post_test.dart',
        'di_test.dart',
      ]) {
        final result = runDart(['$boneDir/test/$testFile']);
        expect(
          result.exitCode,
          0,
          reason:
              '$testFile must pass standalone; stdout: ${result.stdout}\n'
              'stderr: ${result.stderr}',
        );
      }
      // The di_test.dart exercises the firebase-without-credentials guard
      // (A24) alongside the mock wiring.
      final diTest = await File('$boneDir/test/di_test.dart').readAsString();
      expect(diTest, contains('BoneBackend.firebase'));
      expect(diTest, contains('StateError'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A23: exported artifact is < 50KB', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--di', 'mock', '--export'],
        outputSuffix: 'bones_size',
      );
      final artifact = File(
        '${tmpDir.path}/bones_size/profile-feature-mock.tar.gz',
      );
      final size = await artifact.length();
      expect(
        size,
        lessThan(50 * 1024),
        reason: 'artifact must be < 50KB, was $size bytes',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test(
      'A25: the pure-Dart core analyzes with zero errors (SC-002)',
      () async {
        await generateBone(slug: 'profile-feature');
        final result = await analyzeCore(
          '${tmpDir.path}/bones/profile-feature',
        );
        expect(
          result.exitCode,
          0,
          reason:
              'dart analyze must report zero errors on the generated core;\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'A26: bone validate passes on a flutter bone with flutter_test import',
      () async {
        await generateBone(
          slug: 'profile-feature',
          extraFlags: ['--flutter'],
          outputSuffix: 'bones_validate',
        );
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
        final out = await captureOutput(
          () => runner.run([
            'bone',
            'validate',
            'profile-feature',
            '--bones-dir',
            '${tmpDir.path}/bones_validate',
          ]),
        );
        expect(out, contains('OK: bone "profile-feature" is valid.'));
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('A27: no README placeholders or empty classes anywhere', () async {
      await generateBone(
        slug: 'profile-feature',
        extraFlags: ['--flutter'],
        outputSuffix: 'bones_content',
      );
      final files = Directory(
        '${tmpDir.path}/bones_content/profile-feature',
      ).listSync(recursive: true).whereType<File>().toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        expect(p.basename(file.path), isNot(equals('README.md')));
        final content = file.readAsStringSync();
        expect(
          content.contains('Placeholder for the'),
          isFalse,
          reason: '${file.path} must not contain placeholder text',
        );
        expect(
          content.contains('TODO'),
          isFalse,
          reason: '${file.path} must not contain TODO markers',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('A28: regenerating replaces the bone atomically', () async {
      await generateBone(slug: 'profile-feature');
      final boneDir = '${tmpDir.path}/bones/profile-feature';
      final stale = File('$boneDir/STALE.txt');
      await stale.writeAsString('stale');
      await generateBone(slug: 'profile-feature');
      expect(
        await stale.exists(),
        isFalse,
        reason: 'regeneration must not merge into the old bone',
      );
      expect(await File('$boneDir/bone.yaml').exists(), isTrue);
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

Future<void> _copyTree(Directory src, String dst, {String? skipName}) async {
  await Directory(dst).create(recursive: true);
  for (final entity in src.listSync()) {
    if (entity is Directory) {
      await _copyTree(
        entity,
        '$dst/${p.basename(entity.path)}',
        skipName: skipName,
      );
    } else if (entity is File) {
      if (skipName != null && entity.path.endsWith(skipName)) continue;
      await File(
        '$dst/${p.basename(entity.path)}',
      ).writeAsBytes(await entity.readAsBytes());
    }
  }
}
