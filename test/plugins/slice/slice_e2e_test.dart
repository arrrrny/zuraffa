@Tags(['slow'])

/// End-to-end lifecycle test (T075; quickstart scenarios 1 and 2, T076).
///
/// Full agent workflow on the fixture project: cut → verify → modify →
/// merge, asserting the quickstart.md expected outcomes:
///   - Scenario 1: sandbox created, slice.yaml/main_slice.dart/SLICE.md
///     present, ownership classified, no data-layer files at feature depth
///   - Scenario 2: only the modified file is copied back, the slice
///     directory is cleaned up, and the console lists what was merged
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/slice_test_harness.dart';

void main() {
  late String projectRoot;

  setUp(() async {
    projectRoot = await freshSliceProject();
  });

  tearDown(() => disposeSliceProject(projectRoot));

  test('T075: cut → verify → modify → merge full lifecycle', () async {
    final sandbox = '$projectRoot/.zuraffa/slices/product_feature';

    // --- Cut (quickstart scenario 1).
    final cutCommand = SliceCommand(projectRoot: projectRoot);
    final cutRunner = CommandRunner<void>('zfa', 'test')
      ..addCommand(cutCommand);
    final cutOutput = await captureOutput(
      () => cutRunner.run([
        'slice',
        'cut',
        'product_feature',
        '--entry',
        'product',
      ]),
    );
    expect(cutCommand.exitCode, equals(0), reason: cutOutput);

    // Sandbox artifacts exist and are valid.
    final manifest =
        loadYaml(File('$sandbox/slice.yaml').readAsStringSync()) as Map;
    expect(manifest['name'], equals('product_feature'));
    expect(File('$sandbox/main_slice.dart').existsSync(), isTrue);
    expect(File('$sandbox/SLICE.md').existsSync(), isTrue);
    expect(
      File(
        '$sandbox/lib/src/presentation/pages/product/product_view.dart',
      ).existsSync(),
      isTrue,
    );

    // Ownership classification: presentation owned, domain shared.
    final files = (manifest['files'] as List).whereType<Map>().toList();
    final viewEntry = files.singleWhere(
      (f) =>
          f['path'] ==
          'lib/src/presentation/pages/product/'
              'product_view.dart',
    );
    expect(viewEntry['ownership'], equals('owned'));
    final entityEntries = files
        .where((f) => (f['path'] as String).contains('domain/entities/'))
        .toList();
    expect(entityEntries, isNotEmpty);
    for (final entity in entityEntries) {
      expect(entity['ownership'], equals('shared'));
    }

    // Feature depth: no data-layer implementations.
    expect(
      files.where((f) => (f['path'] as String).contains('data/')),
      isEmpty,
    );

    // --- Verify (the slice is complete right after the cut).
    final verifyCommand = SliceCommand(projectRoot: projectRoot);
    final verifyRunner = CommandRunner<void>('zfa', 'test')
      ..addCommand(verifyCommand);
    final verifyOutput = await captureOutput(
      () => verifyRunner.run(['slice', 'verify', 'product_feature']),
    );
    expect(verifyCommand.exitCode, equals(0), reason: verifyOutput);

    // --- Agent modifies exactly one file in the sandbox.
    final viewPath =
        '$sandbox/lib/src/presentation/pages/product/product_view.dart';
    File(viewPath).writeAsStringSync(
      '${File(viewPath).readAsStringSync()}\n// Agent was here\n',
    );

    // --- Merge (quickstart scenario 2).
    final mergeCommand = SliceCommand(projectRoot: projectRoot);
    final mergeRunner = CommandRunner<void>('zfa', 'test')
      ..addCommand(mergeCommand);
    final mergeOutput = await captureOutput(
      () => mergeRunner.run(['slice', 'merge', 'product_feature']),
    );
    expect(mergeCommand.exitCode, equals(0), reason: mergeOutput);

    // The modification landed in the main project...
    final projectView = File(
      '$projectRoot/lib/src/presentation/pages/product/product_view.dart',
    );
    expect(projectView.readAsStringSync(), contains('// Agent was here'));
    // ...only that file was touched: the manifest hash of an untouched file
    // still matches its project copy (verified implicitly by merge reporting
    // exactly one copied file). T119: the count is anchored so '11 file(s)'
    // cannot false-pass — the digit '1' must be preceded by start or
    // whitespace.
    expect(mergeOutput, contains(RegExp(r'(^|\s)1 file\(s\) copied back')));

    // The slice directory is cleaned up after a successful merge.
    expect(Directory(sandbox).existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
