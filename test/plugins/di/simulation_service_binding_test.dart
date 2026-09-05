// Bug #1031 — service-mode `zfa mock create` emitted a datasource-shaped
// simulation binding (`<Entity>DataSource` / `<Entity>MockDataSource`)
// referencing classes that are never generated in service mode.
//
// In service mode the mock plugin generates `<Name>MockProvider`
// (data/providers/<domain>/) implementing `<Name>Service` — no datasource
// surface exists. The simulation binding must therefore follow the service
// shape, mirroring how the datasource lane binds
// `<Entity>DataSource → <Entity>MockDataSource` behind the SIMULATION
// flavor switch (spec 893):
//
//   void register<Name>SimulationService(GetIt getIt) {
//     if (!kSimulationMode) return;
//     getIt.registerLazySingleton<<Name>Service>(() => <Name>MockProvider());
//   }
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_1031_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MockPlugin mockPlugin() => MockPlugin(
    outputDir: outputDir,
    options: const GeneratorOptions(dryRun: false, force: false),
  );

  /// Seeds the service interface the way `zfa service create Auth` emits it
  /// (flat under domain/services/ — the service-create config is not
  /// entity-based) before `zfa mock create --service Auth` runs.
  Future<void> seedAuthService({String? domain}) async {
    final dir = domain == null
        ? Directory('$outputDir/domain/services')
        : Directory('$outputDir/domain/services/$domain');
    await dir.create(recursive: true);
    await File('${dir.path}/auth_service.dart').writeAsString(
      'abstract class AuthService { Future<User> execute(AuthRequest p); }',
    );
  }

  /// Runs `zfa mock create --name Auth --service Auth --params AuthRequest
  /// --returns User --domain auth` the way MockPlugin wires the CLI config
  /// (service mode ⇒ methods == []).
  Future<void> runServiceMockCreate() => mockPlugin().generate(
    GeneratorConfig(
      name: 'Auth',
      service: 'Auth',
      methods: const [],
      paramsType: 'AuthRequest',
      returnsType: 'User',
      domain: 'auth',
      generateMock: true,
      outputDir: outputDir,
    ),
  );

  /// Runs datasource-mode `zfa mock create --name Todo` (the spec 893 lane
  /// that must not change).
  Future<void> runDatasourceMockCreate(String entity) async {
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

  File serviceBindingFile() =>
      File('$outputDir/di/simulation/auth_simulation_service_di.dart');

  File datasourceBindingFile() =>
      File('$outputDir/di/simulation/auth_simulation_datasource_di.dart');

  File simulationIndexFile() => File('$outputDir/di/simulation/index.dart');

  group('#1031: service-mode simulation binding shape', () {
    test(
      'emits a service-shaped simulation binding, not datasource-shaped',
      () async {
        await seedAuthService();
        await runServiceMockCreate();

        final binding = serviceBindingFile();
        expect(
          binding.existsSync(),
          isTrue,
          reason:
              'service-mode mock create must emit the service-shaped '
              'simulation binding auth_simulation_service_di.dart',
        );

        final content = binding.readAsStringSync();
        // The service shape: <Name>Service → <Name>MockProvider behind the
        // single SIMULATION flavor switch, exactly mirroring the datasource
        // lane's register<Entity>SimulationDataSource.
        expect(
          content,
          contains('void registerAuthSimulationService(GetIt getIt)'),
        );
        expect(content, contains('registerLazySingleton<AuthService>'));
        expect(content, contains('() => AuthMockProvider()'));
        expect(content, contains('if (!kSimulationMode) return;'));
        // Runtime surface comes from the public simulation barrel.
        expect(content, contains('package:zuraffa/simulation.dart'));
        // The binding imports the service interface and the mock provider
        // that service-mode actually generates.
        expect(content, contains('../../domain/services/auth_service.dart'));
        expect(
          content,
          contains('../../data/providers/auth/auth_mock_provider.dart'),
        );
        // The datasource shape must be gone: those classes are never
        // generated in service mode (the #1031 uri_does_not_exist lie).
        expect(content, isNot(contains('AuthDataSource')));
        expect(content, isNot(contains('AuthMockDataSource')));
        expect(
          content,
          isNot(contains('data/datasources')),
          reason: 'service-mode binding must not import datasource files',
        );
      },
    );

    test(
      'does not also emit the datasource-shaped binding in service mode',
      () async {
        await seedAuthService();
        await runServiceMockCreate();

        expect(
          datasourceBindingFile().existsSync(),
          isFalse,
          reason:
              'the datasource-shaped binding binds interfaces that were '
              'never generated — it must not be emitted in service mode',
        );
      },
    );

    test('resolves a domain-scoped service interface import', () async {
      // Services created entity-based (with a domain) live under
      // domain/services/<domain>/ — the binding must import that location.
      final entityDir = Directory('$outputDir/domain/entities/user');
      await entityDir.create(recursive: true);
      await File('${entityDir.path}/user.dart').writeAsString(
        'class User { final String id; const User(this.id); }',
      );
      await seedAuthService(domain: 'auth');
      await mockPlugin().generate(
        GeneratorConfig(
          name: 'Auth',
          service: 'Auth',
          methods: const [],
          paramsType: 'AuthRequest',
          returnsType: 'User',
          domain: 'auth',
          generateMock: true,
          outputDir: outputDir,
        ),
      );

      final content = serviceBindingFile().readAsStringSync();
      expect(
        content,
        contains('../../domain/services/auth/auth_service.dart'),
      );
    });

    test('wires the service binding into the simulation index', () async {
      await seedAuthService();
      await runServiceMockCreate();

      final index = simulationIndexFile();
      expect(index.existsSync(), isTrue);
      final content = index.readAsStringSync();
      expect(
        content,
        contains('void registerSimulationBindings(GetIt getIt)'),
      );
      expect(content, contains('registerAuthSimulationService(getIt);'));
      expect(content, contains("import 'auth_simulation_service_di.dart';"));
    });

    test(
      'datasource mode is unchanged: entity mock create still emits the datasource-shaped binding',
      () async {
        await runDatasourceMockCreate('Todo');

        final binding = File(
          '$outputDir/di/simulation/todo_simulation_datasource_di.dart',
        );
        expect(binding.existsSync(), isTrue);
        final content = binding.readAsStringSync();
        expect(content, contains('registerLazySingleton<TodoDataSource>'));
        expect(content, contains('() => TodoMockDataSource()'));
        expect(content, contains('registerTodoSimulationDataSource'));
        // No service-shaped file may appear for the datasource lane.
        expect(
          File(
            '$outputDir/di/simulation/todo_simulation_service_di.dart',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('service and datasource bindings coexist in the simulation index',
        () async {
      await runDatasourceMockCreate('Todo');
      await seedAuthService();
      await runServiceMockCreate();

      final content = simulationIndexFile().readAsStringSync();
      expect(content, contains('registerTodoSimulationDataSource(getIt);'));
      expect(content, contains('registerAuthSimulationService(getIt);'));
    });
  });
}
