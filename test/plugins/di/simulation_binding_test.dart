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
      'class $entity {\n'
      '  final String id;\n'
      '  const $entity(this.id);\n'
      '  $entity copyWithField(Object field, Object? value) => this;\n'
      '}\n'
      'class ${entity}Patch {}\n',
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

  group('Issue #1031: service-mode simulation binding shape', () {
    /// Mirrors the issue repro:
    /// `zfa mock create --name Auth --service Auth --params AuthRequest
    ///  --returns User --domain auth` (service mode: no CRUD methods,
    /// mock lane generates `AuthMockProvider`, no datasource pair).
    Future<void> runServiceMockCreate() => mockPlugin().generate(
      GeneratorConfig(
        name: 'Auth',
        service: 'Auth',
        domain: 'auth',
        paramsType: 'AuthRequest',
        returnsType: 'User',
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    test(
      '#1031: service-mode mock create emits the service-shaped simulation binding, not the datasource shape',
      () async {
        await runServiceMockCreate();

        final serviceBinding = File(
          '$outputDir/di/simulation/auth_simulation_service_di.dart',
        );
        expect(
          serviceBinding.existsSync(),
          isTrue,
          reason:
              'service mode must emit <name>_simulation_service_di.dart '
              '(#1031): the binding must follow the service shape the mock '
              'lane actually generated',
        );

        final content = serviceBinding.readAsStringSync();
        expect(
          content,
          contains('void registerAuthSimulationService(GetIt getIt)'),
        );
        // Single --dart-define flavor switch, same as the datasource lane.
        expect(content, contains('if (!kSimulationMode) return;'));
        // Interface binding to the production service interface, served by
        // the generated mock provider.
        expect(content, contains('registerLazySingleton<AuthService>'));
        expect(content, contains('() => AuthMockProvider()'));
        // Imports resolve to the files the service lane actually generated.
        expect(
          content,
          contains("import '../../domain/services/auth_service.dart';"),
        );
        expect(
          content,
          contains(
            "import '../../data/providers/auth/auth_mock_provider.dart';",
          ),
        );
        expect(content, contains('package:zuraffa/simulation.dart'));

        // The datasource-shaped binding references AuthDataSource /
        // AuthMockDataSource, which are never generated in service mode —
        // emitting it is the #1031 bug.
        expect(
          File(
            '$outputDir/di/simulation/auth_simulation_datasource_di.dart',
          ).existsSync(),
          isFalse,
          reason:
              'service mode must not emit the datasource-shaped binding '
              '(#1031): its imports cannot resolve there',
        );
      },
    );

    test(
      '#1031: simulation index registers the service-shaped binding',
      () async {
        await runServiceMockCreate();

        final index = simulationIndexFile();
        expect(index.existsSync(), isTrue);
        final content = index.readAsStringSync();
        expect(content, contains('registerAuthSimulationService(getIt);'));
        expect(content, contains("import 'auth_simulation_service_di.dart';"));
      },
    );

    test(
      '#1031: datasource lane unchanged — entity-mode mock create never emits the service shape',
      () async {
        await runMockCreate('Todo');

        expect(simulationBindingFile('todo').existsSync(), isTrue);
        expect(
          File(
            '$outputDir/di/simulation/todo_simulation_service_di.dart',
          ).existsSync(),
          isFalse,
          reason: 'without a service the datasource shape stays authoritative',
        );
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

  // Issue #2119 — the generated composition root must preserve the
  // runtime registration order. Simulation bindings OVERRIDE the real
  // bindings (they rebind an interface to its generated mock), so
  // `registerSimulationBindings` must be called AFTER every real binding
  // category (datasources, repositories, services, providers) — never in
  // the middle. A `zfa make ... --force` run used to alphabetically/
  // structurally rewrite the index and drop the simulation call in the
  // middle, reversing the established override order and breaking GetIt
  // dependency resolution at runtime (static analysis could not catch it).
  group('issue 2119: composition-root registration order is preserved', () {
    Future<String> generateCompositionRoot({required bool force}) async {
      await DiPlugin(
        outputDir: outputDir,
        options: GeneratorOptions(dryRun: false, force: force),
      ).generate(
        GeneratorConfig(
          name: 'Customer',
          methods: const ['get'],
          generateData: true,
          generateDataSource: true,
          generateRepository: true,
          useMockInDi: true,
          generateDi: true,
          outputDir: outputDir,
        ),
      );
      return mainIndexFile().readAsStringSync();
    }

    int indexOfCall(String content, String call) =>
        content.indexOf('$call(getIt);');

    int simulationCallCount(String content) =>
        'registerSimulationBindings(getIt);'.allMatches(content).length;

    for (final force in [false, true]) {
      final label = force ? 'force rewrite' : 'incremental append';
      test(
        'registerSimulationBindings comes after the real bindings ($label)',
        () async {
          final content = await generateCompositionRoot(force: force);

          final dataSources = indexOfCall(content, 'registerAllDataSources');
          final repositories = indexOfCall(content, 'registerAllRepositories');
          final simulation = indexOfCall(content, 'registerSimulationBindings');

          expect(dataSources, isNonNegative, reason: 'datasource call missing');
          expect(
            repositories,
            isNonNegative,
            reason: 'repository call missing',
          );
          expect(simulation, isNonNegative, reason: 'simulation call missing');

          // Simulation overrides the real bindings — it must be LAST.
          expect(
            simulation,
            greaterThan(repositories),
            reason:
                'registerSimulationBindings must come AFTER '
                'registerAllRepositories (issue #2119: the simulation '
                'mocks override the real registrations, so a mid-chain '
                'position breaks GetIt resolution). Order was: '
                'dataSources=$dataSources repositories=$repositories '
                'simulation=$simulation',
          );
          expect(
            simulation,
            greaterThan(dataSources),
            reason:
                'registerSimulationBindings must come AFTER '
                'registerAllDataSources',
          );
        },
      );
    }

    test('incremental append migrates a pre-fix index with a mid-chain '
        'simulation call (issue #2119)', () async {
      // Seed a di/index.dart in the exact shape the pre-fix generator
      // emitted — registerSimulationBindings in the MIDDLE, before
      // registerAllRepositories — then re-run WITHOUT --force so
      // _regenerateMainIndex takes the incremental _updateIndexFile
      // path (the documented default; --force is opt-in).
      final mainIndex = mainIndexFile();
      mainIndex.parent.createSync(recursive: true);
      mainIndex.writeAsStringSync(
        "import 'package:zuraffa/zuraffa.dart';\n"
        'import "datasources/index.dart";\n'
        'import "repositories/index.dart";\n'
        'import "simulation/index.dart";\n'
        '\n'
        'void setupDependencies(GetIt getIt) {\n'
        '  registerAllDataSources(getIt);\n'
        '  registerSimulationBindings(getIt);\n'
        '  registerAllRepositories(getIt);\n'
        '}\n',
      );

      final content = await generateCompositionRoot(force: false);

      final dataSources = indexOfCall(content, 'registerAllDataSources');
      final repositories = indexOfCall(content, 'registerAllRepositories');
      final simulation = indexOfCall(content, 'registerSimulationBindings');

      expect(dataSources, isNonNegative, reason: 'datasource call missing');
      expect(repositories, isNonNegative, reason: 'repository call missing');
      expect(simulation, isNonNegative, reason: 'simulation call missing');
      expect(
        simulation,
        greaterThan(repositories),
        reason:
            'the incremental (force:false) path must reorder a '
            'pre-fix mid-chain registerSimulationBindings to the end '
            '(issue #2119). Order was: '
            'dataSources=$dataSources repositories=$repositories '
            'simulation=$simulation',
      );
      // A reorder, not a duplicate: the simulation call appears once.
      expect(
        simulationCallCount(content),
        1,
        reason: 'registerSimulationBindings must not be duplicated',
      );
    });
  });
}
