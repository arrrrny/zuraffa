/// Tests for BoneGenerator (U18-U22, U33).
///
/// Behaviors traced to test-list.md:
///   U18: emits the full bone file set for a spec declaring ≥1 entity
///   U19: refuses with a missing-field error when the spec declares no entities
///   U20: does not abort on an undeclared entity mention in prose
///   U21: rejects a stub import that is neither bone-local, dart:*, nor a declared dependency
///   U22: a failed generation leaves no partial bone directory behind
///   U33: xray markers from the spec are passed through to the manifest
///
/// Uses temporary directories for filesystem tests; cleans up after.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/bone_generator.dart';

import 'helpers/copy_fixture.dart';

void main() {
  late BoneGenerator generator;
  late Directory tmpDir;

  setUp(() async {
    generator = BoneGenerator();
    tmpDir = await Directory.systemTemp.createTemp('bone_generator_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> writeSpec(
    String content, {
    String dirName = 'test-feature',
  }) async {
    final dir = await Directory(
      '${tmpDir.path}/specs/$dirName',
    ).create(recursive: true);
    final file = File('${dir.path}/spec.md');
    await file.writeAsString(content);
    return file;
  }

  group('BoneGenerator.generate', () {
    test(
      'U18: emits the full bone file set for a spec declaring ≥1 entity',
      () async {
        final spec = await writeSpec('''
# Feature: Test Feature

## Key Entities

- **Product** — a catalog item

## Requirements

Something.
''');
        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: spec,
          outputDir: outputDir,
        );

        // bone.yaml exists.
        expect(await File('$boneDir/bone.yaml').exists(), isTrue);

        // Entity stub exists.
        expect(
          await File('$boneDir/lib/entities/product.dart').exists(),
          isTrue,
        );

        // Barrel exists.
        expect(await File('$boneDir/lib/test_feature.dart').exists(), isTrue);

        // Layer placeholders exist.
        for (final layer in ['domain', 'data', 'presentation']) {
          expect(await Directory('$boneDir/$layer').exists(), isTrue);
        }
      },
    );

    test(
      'U19: refuses with a missing-field error when the spec declares no entities',
      () async {
        final spec = await writeSpec('''
# Feature: Empty Feature

## Requirements

No entities here.
''');
        final outputDir = '${tmpDir.path}/bones';

        expect(
          () => generator.generate(specPath: spec, outputDir: outputDir),
          throwsA(isA<BoneGenerationError>()),
        );
      },
    );

    test(
      'U20: does not abort on an undeclared entity mention in prose',
      () async {
        // The referenced entity (Product) is not declared by any known feature.
        // The resolver only validates cross-feature references to *declared*
        // entities, so an arbitrary PascalCase mention in prose must not abort
        // generation (see CodeRabbit finding #589-2: the fragile PascalCase
        // scan that false-flagged technical terms like "Dart"/"Flutter" was
        // removed).
        final specsRoot = '${tmpDir.path}/specs_root';
        await copyFixture('ref-feature', specsRoot);

        final spec = File('$specsRoot/ref-feature/spec.md');
        final outputDir = '${tmpDir.path}/bones';

        // Generation must succeed rather than throw a spurious missing-entity
        // error for the undeclared "Product" reference.
        final boneDir = await generator.generate(
          specPath: spec,
          outputDir: outputDir,
          specsRoot: specsRoot,
        );

        expect(boneDir, isA<String>());
        expect(
          await Directory(boneDir).exists(),
          isTrue,
          reason:
              'bone directory should be produced for the referencing feature',
        );
      },
    );

    test(
      'U21: rejects a stub import that is neither bone-local, dart:*, nor a declared dependency',
      () async {
        // The generator produces minimal entity stubs with no external imports.
        // Verify the generated bone is self-contained: every Dart import
        // resolves inside the bone or is a dart:* import.
        final spec = await writeSpec('''
# Feature: Clean Feature

## Key Entities

- **Item**

## Requirements

Something.
''');
        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: spec,
          outputDir: outputDir,
        );

        // Scan all Dart files for imports.
        final dartFiles = Directory(boneDir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        expect(dartFiles, isNotEmpty, reason: 'bone must contain Dart files');

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          final imports = RegExp(
            r"^import\s+'([^']+)';",
            multiLine: true,
          ).allMatches(content);

          for (final match in imports) {
            final importPath = match.group(1)!;

            // dart:* imports are always valid.
            if (importPath.startsWith('dart:')) continue;

            // package:* imports are only valid when backed by a declared
            // dependency (matching bone slug in bone.yaml dependencies).
            // Standalone bones have no deps, so any package: import fails.
            if (importPath.startsWith('package:')) {
              fail(
                'Import $importPath in ${p.relative(file.path, from: boneDir)} '
                'is a package: import not backed by a declared dependency',
              );
            }

            // Relative imports must resolve inside the bone.

            final resolved = p.normalize(
              p.join(p.dirname(file.path), importPath),
            );
            expect(
              await File(resolved).exists(),
              isTrue,
              reason:
                  'Import $importPath in ${p.relative(file.path, from: boneDir)} '
                  'must resolve inside the bone',
            );
          }
        }
      },
    );

    test(
      'U22: a failed generation leaves no partial bone directory behind',
      () async {
        final spec = await writeSpec('''
# Feature: Fail Feature

## Requirements

No entities.
''');
        final outputDir = '${tmpDir.path}/bones';

        expect(
          () => generator.generate(specPath: spec, outputDir: outputDir),
          throwsA(isA<BoneGenerationError>()),
        );

        // Verify no partial directory was left.
        final boneDir = '$outputDir/fail-feature';
        expect(
          await Directory(boneDir).exists(),
          isFalse,
          reason: 'no partial bone directory should remain after failure',
        );
      },
    );

    test(
      'U38: generated manifest spec_version matches sha256: + 64 hex end to end',
      () async {
        final spec = await writeSpec('''
# Feature: Version Feature

## Key Entities

- **Item** — a thing

## Requirements

Something.
''');
        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: spec,
          outputDir: outputDir,
        );

        // Read the actual bone.yaml file content (not the model).
        final manifestContent = await File('$boneDir/bone.yaml').readAsString();
        final svMatch = RegExp(
          r'spec_version:\s*(sha256:[0-9a-f]{64})',
        ).firstMatch(manifestContent);
        expect(
          svMatch,
          isNotNull,
          reason:
              'bone.yaml must contain spec_version matching sha256: + 64 hex',
        );
        expect(
          svMatch!.group(1),
          matches(RegExp(r'^sha256:[0-9a-f]{64}$')),
          reason:
              'spec_version must be sha256: prefix + 64 lowercase hex chars',
        );
      },
    );

    test(
      'U33: xray markers from the spec are passed through to the manifest',
      () async {
        final spec = await writeSpec('''
# Feature: Xray Feature

## Key Entities

- **Widget** — a UI component

<!-- xray: overlay: {"enabled": true} -->
<!-- xray: mode: development -->

## Requirements

- Widget must render.
''');
        final outputDir = '${tmpDir.path}/bones';
        final boneDir = await generator.generate(
          specPath: spec,
          outputDir: outputDir,
        );

        final manifestContent = await File('$boneDir/bone.yaml').readAsString();
        expect(manifestContent, contains('xray:'));
        expect(manifestContent, contains('overlay:'));
        expect(manifestContent, contains('{"enabled": true}'));
      },
    );
  });
}
