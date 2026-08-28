/// Benchmark scenario registry (FR-002, FR-003).
///
/// [BenchmarkRegistry] is the contract plugins and apps register scenarios
/// against; [InMemoryBenchmarkRegistry] is the built-in implementation.
/// Registration is validated (AC-2), duplicate ids conflict (AC-4), and
/// scenarios can be registered at runtime without restarting the process
/// (FR-003).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import '../result.dart';
import 'benchmark_contract.dart';

/// Error codes returned by [BenchmarkRegistry] operations.
enum BenchmarkRegistryErrorCode {
  /// A scenario with the same id is already registered.
  duplicateScenarioId,

  /// The scenario failed metadata validation.
  invalidScenario,

  /// No scenario is registered under the requested id.
  unknownScenario,
}

/// A registry failure: machine-readable [code] plus a human message.
class BenchmarkRegistryError {
  /// Machine-readable error code.
  final BenchmarkRegistryErrorCode code;

  /// Human-readable description.
  final String message;

  /// Creates a registry error.
  const BenchmarkRegistryError(this.code, this.message);

  @override
  String toString() => '$code: $message';
}

/// Central registry for discovering and managing registered scenarios
/// (FR-002).
abstract class BenchmarkRegistry {
  /// Registers [scenario].
  ///
  /// Fails with [BenchmarkRegistryErrorCode.invalidScenario] when metadata
  /// validation fails, and with
  /// [BenchmarkRegistryErrorCode.duplicateScenarioId] when the id is taken.
  Future<Result<void, BenchmarkRegistryError>> register(
    BenchmarkContract scenario,
  );

  /// Unregisters the scenario with [id].
  Future<Result<void, BenchmarkRegistryError>> unregister(String id);

  /// Returns all registered scenarios.
  Future<List<BenchmarkContract>> getAll();

  /// Returns the scenario registered under [id], or `null`.
  Future<BenchmarkContract?> get(String id);

  /// Returns scenarios matching any of [tags].
  Future<List<BenchmarkContract>> getByTags(List<String> tags);

  /// Whether a scenario is registered under [id].
  Future<bool> has(String id);

  /// Removes every registration (test support).
  Future<void> clear();
}

/// In-memory [BenchmarkRegistry] implementation.
class InMemoryBenchmarkRegistry implements BenchmarkRegistry {
  final Map<String, BenchmarkContract> _scenarios = {};

  /// Creates an empty registry.
  InMemoryBenchmarkRegistry();

  @override
  Future<Result<void, BenchmarkRegistryError>> register(
    BenchmarkContract scenario,
  ) async {
    final errors = ScenarioValidation.validate(scenario);
    if (errors.isNotEmpty) {
      return Result.failure(
        BenchmarkRegistryError(
          BenchmarkRegistryErrorCode.invalidScenario,
          errors.join('; '),
        ),
      );
    }
    if (_scenarios.containsKey(scenario.id)) {
      return Result.failure(
        BenchmarkRegistryError(
          BenchmarkRegistryErrorCode.duplicateScenarioId,
          "a scenario is already registered under '${scenario.id}'",
        ),
      );
    }
    _scenarios[scenario.id] = scenario;
    return const Result.success(null);
  }

  @override
  Future<Result<void, BenchmarkRegistryError>> unregister(String id) async {
    if (!_scenarios.containsKey(id)) {
      return Result.failure(
        BenchmarkRegistryError(
          BenchmarkRegistryErrorCode.unknownScenario,
          "no scenario registered under '$id'",
        ),
      );
    }
    _scenarios.remove(id);
    return const Result.success(null);
  }

  @override
  Future<List<BenchmarkContract>> getAll() async =>
      List.unmodifiable(_scenarios.values);

  @override
  Future<BenchmarkContract?> get(String id) async => _scenarios[id];

  @override
  Future<List<BenchmarkContract>> getByTags(List<String> tags) async {
    final wanted = tags.toSet();
    return _scenarios.values
        .where((s) => s.tags.any(wanted.contains))
        .toList();
  }

  @override
  Future<bool> has(String id) async => _scenarios.containsKey(id);

  @override
  Future<void> clear() async {
    _scenarios.clear();
  }
}
