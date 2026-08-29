/// Tests for SliceRunner (U51, U52, U53; acceptance A20, A21, A22;
/// gates T106-T108).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U51: Builds `flutter run -t <project>/.zuraffa/slices/<name>/main_slice.dart`
///        with the working directory at the project root
///   U52: Extra CLI flags are forwarded to `flutter run` verbatim
///   U53: A failed fast verification aborts the launch before `flutter run`
///        executes
///   A20: `slice run <name>` launches the slice from the project root
///   A21: `slice run` on an unverified slice verifies first and aborts
///   A22: Extra flags (e.g. `--device chrome`) pass through
///
/// The repo test env has no Flutter SDK: command construction is asserted
/// through the injected process seam (per the fixture-based approach in
/// tasks.md).
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/runner/slice_runner.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import '../helpers/capture_output.dart';
import '../helpers/slice_test_harness.dart';

void main() {
  late String projectRoot;

  setUp(() async {
    projectRoot = await freshSliceProject();
  });

  tearDown(() => disposeSliceProject(projectRoot));

  Future<void> cut(CommandRunner<void> runner) => captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

  group('SliceRunner (FR-016)', () {
    test('U51: builds flutter run -t <main_slice> from the project root',
        () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await cut(runner);

      final launched = <List<String>>[];
      final runCommand = SliceCommand(
        projectRoot: projectRoot,
        processLauncher: (executable, args, {workingDirectory}) async {
          launched.add([executable, ...args]);
          expect(workingDirectory, equals(projectRoot));
          return ProcessResult(1, 0, '', '');
        },
      );
      final runRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(runCommand);

      await captureOutput(
        () => runRunner.run(['slice', 'run', 'product_feature']),
      );

      expect(runCommand.exitCode, equals(0));
      expect(launched, hasLength(1));
      final invocation = launched.single;
      expect(invocation.first, equals('flutter'));
      expect(invocation[1], equals('run'));
      expect(invocation[2], equals('-t'));
      expect(
        invocation[3],
        endsWith('.zuraffa/slices/product_feature/main_slice.dart'),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('U52/A22 (T108): extra flags pass through verbatim', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await cut(runner);

      final launched = <List<String>>[];
      final runCommand = SliceCommand(
        projectRoot: projectRoot,
        processLauncher: (executable, args, {workingDirectory}) async {
          launched.add([executable, ...args]);
          return ProcessResult(1, 0, '', '');
        },
      );
      final runRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(runCommand);

      await captureOutput(
        () => runRunner.run(['slice', 'run', 'product_feature', '--device', 'chrome']),
      );

      expect(launched.single, contains('--device'));
      expect(launched.single, contains('chrome'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('U53/A21 (T107): failed verification aborts before launch',
        () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await cut(runner);

      // Break the slice: delete a mirrored file so verification fails.
      File(
        '$projectRoot/.zuraffa/slices/product_feature/'
        'lib/src/presentation/pages/product/product_controller.dart',
      ).deleteSync();

      final launched = <List<String>>[];
      final runCommand = SliceCommand(
        projectRoot: projectRoot,
        processLauncher: (executable, args, {workingDirectory}) async {
          launched.add([executable, ...args]);
          return ProcessResult(1, 0, '', '');
        },
      );
      final runRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(runCommand);

      final output = await captureOutput(
        () => runRunner.run(['slice', 'run', 'product_feature']),
      );

      expect(runCommand.exitCode, equals(1));
      expect(launched, isEmpty, reason: 'flutter run must never execute');
      expect(output, contains('unresolved'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('run on a missing slice fails cleanly', () async {
      final runCommand = SliceCommand(projectRoot: projectRoot);
      final runRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(runCommand);

      final output = await captureOutput(
        () => runRunner.run(['slice', 'run', 'ghost']),
      );

      expect(runCommand.exitCode, equals(1));
      expect(output, contains('ghost'));
      expect(output, isNot(contains('#0')));
    });

    test('A20 (T106): the launch uses flutter run with -t from the root '
        '(direct runner API)', () async {
      final command = SliceCommand(projectRoot: projectRoot);
      final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
      await cut(runner);

      final launched = <List<String>>[];
      final sliceRunner = SliceRunner(
        launcher: (executable, args, {workingDirectory}) async {
          launched.add([executable, ...args, 'wd:$workingDirectory']);
          return ProcessResult(1, 0, '', '');
        },
      );
      final result = await sliceRunner.runSlice(
        sliceName: 'product_feature',
        projectRoot: projectRoot,
        extraArgs: const [],
      );

      expect(result.launched, isTrue);
      expect(launched.single.first, equals('flutter'));
      expect(launched.single, contains('-t'));
      expect(launched.single.last, contains('wd:$projectRoot'));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
