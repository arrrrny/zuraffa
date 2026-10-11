// Issue #1194 follow-up — the mocked tier must actually BOOT under
// `--dart-define=SIMULATION=true`. Found live in the zik_zak sandbox:
//
// 1. the repository DI resolved the CONCRETE `DealRemoteDataSource`,
//    but the simulation tier registers the certified mock under the
//    ABSTRACT `DealDataSource` — in simulation mode nothing registered
//    the concrete, so the first resolution crashed
//    (`DealRemoteDataSource is not registered`) and the app showed a
//    black screen;
// 2. the simulation binding had no unregister-first guard, so a caller
//    invoking `registerSimulationBindings` after `setupDependencies`
//    (which chains it) threw `already registered`.
//
// These pins hold the emitted wiring to the flavor-coherent shape:
// the repository resolves the ABSTRACT; the remote DI registers
// concrete AND abstract→remote behind the real-flavor guard; the
// simulation binding is unregister-first inside the sim guard.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1194_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> generateDi() async {
    await DiPlugin(
      outputDir: tempDir.path,
      options: const GeneratorOptions(dryRun: false, force: true),
    ).generate(
      GeneratorConfig(
        name: 'Deal',
        methods: const ['get', 'getList'],
        generateData: true,
        generateRepository: true,
        generateDi: true,
        generateMock: true,
        outputDir: tempDir.path,
      ),
    );
  }

  test('the repository DI resolves the ABSTRACT datasource '
      '(the flavor decides which impl serves it)', () async {
    await generateDi();
    final src = File(
      '${tempDir.path}/di/repositories/deal_repository_di.dart',
    ).readAsStringSync();
    expect(src, contains("getIt<DealDataSource>()"));
    expect(
      src,
      isNot(contains('getIt<DealRemoteDataSource>()')),
      reason:
          'pinning the concrete breaks the simulation tier — '
          'nothing registers it under SIMULATION=true',
    );
  });

  test('the remote DI registers concrete AND abstract→remote behind the '
      'real-flavor guard', () async {
    await generateDi();
    final src = File(
      '${tempDir.path}/di/datasources/deal_remote_datasource_di.dart',
    ).readAsStringSync();
    expect(src, contains('if (kSimulationMode) return;'));
    expect(src, contains('registerLazySingleton<DealRemoteDataSource>'));
    expect(src, contains('registerLazySingleton<DealDataSource>'));
    expect(
      src,
      contains('getIt<DealRemoteDataSource>()'),
      reason: 'the abstract delegates to the concrete remote',
    );
  });

  test(
    'the simulation binding is unregister-first inside the sim guard',
    () async {
      await generateDi();
      final src = File(
        '${tempDir.path}/di/simulation/deal_simulation_datasource_di.dart',
      ).readAsStringSync();
      final guard = RegExp(
        r'if \(getIt\.isRegistered<DealDataSource>\(\)\)\s*\{?\s*'
        r'getIt\.unsubscribe<DealDataSource>\(\);?\s*'
        r'getIt\.unregister<DealDataSource>\(\);?\s*\}?',
      );
      expect(
        guard.hasMatch(src) ||
            src.contains(
              'if (getIt.isRegistered<DealDataSource>()) getIt.unregister<DealDataSource>();',
            ),
        isTrue,
        reason:
            'a second registerSimulationBindings call (the composition '
            'root chains it) must re-register, not throw',
      );
      expect(src, contains('if (!kSimulationMode) return;'));
    },
  );
}
