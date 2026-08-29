/// Acceptance tests for depth levels (A13, A14, A15; gates T099-T101).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A13: `--depth view` includes view/controller/state and no presenter,
///        usecases, or entities
///   A14: `--depth feature` (default) adds presenter/usecases/domain
///        interfaces/entities but no data implementations
///   A15: `--depth full` additionally includes repository implementations,
///        datasources, and providers
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

  Future<Set<String>> cutAtDepth(String depthFlag) async {
    final args = [
      'slice',
      'cut',
      'product_feature',
      '--entry',
      'product',
      if (depthFlag.isNotEmpty) ...['--depth', depthFlag],
    ];
    final output = await captureOutput(() => runner.run(args));
    expect(command.exitCode, equals(0), reason: output);

    final sandbox = '$projectRoot/.zuraffa/slices/product_feature';
    return Directory(sandbox)
        .listSync(recursive: true)
        .whereType<File>()
        .map(
          (f) => f.path.substring(sandbox.length + 1).replaceAll('\\', '/'),
        )
        .toSet();
  }

  test('A13 (T099): depth view — view/controller/state, no deeper layers',
      () async {
    final files = await cutAtDepth('view');

    expect(files, contains('lib/src/presentation/pages/product/product_view.dart'));
    expect(files, contains('lib/src/presentation/pages/product/product_controller.dart'));
    expect(files, contains('lib/src/presentation/pages/product/product_state.dart'));
    expect(files, contains('lib/src/presentation/widgets/primary_button.dart'));
    // No presenter, usecases, entities, data.
    expect(files, isNot(contains('lib/src/presentation/pages/product/product_presenter.dart')));
    expect(
      files,
      isNot(contains('lib/src/domain/usecases/product/get_product_usecase.dart')),
    );
    expect(files, isNot(contains('lib/src/domain/entities/product/product.dart')));
    expect(
      files,
      isNot(contains('lib/src/data/repositories/data_product_repository.dart')),
    );
    // At view depth the presenter is the mocked boundary (U31).
    expect(files, contains('lib/src/mocks/mock_product_presenter.dart'));
    final sliceDi = File(
      '$projectRoot/.zuraffa/slices/product_feature/lib/src/di/slice_di.dart',
    ).readAsStringSync();
    expect(sliceDi, contains('MockProductPresenter'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('A14 (T100): depth feature (default) — domain in, data out',
      () async {
    final files = await cutAtDepth('');

    expect(files, contains('lib/src/presentation/pages/product/product_presenter.dart'));
    expect(files, contains('lib/src/domain/usecases/product/get_product_usecase.dart'));
    expect(files, contains('lib/src/domain/entities/product/product.dart'));
    expect(files, contains('lib/src/domain/repositories/product_repository.dart'));
    expect(
      files,
      isNot(contains('lib/src/data/repositories/data_product_repository.dart')),
    );
    expect(
      files,
      isNot(contains('lib/src/data/datasources/product_remote_datasource.dart')),
    );
    expect(
      files,
      isNot(contains('lib/src/di/repositories/product_repository_di.dart')),
    );
    // The repository interface is the mocked boundary at feature depth.
    expect(files, contains('lib/src/mocks/mock_product_repository.dart'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('A15 (T101): depth full — data implementations included, no mocks',
      () async {
    final files = await cutAtDepth('full');

    expect(files, contains('lib/src/data/repositories/data_product_repository.dart'));
    expect(files, contains('lib/src/data/datasources/product_remote_datasource.dart'));
    expect(files, contains('lib/src/di/repositories/product_repository_di.dart'));
    // No mocks at full depth (U31).
    expect(
      files,
      isNot(contains('lib/src/mocks/mock_product_repository.dart')),
    );
    final sliceDi = File(
      '$projectRoot/.zuraffa/slices/product_feature/lib/src/di/slice_di.dart',
    ).readAsStringSync();
    expect(sliceDi, contains('registerProductRepository(getIt);'));
    expect(sliceDi, isNot(contains('MockProductRepository')));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('an invalid depth is a usage error listing the valid values',
      () async {
    final output = await captureOutput(
      () => runner.run([
        'slice',
        'cut',
        'x',
        '--entry',
        'product',
        '--depth',
        'sideways',
      ]),
    );

    expect(command.exitCode, equals(64));
    expect(output, contains('depth'));
    expect(output, contains('view'));
    expect(output, contains('full'));
  });
}
