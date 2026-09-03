// Spec 893 — simulation boot + demoability proof (T005).
//
// US1/SC-001/SC-002: the application boots end-to-end on certified mocks
// with fixture data and zero real sockets. FR-009: missing or corrupt
// fixtures fail the boot naming the entity. FR-010: zero complete(mocked)
// features produce a warning. FR-008: the boot is a no-op outside the
// simulation flavor.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/simulation.dart';
import 'package:zuraffa/zuraffa.dart';

// ---------------------------------------------------------------------------
// A generated-style mock graph, mirroring the shapes `zfa make --di` /
// `zfa mock create` emit: interface + mock datasource (serving the
// committed fixture records) + data repository + use case.
class _Todo {
  const _Todo(this.id, this.title, this.done);
  final String id;
  final String title;
  final bool done;

  factory _Todo.fromJson(Map<String, dynamic> json) => _Todo(
    json['id'] as String,
    json['title'] as String,
    json['done'] as bool,
  );
}

abstract class _TodoDataSource {
  Future<List<Map<String, dynamic>>> getList();
}

class _TodoMockDataSource implements _TodoDataSource {
  _TodoMockDataSource({required List<Map<String, dynamic>> records})
    : _records = records;

  final List<Map<String, dynamic>> _records;

  @override
  Future<List<Map<String, dynamic>>> getList() async => _records;
}

class _DataTodoRepository {
  _DataTodoRepository(this._dataSource);
  final _TodoDataSource _dataSource;

  Future<List<_Todo>> getList() async {
    final raw = await _dataSource.getList();
    return raw.map(_Todo.fromJson).toList();
  }
}

class _GetTodoListUseCase extends UseCase<List<_Todo>, NoParams> {
  _GetTodoListUseCase(this._repository);
  final _DataTodoRepository _repository;

  @override
  Future<List<_Todo>> execute(NoParams params, CancelToken? cancelToken) =>
      _repository.getList();
}

// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late String featureDir;
  late String fixturesDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_893_boot_');
    featureDir = '${tempDir.path}/specs/893-demo-feature';
    fixturesDir = '$featureDir/tdd/fixtures';
    NetworkIsolationGuard.uninstall();
  });

  tearDown(() async {
    NetworkIsolationGuard.uninstall();
    ZuraffaContainer.instance.reset();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void commitTodoFixtures({int count = 3}) {
    Directory(fixturesDir).createSync(recursive: true);
    final records = List.generate(
      count,
      (i) => {
        'id': 'todo-${i + 1}',
        'title': 'Fixture todo ${i + 1}',
        'done': i.isOdd,
      },
    );
    File('$fixturesDir/todo_fixtures.json').writeAsStringSync(
      jsonEncode({
        'schema': 1,
        'spec': 893,
        'entity': 'Todo',
        'records': records,
      }),
    );
  }

  group('U11: entity fixture validation', () {
    test('missing fixtures fail fast naming the entity', () async {
      Directory(fixturesDir).createSync(recursive: true);
      expect(
        () => EntityFixtures.loadAll(
          fixturesDir: fixturesDir,
          entities: const {'Todo'},
        ),
        throwsA(
          isA<SimulationFixtureError>()
              .having((e) => e.entity, 'entity', 'Todo')
              .having((e) => e.toString(), 'toString', contains('Todo')),
        ),
      );
    });

    test('corrupt fixtures fail fast naming the entity', () async {
      commitTodoFixtures();
      File('$fixturesDir/todo_fixtures.json').writeAsStringSync('{oops');
      expect(
        () => EntityFixtures.loadAll(
          fixturesDir: fixturesDir,
          entities: const {'Todo'},
        ),
        throwsA(isA<SimulationFixtureError>()),
      );
    });

    test('valid fixtures load deterministically', () {
      commitTodoFixtures();
      final fixtures = EntityFixtures.loadAll(
        fixturesDir: fixturesDir,
        entities: const {'Todo'},
      );
      expect(fixtures['Todo'], hasLength(3));
      expect((fixtures['Todo']!.first)['id'], 'todo-1');
    });
  });

  group('A6: boot on certified mocks — demoability', () {
    test(
      'A6: simulation boot validates entity fixtures, warns on zero features, and runs the mock graph on fixture data',
      () async {
        commitTodoFixtures();
        final container = ZuraffaContainer.instance;
        container.reset();

        final report = await SimulationBoot.runApp(
          container: container,
          featureDir: featureDir,
          entities: const {'Todo'},
          simulation: true,
        );

        // FR-005: the guard is installed for the whole demo session.
        expect(report.guardActive, isTrue);
        expect(NetworkIsolationGuard.isActive, isTrue);
        expect(report.warnings, isEmpty);
        expect(report.fixtures['Todo'], hasLength(3));

        // The generated-style mock graph resolves through DI and serves
        // the COMMITTED fixture records — no real adapter exists, no
        // socket is opened (the guard would throw NetworkIsolationViolation).
        expect(container.isRegistered<_GetTodoListUseCase>(), isFalse,
            reason: 'boot binds fixtures/adapters; the composition root '
                'registers the graph — mirror that here');
        container.registerLazySingleton<_TodoDataSource>(
          () => _TodoMockDataSource(records: report.fixtures['Todo']!),
        );
        container.registerLazySingleton<_DataTodoRepository>(
          () => _DataTodoRepository(container.resolve<_TodoDataSource>()),
        );
        container.registerLazySingleton<_GetTodoListUseCase>(
          () => _GetTodoListUseCase(container.resolve<_DataTodoRepository>()),
        );

        final useCase = container.resolve<_GetTodoListUseCase>();
        final result = await useCase(const NoParams());
        final todos = result.getOrNull();
        expect(todos, isNotNull);
        expect(todos, hasLength(3));
        expect(todos!.first.title, 'Fixture todo 1');

        // SC-002: zero real sockets — nothing was approved and no
        // violation escaped (mocks never dial).
        expect(NetworkIsolationGuard.approvedAttempts, isEmpty);
      },
    );

    test('any real socket attempt inside the demo session is blocked',
        () async {
      commitTodoFixtures();
      final container = ZuraffaContainer.instance;
      container.reset();

      await SimulationBoot.runApp(
        container: container,
        featureDir: featureDir,
        entities: const {'Todo'},
        simulation: true,
      );

      await expectLater(
        Socket.connect('api.real-backend.invalid', 443),
        throwsA(isA<NetworkIsolationViolation>()),
      );
    });
  });

  group('U13: zero mocked features', () {
    test('boots with a warning when no complete(mocked) features exist',
        () async {
      final container = ZuraffaContainer.instance;
      container.reset();

      final report = await SimulationBoot.runApp(
        container: container,
        featureDir: featureDir,
        entities: const {},
        simulation: true,
      );

      expect(report.guardActive, isTrue);
      expect(
        report.warnings.join('\n'),
        contains('complete(mocked)'),
        reason: 'FR-010: the developer is warned that no mocked features '
            'are available for demo',
      );
    });
  });

  group('FR-008: no-op outside the simulation flavor', () {
    test('boot without the SIMULATION define is a harmless no-op',
        () async {
      commitTodoFixtures();
      final container = ZuraffaContainer.instance;
      container.reset();

      final report = await SimulationBoot.runApp(
        container: container,
        featureDir: featureDir,
        entities: const {'Todo'},
        simulation: false,
      );

      expect(report.guardActive, isFalse);
      expect(NetworkIsolationGuard.isActive, isFalse);
      expect(report.warnings, isNotEmpty);
    });
  });
}
