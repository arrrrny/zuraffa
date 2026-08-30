@Tags(['slow'])
/// SC-003 acceptance test: SDD/TDD workflow integration.
///
/// Behaviors traced to test-list.md:
///   A7: bone generated from a specify-produced spec with DEFAULT resolution
///       reflects the spec's declared entities
///   A8: the bone's test stubs parse as valid Dart test scaffolds
///   A9: xray overlay markers in the source spec are preserved in the
///       bone manifest
///
/// Drives the real BoneCommand entry point via CommandRunner.
/// Uses a temporary output directory; cleans up after.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/bone_command.dart';

import '../helpers/capture_output.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sc_003_workflow_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('SC-003: workflow integration (A7, A8, A9)', () {
    test(
      'A7: bone generated from a spec reflects the spec declared entities',
      () async {
        // Set up .specify/feature.json pointing to the spec.
        final featureJsonDir = await Directory(
          '${tmpDir.path}/.specify',
        ).create();
        await File('${featureJsonDir.path}/feature.json').writeAsString(
          jsonEncode({'feature_directory': 'specs/workflow-feature'}),
        );

        // Write the spec.
        await File(
          '${tmpDir.path}/specs/workflow-feature/spec.md',
        ).create(recursive: true);
        await File(
          '${tmpDir.path}/specs/workflow-feature/spec.md',
        ).writeAsString(_workflowSpec);

        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand(
          specsRoot: tmpDir.path,
          featureJsonPath: '${tmpDir.path}/.specify/feature.json',
        );
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run(['bone', 'generate', '--output', outputDir]),
        );

        final boneDir = '$outputDir/workflow-feature';

        // Bone directory must exist.
        expect(
          await Directory(boneDir).exists(),
          isTrue,
          reason: 'bone directory must be created for the active feature',
        );

        // Manifest must contain the spec's declared entities.
        final manifestContent = await File('$boneDir/bone.yaml').readAsString();
        expect(manifestContent, contains('Widget'));
        expect(manifestContent, contains('Signal'));

        // Entity files must exist for each declared entity (042 layout:
        // entities/<snake>.dart at the bone root).
        expect(
          await File('$boneDir/entities/widget.dart').exists(),
          isTrue,
          reason: 'widget.dart entity file must exist',
        );
        expect(
          await File('$boneDir/entities/signal.dart').exists(),
          isTrue,
          reason: 'signal.dart entity file must exist',
        );
      },
    );

    test('A8: the bone test stubs parse as valid Dart test scaffolds', () async {
      // Set up .specify/feature.json.
      final featureJsonDir = await Directory(
        '${tmpDir.path}/.specify',
      ).create();
      await File('${featureJsonDir.path}/feature.json').writeAsString(
        jsonEncode({'feature_directory': 'specs/test-stub-feature'}),
      );

      // Write the spec.
      await File(
        '${tmpDir.path}/specs/test-stub-feature/spec.md',
      ).create(recursive: true);
      await File(
        '${tmpDir.path}/specs/test-stub-feature/spec.md',
      ).writeAsString(_workflowSpec);

      final outputDir = '${tmpDir.path}/bones';
      final command = BoneCommand(
        specsRoot: tmpDir.path,
        featureJsonPath: '${tmpDir.path}/.specify/feature.json',
      );
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      await captureOutput(
        () => runner.run(['bone', 'generate', '--output', outputDir]),
      );

      final boneDir = Directory('$outputDir/test-stub-feature');

      // Test stubs must exist.
      final testDir = Directory('${boneDir.path}/test');
      expect(
        await testDir.exists(),
        isTrue,
        reason: 'test/ directory must exist',
      );

      final testFiles = testDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .toList();
      expect(testFiles, isNotEmpty, reason: 'must have at least one test stub');

      // Each test must be a real runnable test (042: plain-Dart main with
      // real assertions; no TODO-only stubs).
      for (final testFile in testFiles) {
        final content = testFile.readAsStringSync();

        // Must have a main() function.
        expect(
          RegExp(
            r'^\s*(?:(?:Future<void>|void)\s+)?main\s*\(',
            multiLine: true,
          ).hasMatch(content),
          isTrue,
          reason: '${p.basename(testFile.path)} must define main()',
        );
        expect(
          content.contains('TODO'),
          isFalse,
          reason: '${p.basename(testFile.path)} must not be a TODO stub',
        );
      }

      // Parse-level validity: every .dart file in the bone must be
      // syntactically valid Dart. `dart format --output=none` exits
      // non-zero on unparseable input; no pubspec is required.
      final allDartFiles = Directory(boneDir.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(allDartFiles, isNotEmpty, reason: 'bone must contain .dart files');
      for (final dartFile in allDartFiles) {
        final result = await Process.run('dart', [
          'format',
          '--output=none',
          dartFile.path,
        ]);
        expect(
          result.exitCode,
          0,
          reason:
              '${p.basename(dartFile.path)} must be syntactically valid Dart; '
              'stderr: ${result.stderr}',
        );
      }
    });

    test(
      'A9: xray overlay markers in the source spec are preserved in the bone manifest',
      () async {
        // Write spec with xray markers.
        await File(
          '${tmpDir.path}/specs/xray-feature/spec.md',
        ).create(recursive: true);
        await File(
          '${tmpDir.path}/specs/xray-feature/spec.md',
        ).writeAsString(_xraySpec);

        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'xray-feature',
            '--spec',
            '${tmpDir.path}/specs/xray-feature/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = '$outputDir/xray-feature';
        final manifestContent = await File('$boneDir/bone.yaml').readAsString();

        // Xray key must be present in the manifest.
        expect(
          manifestContent,
          contains('xray:'),
          reason: 'bone.yaml must contain an xray: key',
        );

        // The overlay configuration marker must be preserved.
        expect(
          manifestContent,
          contains('overlay'),
          reason: 'xray overlay marker must be preserved',
        );
      },
    );
  });
}

const _workflowSpec = '''
# Feature: Workflow Feature

## Key Entities

- **Widget** — a UI component
- **Signal** — a reactive data stream

## Requirements

- Widgets render based on Signals
- Signals propagate state changes
''';

const _xraySpec = '''
# Feature: Xray Feature

## Key Entities

- **Widget** — a UI component

<!-- xray: overlay: {"enabled": true, "color": "neon-green"} -->

## Requirements

- Widget must render correctly
''';
