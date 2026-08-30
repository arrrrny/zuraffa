@Tags(['slow'])
/// SC-004 acceptance test: export and validate for external agent consumption.
///
/// Behaviors traced to test-list.md:
///   A10: exporting a bone produces a single .tar.gz containing the full
///        bone structure
///   A11: the exported artifact extracted into a clean directory validates
///        standalone
///
/// Drives the real BoneCommand entry point via CommandRunner.
/// Uses a temporary output directory; cleans up after.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/skeleton/bone_command.dart';

import '../helpers/capture_output.dart';

void main() {
  late Directory tmpDir;
  late Directory specsDir;
  late Directory bonesDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('sc_004_export_test_');
    specsDir = await Directory(
      '${tmpDir.path}/specs/export-feature',
    ).create(recursive: true);
    bonesDir = await Directory('${tmpDir.path}/bones').create();

    // Write a valid spec.
    await File('${specsDir.path}/spec.md').writeAsString(_exportSpec);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  /// Generates a bone for export-feature via BoneCommand.
  Future<void> generateBone() async {
    final command = BoneCommand(specsRoot: tmpDir.path);
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    await captureOutput(
      () => runner.run([
        'bone',
        'generate',
        'export-feature',
        '--spec',
        '${specsDir.path}/spec.md',
        '--output',
        bonesDir.path,
      ]),
    );
  }

  group('SC-004: export and validate (A10, A11)', () {
    test(
      'A10: exporting a bone produces a tar.gz containing every bone file',
      () async {
        await generateBone();

        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        final tarGzPath = '${tmpDir.path}/export-feature.tar.gz';
        await captureOutput(
          () => runner.run([
            'bone',
            'export',
            'export-feature',
            '--bones-dir',
            bonesDir.path,
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

        // Must contain bone.yaml.
        final fileNames = archive.map((f) => f.name).toList();
        expect(
          fileNames,
          anyElement(contains('bone.yaml')),
          reason: 'archive must contain bone.yaml',
        );

        // Must contain entity stubs.
        expect(
          fileNames,
          anyElement(contains('widget.dart')),
          reason: 'archive must contain widget.dart entity stub',
        );
        expect(
          fileNames,
          anyElement(contains('catalog_item.dart')),
          reason: 'archive must contain catalog_item.dart entity stub',
        );

        // Must contain the DI container (042 working slice).
        expect(
          fileNames,
          anyElement(contains('injection.dart')),
          reason: 'archive must contain di/injection.dart',
        );

        // Must contain test stubs.
        expect(
          fileNames,
          anyElement(contains('widget_test.dart')),
          reason: 'archive must contain widget_test.dart test stub',
        );
      },
    );

    test(
      'A11: exported artifact extracted into a clean directory validates standalone',
      () async {
        await generateBone();

        final command = BoneCommand(specsRoot: tmpDir.path);
        final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);

        final tarGzPath = '${tmpDir.path}/export-feature.tar.gz';
        await captureOutput(
          () => runner.run([
            'bone',
            'export',
            'export-feature',
            '--bones-dir',
            bonesDir.path,
            '--output',
            tarGzPath,
          ]),
        );

        // Extract into a clean temp directory.
        final extractDir = await Directory('${tmpDir.path}/extracted').create();
        final gzBytes = await File(tarGzPath).readAsBytes();
        final tarBytes = GZipDecoder().decodeBytes(gzBytes);
        final archive = TarDecoder().decodeBytes(tarBytes);

        for (final file in archive) {
          if (file.isFile) {
            final outFile = File('${extractDir.path}/${file.name}');
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(
              Uint8List.fromList(file.content as List<int>),
            );
          }
        }

        // The extracted bone must be usable standalone.
        // Check that bone.yaml exists and has the right content.
        final manifestFile = File('${extractDir.path}/bone.yaml');
        expect(
          await manifestFile.exists(),
          isTrue,
          reason: 'extracted bone.yaml must exist',
        );
        final manifestContent = await manifestFile.readAsString();
        expect(manifestContent, contains('feature: export-feature'));

        // Entity files must be present (042 layout: entities/).
        expect(
          await File('${extractDir.path}/entities/widget.dart').exists(),
          isTrue,
          reason: 'widget.dart must exist in extracted bone',
        );

        // Test stubs must be present.
        expect(
          await File('${extractDir.path}/test/widget_test.dart').exists(),
          isTrue,
          reason: 'widget_test.dart must exist in extracted bone',
        );

        // The extracted bone passes self-containment check:
        // scan all Dart files for imports.
        final dartFiles = extractDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          final imports = RegExp(
            r"^import\s+'([^']+)';",
            multiLine: true,
          ).allMatches(content);

          for (final match in imports) {
            final importPath = match.group(1)!;
            if (importPath.startsWith('dart:')) continue;
            // package:* imports are only valid when backed by a declared
            // dependency (matching bone slug in bone.yaml dependencies).
            // Standalone bones have no deps, so any package: import fails.
            if (importPath.startsWith('package:')) {
              fail(
                'Import $importPath in '
                '${p.relative(file.path, from: extractDir.path)} '
                'is a package: import not backed by a declared dependency',
              );
            }

            final resolved = p.normalize(
              p.join(p.dirname(file.path), importPath),
            );
            expect(
              await File(resolved).exists(),
              isTrue,
              reason:
                  'Import "$importPath" in '
                  '${p.relative(file.path, from: extractDir.path)} '
                  'must resolve inside the extracted bone',
            );
          }
        }
      },
    );
  });
}

const _exportSpec = '''
# Feature: Export Feature

## Key Entities

- **Widget** — a UI component
- **CatalogItem** — a product entry

## Requirements

- Widgets display CatalogItems
''';
