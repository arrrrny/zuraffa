/// Tests for ExportSliceCapability (U58; gate T086).
///
/// Behavior traced to specs/043-slice-plugin/tdd/test-list.md:
///   U58: Export of a slice that fails verification aborts before any archive
///        or repo is made
///
/// T124: intentionally paired with A26 in slice_export_integration_test.dart
/// — one gate, two levels of negative: this unit test pins that no tarball
/// lands on disk; A26 pins that no gh command fires pre-verify.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import '../helpers/capture_output.dart';
import '../helpers/slice_test_harness.dart';

void main() {
  late String projectRoot;

  setUp(() async {
    projectRoot = await freshSliceProject();
  });

  tearDown(() => disposeSliceProject(projectRoot));

  group('ExportSliceCapability verify gate (FR-020)', () {
    test('U58: export of a broken slice aborts with no artifact', () async {
      final cutCommand = SliceCommand(projectRoot: projectRoot);
      final cutRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(cutCommand);
      await captureOutput(
        () => cutRunner.run([
          'slice',
          'cut',
          'product_feature',
          '--entry',
          'product',
        ]),
      );
      final archivePath =
          '$projectRoot/.zuraffa/exports/product_feature.tar.gz';
      expect(File(archivePath).existsSync(), isFalse);

      // Break the slice: delete a mirrored file so verification fails.
      File(
        '$projectRoot/.zuraffa/slices/product_feature/'
        'lib/src/presentation/pages/product/product_controller.dart',
      ).deleteSync();

      final exportCommand = SliceCommand(projectRoot: projectRoot);
      final exportRunner = CommandRunner<void>('zfa', 'test')
        ..addCommand(exportCommand);
      final output = await captureOutput(
        () => exportRunner.run([
          'slice',
          'export',
          'product_feature',
          '--format',
          'tar.gz',
        ]),
      );

      expect(exportCommand.exitCode, equals(1));
      expect(output, contains('unresolved'));
      expect(
        File(archivePath).existsSync(),
        isFalse,
        reason: 'U58: no archive may be produced when verification fails',
      );
      expect(output, isNot(contains('#0')));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
