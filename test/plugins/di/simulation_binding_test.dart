// Spec 893 — generated simulation DI bindings (T002).
//
// FR-002: simulation DI bindings are generated as part of the standard
// `zfa make --di` and `zfa mock create` workflows — zero manual
// registration. FR-003: every mock datasource is registered under the
// simulation flavor. FR-011/SC-006: simulation-generated bindings are
// distinguishable from hand-written ones. The flavor switch is a single
// `--dart-define=SIMULATION=true` (FR-001), evaluated in the generated
// code itself — never hand-wired.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_893_di_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DiPlugin diPlugin() => DiPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: false),
  );

  MockPlugin mockPlugin() => MockPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: false),
  );

  File simulationBindingFile(String entitySnake) => File(
    '$outputDir/di/simulation/${entitySnake}_simulation_datasource_di.dart',
  );

  File simulationIndexFile() => File('$outputDir/di/simulation/index.dart');

  File mainIndexFile() => File('$outputDir/di/index.dart');

  /// Seeds the domain entity the way real projects (and the existing
  /// mock-builder tests) provide it before `zfa mock create` runs.
  Future<void> runMockCreate(String entity) async {
    final entitySnake = entity.toLowerCase();
    final entityDir = Directory('$outputDir/domain/entities/$entitySnake');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/$entitySnake.dart').writeAsString(
      'class $entity { final String id; const $entity(this.id); }',
    );
    await mockPlugin().generate(
      GeneratorConfig(
        name: entity,
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );
  }

  Future<void> runMakeDiWithMock() => diPlugin().generate(
    GeneratorConfig(
      name: 'Cart',
      methods: const ['get'],
      generateData: true,
      generateDi: true,
      useMockInDi: true,
      outputDir: outputDir,
    ),
  );

  group('A2: simulation bindings are generated, not hand-wired', () {
    test(
      'A2: zfa mock create and zfa make --di generate the simulation binding without manual wiring',
      () async {
        await runMockCreate('Todo');

        final binding = simulationBindingFile('todo');
        expect(
          binding.existsSync(),
          isTrue,
          reason: 'zfa mock create must emit the di/simulation/ binding',
        );

        final index = simulationIndexFile();
        expect(
          index.existsSync(),
          isTrue,
          reason: 'simulation index (registerSimulationBindings) must exist',
        );

        // Running the standard `zfa make --di` workflow (useMockInDi) must
        // produce the same generated simulation surface with zero manual
        // registration code.
        final makeOutputDir = Directory('${tempDir.path}/lib2/src').path;
        await DiPlugin(
          outputDir: makeOutputDir,
          options: const GeneratorOptions(dryRun: false, force: false),
        ).generate(
          GeneratorConfig(
            name: 'Cart',
            methods: const ['get'],
            generateData: true,
            generateDi: true,
            useMockInDi: true,
            outputDir: makeOutputDir,
          ),
        );
        expect(
          File(
            '$makeOutputDir/di/simulation/cart_simulation_datasource_di.dart',
          ).existsSync(),
          isTrue,
          reason: 'zfa make --di must emit the simulation binding',
        );
      },
    );

    test(
      'U3: generated binding registers the mock under the interface behind the flavor guard',
      () async {
        await runMockCreate('Todo');

        final content = simulationBindingFile('todo').readAsStringSync();
        // Interface binding, not just the concrete mock type: simulation
        // mode serves every consumer resolving the production datasource
        // type.
        expect(content, contains('registerLazySingleton<TodoDataSource>'));
        expect(content, contains('() => TodoMockDataSource()'));
        // Single --dart-define flavor switch, generated not hand-wired.
        expect(content, contains('if (!kSimulationMode) return;'));
        // Runtime surface comes from the public simulation barrel.
        expect(content, contains('package:zuraffa/simulation.dart'));
      },
    );

    test(
      'U4: simulation index runs the flag-conflict gate before registering bindings',
      () async {
        await runMockCreate('Todo');

        final content = simulationIndexFile().readAsStringSync();
        expect(
          content,
          contains('void registerSimulationBindings(GetIt getIt)'),
        );
        expect(content, contains('SimulationFlavor.checkFlagConflicts()'));
        expect(content, contains('registerTodoSimulationDataSource(getIt);'));
      },
    );

    test(
      'U6: main di index wires registerSimulationBindings into setupDependencies',
      () async {
        await runMakeDiWithMock();

        final content = mainIndexFile().readAsStringSync();
        expect(content, contains('setupDependencies'));
        expect(content, contains("import 'simulation/index.dart';"));
        expect(content, contains('registerSimulationBindings(getIt);'));
      },
    );

    test('second entity extends the simulation index automatically', () async {
      await runMockCreate('Todo');
      await runMockCreate('Order');

      final content = simulationIndexFile().readAsStringSync();
      expect(content, contains('registerTodoSimulationDataSource(getIt);'));
      expect(content, contains('registerOrderSimulationDataSource(getIt);'));
      expect(content, contains("import 'todo_simulation_datasource_di.dart';"));
      expect(
        content,
        contains("import 'order_simulation_datasource_di.dart';"),
      );
    });
  });

  group('A3: distinguishability', () {
    test(
      'A3: simulation bindings are distinguishable by location and generated markers',
      () async {
        await runMockCreate('Todo');

        // FR-011: dedicated generated location + explicit markers.
        expect(
          simulationBindingFile('todo').path,
          contains(
            '${Platform.pathSeparator}di${Platform.pathSeparator}simulation',
          ),
        );
        final content = simulationBindingFile('todo').readAsStringSync();
        expect(content, contains('SIMULATION BINDING'));
        expect(content, contains('GENERATED - DO NOT EDIT'));
        expect(content, contains('spec 893'));
      },
    );
  });

  group('U5: real adapters under the simulation flavor', () {
    test(
      'U5: real datasource registration is guarded against the simulation flavor',
      () async {
        await diPlugin().generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get'],
            generateData: true,
            generateDi: true,
            outputDir: outputDir,
          ),
        );

        final remote = File(
          '$outputDir/di/datasources/product_remote_datasource_di.dart',
        );
        expect(remote.existsSync(), isTrue);
        final content = remote.readAsStringSync();
        // Edge case: the presence of a real adapter must not interfere
        // with the simulation flavor bindings — real adapters never
        // register when the app is compiled for simulation.
        expect(content, contains('if (kSimulationMode) return;'));
        expect(content, contains('package:zuraffa/simulation.dart'));
      },
    );
  });
}
