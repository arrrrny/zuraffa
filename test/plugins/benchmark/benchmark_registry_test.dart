// Tests for lib/src/core/benchmark/benchmark_registry.dart — behaviors
// U13–U20 of specs/015-benchmark-plugin/tdd/test-list.md.
//
// Registration, conflict handling, discovery, runtime registration.
import 'package:test/test.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_registry.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_result.dart';

void main() {
  late InMemoryBenchmarkRegistry registry;

  setUp(() {
    registry = InMemoryBenchmarkRegistry();
  });

  test('register then get', () async {
    final scenario = FakeScenario(
      'entity-crud-benchmark',
      name: 'Entity CRUD benchmark',
      tags: ['entity'],
    );
    final result = await registry.register(scenario);

    expect(result.isSuccess, isTrue);

    final stored = await registry.get('entity-crud-benchmark');
    expect(stored, isNotNull);
    expect(stored!.id, 'entity-crud-benchmark');
    expect(stored.name, 'Entity CRUD benchmark');
    expect(stored.version, '1.0.0');
    expect(stored.configSchema, containsPair('properties', anything));
  });

  test('duplicate conflicts', () async {
    await registry.register(FakeScenario('entity-crud-benchmark'));
    final second = await registry.register(
      FakeScenario('entity-crud-benchmark'),
    );

    expect(second.isFailure, isTrue);
    final error = second.getFailureOrNull();
    expect(error, isNotNull);
    expect(error!.code, BenchmarkRegistryErrorCode.duplicateScenarioId);
    expect(error.message, contains('entity-crud-benchmark'));

    // The original registration is intact.
    final stored = await registry.get('entity-crud-benchmark');
    expect(stored, isNotNull);
    expect((await registry.getAll()).length, 1);
  });

  test('invalid scenario rejected at registration', () async {
    final result = await registry.register(FakeScenario('Invalid ID'));

    expect(result.isFailure, isTrue);
    final error = result.getFailureOrNull();
    expect(error!.code, BenchmarkRegistryErrorCode.invalidScenario);
    expect(error.message, contains('kebab-case'));
    expect((await registry.getAll()), isEmpty);
  });

  test('unregister removes', () async {
    await registry.register(FakeScenario('a-scenario'));
    final result = await registry.unregister('a-scenario');

    expect(result.isSuccess, isTrue);
    expect(await registry.get('a-scenario'), isNull);
    expect(await registry.has('a-scenario'), isFalse);
  });

  test('unregister unknown id fails', () async {
    final result = await registry.unregister('never-registered');
    expect(result.isFailure, isTrue);
    expect(
      result.getFailureOrNull()!.code,
      BenchmarkRegistryErrorCode.unknownScenario,
    );
  });

  test('get all', () async {
    for (var i = 0; i < 3; i++) {
      await registry.register(FakeScenario('scenario-$i'));
    }
    final all = await registry.getAll();
    expect(all, hasLength(3));
    expect(
      all.map((s) => s.id),
      containsAll(['scenario-0', 'scenario-1', 'scenario-2']),
    );
  });

  test('get by tags', () async {
    await registry.register(
      FakeScenario('db-benchmark', tags: ['db', 'entity']),
    );
    await registry.register(FakeScenario('net-benchmark', tags: ['network']));
    await registry.register(
      FakeScenario('mixed-benchmark', tags: ['db', 'network']),
    );

    final dbScenarios = await registry.getByTags(['db']);
    expect(
      dbScenarios.map((s) => s.id),
      containsAll(['db-benchmark', 'mixed-benchmark']),
    );

    final dbOrNet = await registry.getByTags(['db', 'network']);
    expect(dbOrNet, hasLength(3));
  });

  test('has reports presence', () async {
    await registry.register(FakeScenario('present-scenario'));
    expect(await registry.has('present-scenario'), isTrue);
    expect(await registry.has('absent-scenario'), isFalse);
  });

  test('clear empties', () async {
    await registry.register(FakeScenario('a'));
    await registry.register(FakeScenario('b'));
    await registry.clear();
    expect(await registry.getAll(), isEmpty);
    expect(await registry.has('a'), isFalse);
  });

  test('runtime registration', () async {
    // Simulates a plugin registering a scenario after the suite object was
    // created — no restart, same process (FR-003).
    await registry.register(FakeScenario('early-scenario'));
    final before = (await registry.getAll()).length;

    await registry.register(FakeScenario('late-scenario'));
    final after = (await registry.getAll()).length;

    expect(after, before + 1);
    expect(await registry.has('late-scenario'), isTrue);
    expect(await registry.get('late-scenario'), isA<BenchmarkContract>());
  });

  test(
    'registering same instance under two registries is independent',
    () async {
      final other = InMemoryBenchmarkRegistry();
      final scenario = FakeScenario('shared-scenario');
      await registry.register(scenario);

      expect(await other.has('shared-scenario'), isFalse);
      await other.register(scenario);
      expect(await other.has('shared-scenario'), isTrue);
      expect(await registry.has('shared-scenario'), isTrue);
    },
  );
}

/// A deterministic fake scenario for registry tests.
class FakeScenario extends BenchmarkScenario {
  FakeScenario(this._id, {String? name, List<String> tags = const []})
    : _name = name ?? 'Scenario for $_id',
      _tags = tags;

  final String _id;
  final String _name;
  final List<String> _tags;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => const {
    'type': 'object',
    'properties': {
      'iterations': {'type': 'integer', 'minimum': 1, 'default': 10},
    },
  };

  @override
  List<String> get tags => _tags;

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async =>
      BenchmarkResult(
        scenarioId: id,
        scenarioName: name,
        scenarioVersion: version,
        status: BenchmarkStatus.passed,
        metrics: const {'ops': 1},
        thresholdViolations: const [],
        duration: const Duration(milliseconds: 1),
        timestamp: DateTime.now(),
      );
}
