/// Tests for slice plugin polish behaviors (T071-T074).
///
///   T071: SlicePlugin configKey ('sliceByDefault') and config schema for
///         `.zfa.json` integration
///   T072: `--help` on each subcommand prints focused usage with examples
///   T073: `--verbose` on cut/merge prints detailed diagnostics
///   T074: long operations report progress through the ProgressReporter
///         pattern
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';
import 'package:zuraffa/src/plugins/slice/slice_plugin.dart';

import 'helpers/capture_output.dart';
import 'helpers/copy_fixture_project.dart';

void main() {
  late String projectRoot;

  setUp(() async {
    projectRoot = await copySliceFixtureProject();
  });

  tearDown(() async {
    final dir = Directory(projectRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  CommandRunner<void> runnerWith(SliceCommand command) =>
      CommandRunner<void>('zfa', 'test')..addCommand(command);

  group('SlicePlugin configuration (T071)', () {
    test('configKey and config schema expose .zfa.json integration', () {
      final plugin = SlicePlugin();

      expect(plugin.configKey, equals('sliceByDefault'));
      expect(plugin.configSchema, isA<Map>());
      expect(
        plugin.configSchema['properties'] as Map,
        containsPair(
          'sliceByDefault',
          isA<Map>().having(
            (p) => p['type'],
            'type',
            equals('boolean'),
          ),
        ),
      );
    });
  });

  group('subcommand help (T072)', () {
    test('zfa slice cut --help prints cut usage with an example', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(command).run(['slice', 'cut', '--help']),
      );

      expect(command.exitCode, equals(0));
      expect(output, contains('usage: zfa slice cut'));
      expect(output, contains('--entry'));
      expect(output, contains('zfa slice cut product_feature --entry product'));
    });

    test('zfa slice merge --help prints merge usage with an example',
        () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(command).run(['slice', 'merge', '--help']),
      );

      expect(command.exitCode, equals(0));
      expect(output, contains('usage: zfa slice merge'));
      expect(output, contains('--yes'));
      expect(output, contains('zfa slice merge product_feature'));
    });

    test('zfa slice export --help names both formats', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(command).run(['slice', 'export', '--help']),
      );

      expect(command.exitCode, equals(0));
      expect(output, contains('tar.gz'));
      expect(output, contains('github'));
    });
  });

  group('verbose diagnostics (T073)', () {
    test('cut --verbose lists files, ownership, and boundaries', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(command).run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
          '--verbose',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('verbose:'));
      // Every mirrored file is listed with its ownership.
      expect(
        output,
        contains(
          'verbose: lib/src/presentation/pages/product/product_view.dart '
          '(owned)',
        ),
      );
      // Boundary interfaces are listed for debugging the walk.
      expect(output, contains('verbose: boundary'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('merge --verbose prints per-file decisions', () async {
      final cutCommand = SliceCommand(projectRoot: projectRoot);
      await captureOutput(
        () => runnerWith(cutCommand).run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
        ]),
      );

      // Agent modifies one file.
      File(
        '$projectRoot/.zuraffa/slices/product_feature/'
        'lib/src/presentation/pages/product/product_view.dart',
      ).writeAsStringSync('// agent edit\n');

      final mergeCommand = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(mergeCommand).run([
          'slice',
          'merge',
          'product_feature',
          '--verbose',
        ]),
      );

      expect(mergeCommand.exitCode, equals(0), reason: output);
      expect(
        output,
        contains(
          'verbose: copied '
          'lib/src/presentation/pages/product/product_view.dart',
        ),
      );
      expect(output, contains('verbose: skipped'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('progress reporting (T074)', () {
    test('cut reports started/step/completed progress', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(command).run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('[_] Cutting slice "product_feature"'));
      expect(output, contains('[✓] Completed'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('merge reports progress', () async {
      final cutCommand = SliceCommand(projectRoot: projectRoot);
      await captureOutput(
        () => runnerWith(cutCommand).run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
        ]),
      );

      final mergeCommand = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(mergeCommand).run(['slice', 'merge', 'product_feature']),
      );

      expect(mergeCommand.exitCode, equals(0), reason: output);
      expect(output, contains('[_] Merging slice "product_feature"'));
      expect(output, contains('[✓] Completed'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('export reports progress', () async {
      final cutCommand = SliceCommand(projectRoot: projectRoot);
      await captureOutput(
        () => runnerWith(cutCommand).run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
        ]),
      );

      final exportCommand = SliceCommand(projectRoot: projectRoot);
      final output = await captureOutput(
        () => runnerWith(exportCommand).run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'tar.gz',
        ]),
      );

      expect(exportCommand.exitCode, equals(0), reason: output);
      expect(output, contains('[_] Exporting slice "product_feature"'));
      expect(output, contains('[✓] Completed'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
