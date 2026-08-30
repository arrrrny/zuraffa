@Tags(['slow'])
/// Acceptance tests for `zfa slice merge` (A5, A6, A7, A8; gates T091-T094).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A5: Merge copies back only the agent-modified file to its original
///       path, touching nothing else
///   A6: Merge of a modified `shared` file warns and requires confirmation
///       before overwriting
///   A7: A file changed in both sandbox and main project since the cut is
///       reported as a conflict, never silently overwritten
///   A8: Merge with no modifications reports "no changes to merge" and
///       deletes the slice directory
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import 'helpers/capture_output.dart';
import 'helpers/slice_test_harness.dart';

void main() {
  late String projectRoot;
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() async {
    projectRoot = await freshSliceProject();
    command = SliceCommand(projectRoot: projectRoot);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  tearDown(() => disposeSliceProject(projectRoot));

  String sandbox() => '$projectRoot/.zuraffa/slices/product_feature';

  File sandboxFile(String rel) => File('${sandbox()}/$rel');

  File projectFile(String rel) => File('$projectRoot/$rel');

  Future<void> cut() => captureOutput(
    () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
  );

  group('slice merge acceptance (US2)', () {
    test(
      'A5 (T091): merge copies back only the modified file and cleans up',
      () async {
        await cut();

        // Simulate the agent: modify the view, leave everything else alone.
        final viewRel = 'lib/src/presentation/pages/product/product_view.dart';
        final original = await projectFile(viewRel).readAsString();
        await sandboxFile(
          viewRel,
        ).writeAsString('$original\n// Agent was here');

        final otherRel = 'lib/src/domain/entities/product/product.dart';
        final otherBefore = await projectFile(otherRel).readAsString();

        final output = await captureOutput(
          () => runner.run(['slice', 'merge', 'product_feature']),
        );

        expect(command.exitCode, equals(0), reason: output);
        expect(
          await projectFile(viewRel).readAsString(),
          endsWith('// Agent was here'),
        );
        // Nothing else was touched.
        expect(await projectFile(otherRel).readAsString(), equals(otherBefore));
        // The slice directory is cleaned up after a successful merge.
        expect(await Directory(sandbox()).exists(), isFalse);
        expect(output, contains('product_view.dart'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'A6 (T092): a modified shared file warns and needs confirmation',
      () async {
        await cut();

        final rel = 'lib/src/presentation/widgets/primary_button.dart';
        final original = await projectFile(rel).readAsString();
        await sandboxFile(
          rel,
        ).writeAsString('$original\n// Agent touched shared');

        // Without --yes and without a terminal, the confirmation is denied.
        final output = await captureOutput(
          () => runner.run(['slice', 'merge', 'product_feature']),
        );

        expect(command.exitCode, equals(1));
        expect(output, anyOf(contains('shared'), contains('confirm')));
        expect(await projectFile(rel).readAsString(), equals(original));
        expect(
          await Directory(sandbox()).exists(),
          isTrue,
          reason: 'unconfirmed shared writes preserve the sandbox',
        );

        // With --yes the shared write is confirmed and applied.
        final confirmed = await captureOutput(
          () => runner.run(['slice', 'merge', 'product_feature', '--yes']),
        );

        expect(command.exitCode, equals(0), reason: confirmed);
        expect(
          await projectFile(rel).readAsString(),
          endsWith('// Agent touched shared'),
        );
        expect(await Directory(sandbox()).exists(), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('A7 (T093): concurrent main-project changes are a conflict', () async {
      await cut();

      final rel = 'lib/src/presentation/pages/product/product_view.dart';

      // The agent edits in the sandbox...
      final sandboxContent = await sandboxFile(rel).readAsString();
      await sandboxFile(rel).writeAsString('$sandboxContent\n// Agent edit');

      // ...while the main project changed the same file after the cut.
      final mainContent = await projectFile(rel).readAsString();
      await projectFile(rel).writeAsString('$mainContent\n// Main edit');

      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'product_feature']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('conflict'));
      expect(output, contains('product_view.dart'));
      // The main project's version is never silently overwritten.
      expect(await projectFile(rel).readAsString(), endsWith('// Main edit'));
      // The sandbox survives for manual resolution.
      expect(await Directory(sandbox()).exists(), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A8 (T094): no modifications reports no changes and deletes the '
        'slice', () async {
      await cut();

      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'product_feature']),
      );

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('No changes to merge'));
      expect(await Directory(sandbox()).exists(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('merging a slice that does not exist fails cleanly', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'merge', 'ghost_slice']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('ghost_slice'));
      expect(output, isNot(contains('#0')));
    });
  });
}
