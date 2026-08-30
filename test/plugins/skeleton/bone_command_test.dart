@Tags(['slow'])
/// Tests for zfa bone command (U32, U26, U28, U29, U30, U31).
///
/// Behaviors traced to test-list.md:
///   U32: `zfa bone --help` lists the generate, export, and validate subcommands
///   U26: `zfa bone generate <slug>` generates the bone for the named feature
///   U28: `zfa bone export` writes a .tar.gz containing every file in the bone
///   U29: `zfa bone export` fails non-zero when the bone has not been generated
///   U30: `zfa bone validate` passes a clean bone and fails after spec changes
///   U31: command failures exit non-zero with a stderr message and no partial output
///
/// Drives the command through its real entry point: an args CommandRunner
/// hosting BoneCommand, with stdout/stderr captured via runZoned.
/// Tests use --bones-dir and --output to avoid CWD changes.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/bone_command.dart';
import 'package:zuraffa/src/plugins/skeleton/generators/spec_reader.dart';

import '../../helpers/run_zfa_source.dart';
import 'helpers/capture_output.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('bone_command_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> writeSpec(
    String content, {
    String dirName = 'sample-feature',
  }) async {
    final dir = await Directory(
      '${tmpDir.path}/specs/$dirName',
    ).create(recursive: true);
    final file = File('${dir.path}/spec.md');
    await file.writeAsString(content);
    return file;
  }

  group('BoneCommand', () {
    test(
      'U32: zfa bone --help lists generate, export, and validate subcommands',
      () async {
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        final output = await captureOutput(
          () => runner.run(['bone', '--help']),
        );

        expect(output, contains('generate'));
        expect(output, contains('export'));
        expect(output, contains('validate'));
      },
    );

    test(
      'U26: zfa bone generate <slug> generates the bone for the named feature',
      () async {
        await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item
- **CartItem** — user selection

## Requirements

Something.
''');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        final output = await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            '${tmpDir.path}/specs/sample-feature/spec.md',
            '--output',
            outputDir,
          ]),
        );

        // Bone directory must exist.
        final boneDir = '$outputDir/sample-feature';
        expect(
          await Directory(boneDir).exists(),
          isTrue,
          reason: 'bone directory must be created',
        );

        // Manifest must exist.
        expect(
          await File('$boneDir/bone.yaml').exists(),
          isTrue,
          reason: 'bone.yaml must be created',
        );

        // Output must mention the bone path.
        expect(output, contains('sample-feature'));
      },
    );

    test(
      'U31: generate failure exits non-zero with no partial output',
      () async {
        // Empty spec (no entities) should fail.
        await writeSpec('''
# Feature: Empty Feature

## Requirements

No entities.
''');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        // The command should print an error but not crash.
        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'empty-feature',
            '--spec',
            '${tmpDir.path}/specs/empty-feature/spec.md',
            '--output',
            outputDir,
          ]),
        );

        // No partial bone directory should exist.
        final boneDir = '$outputDir/empty-feature';
        expect(
          await Directory(boneDir).exists(),
          isFalse,
          reason: 'no partial output on failure',
        );
      },
    );

    test(
      'U28: zfa bone export writes a tar.gz containing every bone file',
      () async {
        // Manually set up a bone directory structure.
        final bonesDir = '${tmpDir.path}/bones';
        final boneDir = '$bonesDir/export-feature';
        await Directory('$boneDir/lib/entities').create(recursive: true);
        await Directory('$boneDir/test').create(recursive: true);
        await File(
          '$boneDir/bone.yaml',
        ).writeAsString('version: 1\nfeature: export-feature\n');
        await File(
          '$boneDir/lib/entities/widget.dart',
        ).writeAsString('class Widget {}\n');
        await File(
          '$boneDir/lib/export_feature.dart',
        ).writeAsString("export 'entities/widget.dart';\n");
        await File('$boneDir/test/widget_test.dart').writeAsString(
          "import '../lib/export_feature.dart';\nvoid main() {}\n",
        );

        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        // Export using --bones-dir to point at our temp bones directory.
        final tarGzPath = '${tmpDir.path}/export-feature.tar.gz';
        await captureOutput(
          () => runner.run([
            'bone',
            'export',
            'export-feature',
            '--bones-dir',
            bonesDir,
            '--output',
            tarGzPath,
          ]),
        );

        // The tar.gz file must exist.
        expect(
          await File(tarGzPath).exists(),
          isTrue,
          reason: 'tar.gz file must be created',
        );

        // Decode and verify contents.
        final gzBytes = await File(tarGzPath).readAsBytes();
        final tarBytes = GZipDecoder().decodeBytes(gzBytes);
        final archive = TarDecoder().decodeBytes(tarBytes);
        final fileNames = archive.map((f) => f.name).toList();

        // Must contain bone.yaml.
        expect(
          fileNames,
          anyElement(contains('bone.yaml')),
          reason: 'archive must contain bone.yaml',
        );
        // Must contain entity stubs.
        expect(
          fileNames,
          anyElement(contains('widget.dart')),
          reason: 'archive must contain widget.dart',
        );
        // Must contain barrel.
        expect(
          fileNames,
          anyElement(contains('export_feature.dart')),
          reason: 'archive must contain barrel',
        );
      },
    );

    test(
      'U29: zfa bone export fails non-zero when the bone has not been generated',
      () async {
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        // Export non-existent bone.
        final output = await captureOutput(
          () => runner.run([
            'bone',
            'export',
            'nonexistent-bone',
            '--bones-dir',
            '${tmpDir.path}/bones',
          ]),
        );

        // Should print error message naming the bone.
        expect(
          output,
          contains('Error'),
          reason: 'export must print error for missing bone',
        );
        expect(
          output,
          contains('not generated'),
          reason: 'error must mention the bone was not generated',
        );
        expect(
          output,
          contains('nonexistent-bone'),
          reason: 'error must name the missing bone slug',
        );
      },
    );

    test(
      'U30: zfa bone validate passes a clean bone and fails after spec changes',
      () async {
        // Write a spec.
        final specContent =
            '# Feature: Validate Feature\n\n'
            '## Key Entities\n\n- **Item** — a thing\n\n'
            '## Requirements\n\nSomething.\n';
        final specDir = await Directory(
          '${tmpDir.path}/specs/validate-feature',
        ).create(recursive: true);
        final specFile = File('${specDir.path}/spec.md');
        await specFile.writeAsString(specContent);

        // Compute the spec_version hash.
        final reader = SpecReader();
        final specResult = reader.read(specFile);

        // Create a bone directory with the correct spec_version hash.
        final bonesDir = '${tmpDir.path}/bones';
        final boneDir = '$bonesDir/validate-feature';
        await Directory(boneDir).create(recursive: true);
        await File('$boneDir/bone.yaml').writeAsString(
          'version: 1\n'
          'feature: validate-feature\n'
          'spec_version: sha256:${specResult.specVersion}\n'
          'entities:\n  - Item\n'
          'dependencies: []\n'
          'layers:\n  - domain\n  - data\n  - presentation\n',
        );

        // Validate should pass.
        final valCommand = BoneCommand(specsRoot: tmpDir.path);
        final valRunner = CommandRunner<void>('zfa', 'test')
          ..addCommand(valCommand);

        final output1 = await captureOutput(
          () => valRunner.run([
            'bone',
            'validate',
            'validate-feature',
            '--bones-dir',
            bonesDir,
          ]),
        );
        expect(
          output1,
          contains('OK'),
          reason: 'validate must pass for a clean bone',
        );

        // Now modify the spec (changes the hash).
        final newContent =
            '# Feature: Validate Feature (changed)\n\n'
            '## Key Entities\n\n- **Item** — a thing\n\n'
            '## Requirements\n\nSomething different.\n';
        await specFile.writeAsString(newContent);

        // Validate should now report staleness.
        final output2 = await captureOutput(
          () => valRunner.run([
            'bone',
            'validate',
            'validate-feature',
            '--bones-dir',
            bonesDir,
          ]),
        );
        expect(
          output2,
          contains('stale'),
          reason: 'validate must report staleness when spec changes',
        );
        expect(
          output2,
          contains('Error'),
          reason: 'validate staleness must prefix with Error',
        );
        expect(
          output2,
          contains('spec_version'),
          reason: 'staleness error must mention spec_version',
        );
      },
    );

    test(
      'U37: validate rejects a bone containing a broken relative import',
      () async {
        // Write a spec and generate a bone.
        await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Widget** — a UI component

## Requirements

Something.
''', dirName: 'sample-feature');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            '${tmpDir.path}/specs/sample-feature/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = '$outputDir/sample-feature';
        expect(
          await Directory(boneDir).exists(),
          isTrue,
          reason: 'bone dir must exist after generate',
        );

        // Inject a broken relative import into one of the stub files.
        final stubFile = File('$boneDir/entities/widget.dart');
        final originalContent = await stubFile.readAsString();
        await stubFile.writeAsString(
          "import 'does_not_exist.dart';\n$originalContent",
        );

        // Validate should fail and name the broken import.
        final valOutput = await captureOutput(
          () => runner.run([
            'bone',
            'validate',
            'sample-feature',
            '--bones-dir',
            outputDir,
          ]),
        );

        expect(
          valOutput,
          allOf(contains('Error'), contains('does_not_exist.dart')),
          reason: 'validate must reject broken import and name the file',
        );
      },
    );

    test(
      'validate rejects package: import not matching a declared dependency',
      () async {
        // Generate a bone with no declared dependencies.
        await writeSpec('''
# Feature: Pkg Feature

## Key Entities

- **Item** — a thing

## Requirements

Something.
''', dirName: 'pkg-feature');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'pkg-feature',
            '--spec',
            '${tmpDir.path}/specs/pkg-feature/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = '$outputDir/pkg-feature';
        // Inject a package: import not backed by any declared dependency.
        final stubFile = File('$boneDir/entities/item.dart');
        final originalContent = await stubFile.readAsString();
        await stubFile.writeAsString(
          "import 'package:not_a_declared_dep/x.dart';\n$originalContent",
        );

        // Validate should reject the undeclared package import.
        final valOutput = await captureOutput(
          () => runner.run([
            'bone',
            'validate',
            'pkg-feature',
            '--bones-dir',
            outputDir,
          ]),
        );

        expect(
          valOutput,
          allOf(contains('Error'), contains('not_a_declared_dep')),
          reason:
              'validate must reject package import not backed by a dependency',
        );
      },
    );

    test(
      'validate accepts package: import matching a declared dependency',
      () async {
        // Write a spec with a dependency on export-feature.
        await writeSpec('''
# Feature: Pkg Feature

## Key Entities

- **Item** — a thing

## Requirements

Something.
''', dirName: 'pkg-feature-dep');

        // Also create a dependency feature (so the resolver can find it).
        await writeSpec('''
# Feature: Dep Feature

## Key Entities

- **Widget** — a UI component

## Requirements

Something.
''', dirName: 'dep-feature');

        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'pkg-feature-dep',
            '--spec',
            '${tmpDir.path}/specs/pkg-feature-dep/spec.md',
            '--output',
            outputDir,
          ]),
        );

        final boneDir = '$outputDir/pkg-feature-dep';
        // Inject a package: import whose name matches a declared dependency
        // slug (dep-feature → dep_feature).
        final stubFile = File('$boneDir/entities/item.dart');
        final originalContent = await stubFile.readAsString();
        await stubFile.writeAsString(
          "import 'package:dep_feature/something.dart';\n$originalContent",
        );

        // Bone must also have a dependency on dep-feature in bone.yaml.
        // The resolver adds it because our spec doesn't reference dep entities,
        // so manually add it to the manifest for the positive test.
        final manifestFile = File('$boneDir/bone.yaml');
        var manifestContent = await manifestFile.readAsString();
        manifestContent = manifestContent.replaceFirst(
          'dependencies: []',
          'dependencies:\n  - bone: dep_feature\n    entities:\n      - Widget',
        );
        await manifestFile.writeAsString(manifestContent);

        // Validate should accept the package import because dep_feature
        // is a declared dependency.
        final valOutput = await captureOutput(
          () => runner.run([
            'bone',
            'validate',
            'pkg-feature-dep',
            '--bones-dir',
            outputDir,
          ]),
        );

        expect(
          valOutput,
          contains('OK'),
          reason: 'validate must accept package import backed by a dependency',
        );
      },
    );
  });

  group('U36: process exit code contract', () {
    // The in-process tests above cannot observe this: `CliRunner.run` must
    // propagate a command-set failure `exitCode` to the real process exit code.
    // Driven through the real CLI as a subprocess.
    setUpAll(() async {
      await initZfaSourceBin();
    });

    test(
      'U36: CLI process exits non-zero when a bone subcommand reports an error',
      () async {
        final result = await runZfaSource([
          'bone',
          'export',
          'no-such-bone-u36',
        ], workingDirectory: zfaProjectRoot);
        expect(
          result.exitCode,
          isNot(equals(0)),
          reason:
              'a failed bone subcommand must exit non-zero; '
              'stderr was: ${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });

  group('BoneCommand (042 working slice)', () {
    test('042-U37: invalid --di value prints a usage error, exits non-zero, '
        'and generates nothing', () async {
      final spec = await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item

## Requirements

- Something
''');
      final outputDir = '${tmpDir.path}/bones';
      final command = BoneCommand();
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      final output = await captureOutput(
        () => runner.run([
          'bone',
          'generate',
          'sample-feature',
          '--spec',
          spec.path,
          '--output',
          outputDir,
          '--di',
          'redis',
        ]),
      );

      expect(output, contains('--di'));
      expect(exitCode, isNot(equals(0)));
      expect(
        await Directory('$outputDir/sample-feature').exists(),
        isFalse,
        reason: 'invalid --di must not generate anything',
      );
      exitCode = 0;
    });

    test(
      '042-U38: --export names the artifact <feature>-<di>.tar.gz',
      () async {
        final spec = await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item

## Requirements

- Something
''');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        final output = await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            spec.path,
            '--output',
            outputDir,
            '--di',
            'mock',
            '--export',
          ]),
        );

        final artifact = File('$outputDir/sample-feature-mock.tar.gz');
        expect(
          await artifact.exists(),
          isTrue,
          reason: 'artifact must exist; command output was: $output',
        );
        expect(output, contains('sample-feature-mock.tar.gz'));
      },
    );

    test('042-U39: --di, --flutter, and --include-deps are plumbed to the '
        'generator', () async {
      final spec = await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item

## Requirements

- Something
''');
      final outputDir = '${tmpDir.path}/bones';
      final command = BoneCommand();
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      await captureOutput(
        () => runner.run([
          'bone',
          'generate',
          'sample-feature',
          '--spec',
          spec.path,
          '--output',
          outputDir,
          '--di',
          'mock',
          '--flutter',
          '--include-deps',
        ]),
      );

      final boneDir = '$outputDir/sample-feature';
      // --flutter plumbed: pubspec + main + page + widget test.
      expect(await File('$boneDir/pubspec.yaml').exists(), isTrue);
      expect(await File('$boneDir/lib/main.dart').exists(), isTrue);
      expect(
        await File('$boneDir/presentation/sample_feature_page.dart').exists(),
        isTrue,
      );
      expect(
        await File('$boneDir/test/sample_feature_page_test.dart').exists(),
        isTrue,
      );
      // --di mock plumbed into the manifest.
      final manifest = await File('$boneDir/bone.yaml').readAsString();
      expect(manifest, contains('di: mock'));
      expect(manifest, contains('di_source:'));
    });

    test('042-U40: usage text documents the new flags', () async {
      final command = BoneCommand();
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      final output = await captureOutput(() => runner.run(['bone', '--help']));

      expect(output, contains('--di <mock|firebase|auto>'));
      expect(output, contains('--flutter'));
      expect(output, contains('--include-deps'));
      expect(output, contains('--export'));
    });

    test('042-U41: validate accepts packages declared in the bone pubspec '
        '(flutter mode)', () async {
      final spec = await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item

## Requirements

- Something
''');
      final outputDir = '${tmpDir.path}/bones';
      final command = BoneCommand();
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

      await captureOutput(
        () => runner.run([
          'bone',
          'generate',
          'sample-feature',
          '--spec',
          spec.path,
          '--output',
          outputDir,
          '--flutter',
        ]),
      );

      final output = await captureOutput(
        () => runner.run([
          'bone',
          'validate',
          'sample-feature',
          '--bones-dir',
          outputDir,
        ]),
      );
      expect(output, contains('OK: bone "sample-feature" is valid.'));
    });

    test(
      '042-U42: validate still rejects undeclared package imports',
      () async {
        final spec = await writeSpec('''
# Feature: Sample Feature

## Key Entities

- **Product** — a catalog item

## Requirements

- Something
''');
        final outputDir = '${tmpDir.path}/bones';
        final command = BoneCommand();
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        await captureOutput(
          () => runner.run([
            'bone',
            'generate',
            'sample-feature',
            '--spec',
            spec.path,
            '--output',
            outputDir,
          ]),
        );

        // Inject a rogue import into a generated file.
        final rogue = File('$outputDir/sample-feature/entities/product.dart');
        await rogue.writeAsString(
          "import 'package:some_rogue_package/thing.dart';\n"
          '${await rogue.readAsString()}',
        );

        final output = await captureOutput(
          () => runner.run([
            'bone',
            'validate',
            'sample-feature',
            '--bones-dir',
            outputDir,
          ]),
        );
        expect(output, contains('undeclared package import'));
        exitCode = 0;
      },
    );
  });
}
