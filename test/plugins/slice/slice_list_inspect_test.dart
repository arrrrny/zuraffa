/// Acceptance tests for `zfa slice list` and `zfa slice inspect`
/// (A9, A10; gates T095-T096).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A9: `slice list` shows all active slices with name, entry points,
///       creation date, and file count
///   A10: `slice inspect` shows every file with ownership classification
///        and modified-since-cut status
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

  Future<void> cut(String name, String entry) => captureOutput(
        () => runner.run(['slice', 'cut', name, '--entry', entry]),
      );

  group('slice list (US3, FR-012)', () {
    test('A9 (T095): list shows both slices with entries, date, and count',
        () async {
      await cut('product_feature', 'product');
      await cut('profile_feature', 'profile');

      final output = await captureOutput(() => runner.run(['slice', 'list']));

      expect(command.exitCode, equals(0), reason: output);
      expect(output, contains('product_feature'));
      expect(output, contains('profile_feature'));
      // Entry points are visible.
      expect(output, contains('product_view.dart'));
      expect(output, contains('profile_view.dart'));
      // Creation date is shown.
      expect(output, contains(DateTime.now().year.toString()));
      // File counts are shown per slice.
      expect(output, contains('files'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A9: list with no slices says so', () async {
      final output = await captureOutput(() => runner.run(['slice', 'list']));

      expect(command.exitCode, equals(0));
      expect(output, contains('No active slices'));
    });
  });

  group('slice inspect (US3, FR-012)', () {
    test('A10 (T096): inspect shows every file with ownership and '
        'modification status', () async {
      await cut('product_feature', 'product');

      // Simulate the agent editing two files.
      final viewRel =
          'lib/src/presentation/pages/product/product_view.dart';
      final viewFile = File(
        '$projectRoot/.zuraffa/slices/product_feature/$viewRel',
      );
      await viewFile.writeAsString(
        '${await viewFile.readAsString()}\n// Agent edit',
      );

      final output = await captureOutput(
        () => runner.run(['slice', 'inspect', 'product_feature']),
      );

      expect(command.exitCode, equals(0), reason: output);
      // Ownership classification per file.
      expect(output, contains('owned'));
      expect(output, contains('shared'));
      expect(output, contains(viewRel));
      expect(
        output,
        contains('lib/src/domain/entities/product/product.dart'),
      );
      // The modified file is flagged; the untouched ones are not.
      expect(output, contains('modified'));
      expect(output, contains('unmodified'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A10: inspecting a missing slice fails cleanly', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'inspect', 'ghost_slice']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('ghost_slice'));
      expect(output, isNot(contains('#0')));
    });
  });
}
