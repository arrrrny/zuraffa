/// SC-001 acceptance test: drive `zfa bone generate` end to end and assert
/// the bone's manifest, entity stubs, layer placeholders, and self-containment.
///
/// Behaviors traced to test-list.md:
///   A1: generating a bone for a spec with ≥1 entity creates manifest,
///       entity stubs, layer placeholders, dependency file
///   A2: every import in a generated bone resolves inside the bone or
///       to a declared dependency
///
/// Drives the real BoneCommand entry point via CommandRunner.
/// Uses a temporary output directory; cleans up after.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/bone_command.dart';

import '../helpers/capture_output.dart';

void main() {
  late Directory tmpDir;
  late Directory fixtureDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sc_001_bone_test_');
    // Copy fixture spec to a temp location so the test is hermetic.
    fixtureDir = await Directory(
      '${tmpDir.path}/specs/sample-feature',
    ).create(recursive: true);
    await File('${fixtureDir.path}/spec.md').writeAsString(_sampleSpec);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('SC-001: bone generation (A1, A2)', () {
    test(
      'A1: generating a bone creates manifest, entity stubs, layer placeholders',
      () async {
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            '${fixtureDir.path}/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = '$outputDir/sample-feature';

        // Manifest file exists.
        final manifestFile = File('$boneDir/bone.yaml');
        expect(
          await manifestFile.exists(),
          isTrue,
          reason: 'bone.yaml must exist',
        );

        // Entity stubs exist.
        expect(
          await File('$boneDir/lib/entities/product.dart').exists(),
          isTrue,
          reason: 'product.dart entity stub must exist',
        );
        expect(
          await File('$boneDir/lib/entities/cart_item.dart').exists(),
          isTrue,
          reason: 'cart_item.dart entity stub must exist',
        );

        // Layer placeholders exist.
        for (final layer in ['domain', 'data', 'presentation']) {
          expect(
            await Directory('$boneDir/$layer').exists(),
            isTrue,
            reason: '$layer/ directory must exist',
          );
        }

        // Barrel entry point exists.
        expect(
          await File('$boneDir/lib/sample_feature.dart').exists(),
          isTrue,
          reason: 'barrel entry point must exist',
        );
      },
    );

    test(
      'A2: every import in the bone resolves inside the bone or to a dependency',
      () async {
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            '${fixtureDir.path}/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = Directory('$outputDir/sample-feature');
        expect(
          await boneDir.exists(),
          isTrue,
          reason: 'bone directory must exist',
        );

        // Scan all Dart files in the bone for import statements.
        final dartFiles = boneDir
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
                'Import $importPath in ${p.relative(file.path, from: boneDir.path)} '
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
                  'Import $importPath in ${p.relative(file.path, from: boneDir.path)} '
                  'must resolve inside the bone',
            );
          }
        }
      },
    );
  });
}

const _sampleSpec = '''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item
- **CartItem** — user selection

## Requirements

- Products have a name and price
- CartItems reference a Product
''';
