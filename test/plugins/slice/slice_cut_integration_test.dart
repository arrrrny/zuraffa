/// Acceptance tests for `zfa slice cut` (A1, A2, A3, A4; gates T087-T090).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   A1: `slice cut` on a profile-like page produces a sandbox with
///       view/controller/presenter/state/usecases/entities/mock DI/entry
///       point and no unrelated files
///   A2: A cut including widgets used by other features includes them and
///       classifies them `shared` in slice.yaml
///   A3: A presenter resolving usecases via `getIt<T>()` gets those usecase
///       types and their DI registration files included
///   A4: A barrel (`index.dart`) import pulls in only the re-exported
///       symbols the slice actually references
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
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

  /// All files under the sandbox (relative to the sandbox root, '/'-joined).
  Set<String> sandboxFiles() {
    final root = Directory(sandbox());
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .map(
          (f) =>
              f.path.substring(root.path.length + 1).replaceAll('\\', '/'),
        )
        .toSet();
  }

  /// The parsed slice.yaml manifest.
  Map<String, dynamic> manifest() {
    final content = File('${sandbox()}/slice.yaml').readAsStringSync();
    final doc = loadYaml(content) as Map;
    return {
      for (final entry in doc.entries)
        entry.key.toString(): entry.value,
    };
  }

  group('slice cut acceptance (US1)', () {
    test(
      'A1 (T087): cut produces the complete sandbox and nothing unrelated',
      () async {
        final output = await captureOutput(
          () => runner.run([
            'slice',
            'cut',
            'product_feature',
            '--entry',
            'product',
          ]),
        );

        expect(command.exitCode, equals(0), reason: output);

        final files = sandboxFiles();
        // The page itself.
        expect(files, contains('lib/src/presentation/pages/product/product_view.dart'));
        expect(files, contains('lib/src/presentation/pages/product/product_controller.dart'));
        expect(files, contains('lib/src/presentation/pages/product/product_presenter.dart'));
        expect(files, contains('lib/src/presentation/pages/product/product_state.dart'));
        // Domain pulled via imports and getIt<T>().
        expect(files, contains('lib/src/domain/usecases/product/get_product_usecase.dart'));
        expect(files, contains('lib/src/domain/usecases/product/update_product_usecase.dart'));
        expect(files, contains('lib/src/domain/usecases/shared/fetch_settings_usecase.dart'));
        expect(files, contains('lib/src/domain/entities/product/product.dart'));
        expect(files, contains('lib/src/domain/entities/product/product.g.dart'));
        expect(files, contains('lib/src/domain/repositories/product_repository.dart'));
        // Mock DI wiring and the runnable entry point.
        expect(files, contains('lib/src/di/slice_di.dart'));
        expect(files, contains('lib/src/mocks/mock_product_repository.dart'));
        expect(files, contains('main_slice.dart'));
        expect(files, contains('SLICE.md'));
        expect(files, contains('slice.yaml'));
        // And nothing unrelated.
        expect(files, isNot(contains('lib/src/presentation/pages/profile/profile_view.dart')));
        expect(files, isNot(contains('lib/src/data/repositories/data_product_repository.dart')));
        expect(files, isNot(contains('lib/src/data/datasources/product_remote_datasource.dart')));
        expect(files, isNot(contains('lib/src/presentation/widgets/secondary_button.dart')));
        expect(files, isNot(contains('lib/src/presentation/widgets/loading_indicator.dart')));
        expect(files, isNot(contains('lib/src/presentation/widgets/app_card.dart')));
        expect(files, isNot(contains('lib/main.dart')));
        // The cut summary names the slice and its file count.
        expect(output, contains('product_feature'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('A2 (T087/T088): shared widget included and classified shared in '
        'slice.yaml', () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      final files = sandboxFiles();
      expect(files, contains('lib/src/presentation/widgets/primary_button.dart'));

      final filesNode = manifest()['files'] as List;
      final byPath = {
        for (final entry in filesNode.whereType<Map>())
          entry['path'].toString(): entry['ownership'].toString(),
      };
      expect(byPath['lib/src/presentation/widgets/primary_button.dart'], equals('shared'));
      expect(
        byPath['lib/src/presentation/pages/product/product_view.dart'],
        equals('owned'),
      );
      expect(
        byPath['lib/src/domain/entities/product/product.dart'],
        equals('shared'),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A3 (T089): getIt-resolved usecases and their DI files are '
        'included', () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      final files = sandboxFiles();
      expect(files, contains('lib/src/di/usecases/get_product_usecase_di.dart'));
      expect(files, contains('lib/src/di/usecases/update_product_usecase_di.dart'));
      expect(files, contains('lib/src/di/usecases/fetch_settings_usecase_di.dart'));

      // The generated slice_di delegates real wiring to those files and
      // registers the boundary mock.
      final sliceDi = File('${sandbox()}/lib/src/di/slice_di.dart')
          .readAsStringSync();
      expect(sliceDi, contains('registerGetProductUseCase(getIt);'));
      expect(sliceDi, contains('MockProductRepository'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A4 (T090): a barrel import pulls only the referenced symbols',
        () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      final files = sandboxFiles();
      // product_view imports the widgets barrel with `show PrimaryButton`.
      expect(files, contains('lib/src/presentation/widgets/primary_button.dart'));
      expect(files, isNot(contains('lib/src/presentation/widgets/secondary_button.dart')));
      expect(files, isNot(contains('lib/src/presentation/widgets/loading_indicator.dart')));
      expect(files, isNot(contains('lib/src/presentation/widgets/app_card.dart')));
      // The barrel itself is mirrored FILTERED: it exports only the symbol
      // the slice references, so the import resolves without dragging in
      // the barrel's other contents (FR-005).
      final barrel = File('${sandbox()}/lib/src/presentation/widgets/index.dart')
          .readAsStringSync();
      expect(barrel, contains("export 'primary_button.dart';"));
      expect(barrel, isNot(contains('secondary_button')));
      expect(barrel, isNot(contains('loading_indicator')));
      expect(barrel, isNot(contains('app_card')));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A1: main_slice.dart wires the entry view with mock DI', () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      final mainSlice = File('${sandbox()}/main_slice.dart').readAsStringSync();
      expect(
        mainSlice,
        contains(
          "import 'package:zik_zak/src/presentation/pages/product/product_view.dart';",
        ),
      );
      expect(mainSlice, contains('setupSliceDependencies()'));
      expect(mainSlice, contains('runApp('));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('A1: slice.yaml records hashes and boundaries at feature depth',
        () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      final doc = manifest();
      expect(doc['name'], equals('product_feature'));
      expect(doc['depth'], equals('feature'));
      expect(doc['packageName'], equals('zik_zak'));
      expect(
        doc['entries'],
        equals(['lib/src/presentation/pages/product/product_view.dart']),
      );

      final filesNode = doc['files'] as List;
      final viewEntry = filesNode
          .whereType<Map>()
          .singleWhere((f) => f['path'].toString().contains('product_view.dart'));
      // SHA-256 hex of the fixture's view file.
      expect(viewEntry['hashAtCut'], matches(RegExp(r'^[0-9a-f]{64}$')));

      final boundaries = doc['boundaries'] as List;
      final repoBoundary = boundaries
          .whereType<Map>()
          .singleWhere((b) => b['typeName'] == 'ProductRepository');
      expect(
        repoBoundary['interfaceFile'],
        equals('lib/src/domain/repositories/product_repository.dart'),
      );
      expect(repoBoundary['mockStrategy'], equals('auto'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('cutting into an existing slice name fails without clobbering',
        () async {
      await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );
      final before = sandboxFiles();

      final output = await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'product']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('already exists'));
      expect(sandboxFiles(), equals(before));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a missing entry fails with alternatives, never a stack trace',
        () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'cut', 'product_feature', '--entry', 'ghost']),
      );

      expect(command.exitCode, equals(1));
      expect(output, contains('ghost'));
      expect(output, contains('product'));
      expect(output, contains('profile'));
      expect(output, isNot(contains('Stack trace')));
      expect(output, isNot(contains('#0')));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
