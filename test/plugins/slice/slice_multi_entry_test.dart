@Tags(['slow'])

/// Acceptance tests for multi-entry cuts (A11, A12; gates T097-T098).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A11: A two-entry cut contains both pages' dependency trees with shared
///        dependencies included exactly once
///   A12: A usecase shared by both entries appears once in the manifest
///        with one DI registration
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
  late CommandRunner<void> runner;
  late SliceCommand command;

  setUp(() async {
    projectRoot = await freshSliceProject();
    command = SliceCommand(projectRoot: projectRoot);
    runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
  });

  tearDown(() => disposeSliceProject(projectRoot));

  test(
    'A11 (T097): both pages with shared dependencies exactly once',
    () async {
      final output = await captureOutput(
        () => runner.run([
          'slice',
          'cut',
          'profile_flow',
          '--entry',
          'product',
          '--entry',
          'profile',
        ]),
      );

      expect(command.exitCode, equals(0), reason: output);

      final sandbox = '$projectRoot/.zuraffa/slices/profile_flow';
      final files = Directory(sandbox)
          .listSync(recursive: true)
          .whereType<File>()
          .map(
            (f) => f.path.substring(sandbox.length + 1).replaceAll('\\', '/'),
          )
          .toList();

      // Both pages' trees.
      expect(
        files,
        contains('lib/src/presentation/pages/product/product_view.dart'),
      );
      expect(
        files,
        contains('lib/src/presentation/pages/product/product_presenter.dart'),
      );
      expect(
        files,
        contains('lib/src/presentation/pages/profile/profile_view.dart'),
      );
      expect(
        files,
        contains('lib/src/presentation/pages/profile/profile_presenter.dart'),
      );
      // The profile view's bare barrel import pulls its two referenced widgets.
      expect(files, contains('lib/src/presentation/widgets/app_card.dart'));
      expect(
        files,
        contains('lib/src/presentation/widgets/primary_button.dart'),
      );

      // Shared dependencies appear EXACTLY once across both trees.
      final sharedUsecase = files
          .where(
            (f) =>
                f ==
                'lib/src/domain/usecases/shared/fetch_settings_usecase.dart',
          )
          .toList();
      expect(sharedUsecase, hasLength(1));
      final sharedWidget = files
          .where((f) => f == 'lib/src/presentation/widgets/primary_button.dart')
          .toList();
      expect(sharedWidget, hasLength(1));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('A12 (T098): the shared usecase and its DI registration appear once '
      'in the manifest', () async {
    await captureOutput(
      () => runner.run([
        'slice',
        'cut',
        'profile_flow',
        '--entry',
        'product',
        '--entry',
        'profile',
      ]),
    );

    final content = File(
      '$projectRoot/.zuraffa/slices/profile_flow/slice.yaml',
    ).readAsStringSync();
    final doc = loadYaml(content) as Map;
    final files = doc['files'] as List;

    final sharedUsecaseEntries = files
        .whereType<Map>()
        .where(
          (f) =>
              f['path'] ==
              'lib/src/domain/usecases/shared/fetch_settings_usecase.dart',
        )
        .toList();
    expect(sharedUsecaseEntries, hasLength(1));

    final sharedDiEntries = files
        .whereType<Map>()
        .where(
          (f) =>
              f['path'] == 'lib/src/di/usecases/fetch_settings_usecase_di.dart',
        )
        .toList();
    expect(sharedDiEntries, hasLength(1));

    // Both entries are recorded.
    expect(doc['entries'], hasLength(2));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the multi-entry main_slice exposes both roots', () async {
    await captureOutput(
      () => runner.run([
        'slice',
        'cut',
        'profile_flow',
        '--entry',
        'product',
        '--entry',
        'profile',
      ]),
    );

    final mainSlice = File(
      '$projectRoot/.zuraffa/slices/profile_flow/main_slice.dart',
    ).readAsStringSync();
    expect(mainSlice, contains('ProductView'));
    expect(mainSlice, contains('ProfileView'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
