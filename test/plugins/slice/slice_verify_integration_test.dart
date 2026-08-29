/// Acceptance tests for `zfa slice verify` (A16, A17, A18, A19; gates
/// T102-T105).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A16: `slice verify` on a complete slice reports all imports resolved
///   A17: `slice verify` on a slice missing a file reports exactly which
///        files have unresolved imports and which import paths are broken
///   A18: `slice verify --analyze` runs `dart analyze` on the sandbox and
///        reports compilation errors
///   A19: `zfa slice cut --verify` auto-verifies after extraction and fails
///        the extraction when the slice is incomplete
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/copy_fixture_project.dart';

void main() {
  late String projectRoot;
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() async {
    projectRoot = await copySliceFixtureProject();
    command = SliceCommand(projectRoot: projectRoot);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  tearDown(() async {
    final dir = Directory(projectRoot);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  String sandbox() => '$projectRoot/.zuraffa/slices/product_feature';

  Future<void> cut() => captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

  group('slice verify (US6, FR-013..FR-015)', () {
    test('A16 (T102): a complete slice verifies clean', () async {
      await cut();

      final output = await captureOutput(
        () => runner.run(['slice', 'verify', 'product_feature']),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('all imports resolved'));
      expect(output, contains('ready'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A17 (T103): a deleted sandbox file is reported with its broken '
        'imports', () async {
      await cut();

      // Simulate an accidental exclusion: the controller imports the
      // presenter, the view imports the controller.
      File(
        '${sandbox()}/lib/src/presentation/pages/product/product_controller.dart',
      ).deleteSync();

      final output = await captureOutput(
        () => runner.run(['slice', 'verify', 'product_feature']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('product_view.dart'));
      expect(output, contains('product_controller.dart'));
      expect(output, contains('unresolved'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A18 (T104): --analyze runs dart analyze and reports errors',
        () async {
      await cut();

      // Inject the process seam: the fake analyzer reports two errors.
      final analyzeCommand = SliceCommand(
        projectRoot: projectRoot,
        analyzeLauncher: (executable, args, {workingDirectory}) async {
          expect(executable, equals('dart'));
          expect(args, contains('analyze'));
          expect(args.last, contains('product_feature'));
          return ProcessResult(
            1,
            2,
            'Analyzing sandbox...\n'
                '  error - lib/src/mocks/mock_product_repository.dart:7:10 - '
                'Undefined name \'Bar\'. - undefined_identifier\n'
                '1 issue found.',
            '',
          );
        },
      );
      final analyzeRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(analyzeCommand);

      final output = await captureOutput(
        () => analyzeRunner.run([
          'slice',
          'verify',
          'product_feature',
          '--analyze',
        ]),
      );

      expect(analyzeCommand.exitCode, equals(1));
      expect(output, contains('mock_product_repository.dart'));
      expect(output, contains('Undefined name'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A19 (T105): cut --verify fails the cut when the slice is broken',
        () async {
      // Break the fixture first: the controller imports a file that does
      // not exist, so the extracted slice cannot be import-closed.
      final controller = File(
        '$projectRoot/lib/src/presentation/pages/product/product_controller.dart',
      );
      await controller.writeAsString(
        "${await controller.readAsString()}\nimport 'missing_widget.dart';\n",
      );

      final output = await captureOutput(
        () => runner.run([
          'slice',
          'cut',
          'broken_slice',
          '--entry',
          'product',
          '--verify',
        ]),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('verification failed'));
      // The incomplete sandbox is rolled back.
      expect(
        Directory('$projectRoot/.zuraffa/slices/broken_slice').existsSync(),
        isFalse,
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
