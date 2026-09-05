import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/plugins/di/capabilities/create_di_capability.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

/// SPEC 0974 (issue #974, order 4): real verdicts —
/// `ExecutionResult.success` reflects actual generation (a forced failure
/// returns `success: false`), and non-fatal outcomes surface as
/// structured `{target, reason}` warning entries instead of a silent
/// hardcoded success.
/// File system whose write path always fails — forces a generation
/// failure through the REAL plugin pipeline (DiPlugin -> FileUtils).
class _ExplodingFileSystem implements FileSystem {
  const _ExplodingFileSystem();

  @override
  Future<void> write(String path, String content) async {
    throw StateError('simulated disk failure: $path');
  }

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {
    throw StateError('simulated disk failure: $path');
  }

  @override
  Future<String> read(String path) async => '';

  @override
  String readSync(String path) => '';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<bool> exists(String path) async => false;

  @override
  bool existsSync(String path) => false;

  @override
  Future<bool> isDirectory(String path) async => false;

  @override
  bool isDirectorySync(String path) => false;

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async =>
      const [];

  @override
  List<String> listSync(String path, {bool recursive = false}) => const [];

  @override
  Stream<String> watch(String path) => const Stream.empty();
}

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_verdict_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('A4: a forced generation failure returns success: false', () async {
    final plugin = DiPlugin(
      outputDir: outputDir,
      // Options must match the capability's config (force/dryRun/verbose/
      // revert all false) so DiPlugin.generate does NOT delegate to a
      // fresh plugin — the delegator rebuilds with a default FileSystem
      // and would bypass the injected exploding one.
      options: const GeneratorOptions(),
      fileSystem: const _ExplodingFileSystem(),
    );
    final capability = CreateDiCapability(plugin, projectRoot: projectRoot);

    final result = await capability.execute({'name': 'Product'});

    expect(
      result.success,
      isFalse,
      reason: 'a generation failure must not report success',
    );
    expect(result.message, isNotNull);
    expect(result.message, contains('simulated disk failure'));
    expect(result.files, isEmpty);
    // No proof for a failed run.
    expect(
      Directory(p.join(projectRoot, '.zfa', 'receipts')).existsSync(),
      isFalse,
    );
  });

  test(
    'A4b: successful generation still returns success: true (no false negatives)',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final result = await CreateDiCapability(
        plugin,
        projectRoot: projectRoot,
      ).execute({'name': 'Product'});

      expect(result.success, isTrue);
      expect(result.files, isNotEmpty);
      expect(
        result.warnings,
        isEmpty,
        reason: 'a clean first run has nothing to warn about',
      );
    },
  );

  test(
    'A4c: skipped files surface as structured {target, reason} warnings',
    () async {
      final plugin = DiPlugin(
        outputDir: outputDir,
        // force: false so the second run hits existing files.
        options: const GeneratorOptions(force: false),
      );
      final capability = CreateDiCapability(plugin, projectRoot: projectRoot);

      // First run creates everything.
      await capability.execute({'name': 'Product'});
      // Second run without --force: every file is skipped.
      final second = await capability.execute({'name': 'Product'});

      expect(
        second.warnings,
        isNotEmpty,
        reason: 'skipped files must become structured warnings',
      );
      for (final warning in second.warnings) {
        expect(warning.keys, containsAll(['target', 'reason']));
        expect(warning['target'], isA<String>());
        expect(warning['reason'], isA<String>());
        expect(warning['reason'].toString(), contains('force'));
      }
      expect(
        second.warnings.any(
          (w) => w['target'].toString().endsWith('service_locator.dart'),
        ),
        isTrue,
        reason:
            'the silently-dropped shared artifact (service_locator) '
            'must surface as a structured warning',
      );
    },
  );

  test('U6: ExecutionResult serializes structured warnings in toJson()', () {
    final result = ExecutionResult(
      success: true,
      warnings: [
        {'target': 'lib/src/di/x_di.dart', 'reason': 'exists'},
      ],
    );

    final json = result.toJson();
    expect(json['warnings'], isA<List<dynamic>>());
    expect(
      (json['warnings'] as List).first,
      containsPair('target', 'lib/src/di/x_di.dart'),
    );

    // Absent when empty — the default shape stays byte-compatible.
    expect(
      ExecutionResult(success: true).toJson().containsKey('warnings'),
      isFalse,
    );
  });
}
