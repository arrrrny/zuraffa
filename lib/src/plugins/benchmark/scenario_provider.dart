/// Cross-plugin scenario discovery contract (research.md decision).
///
/// Third-party plugins that want to contribute benchmarks implement
/// [BenchmarkScenarioProvider] and register themselves with the benchmark
/// plugin; the benchmark plugin then pulls their scenarios into its
/// registry during discovery. Plugins depend only on the benchmark contract
/// surface — never on the benchmark plugin itself (FR-014, FR-015).
///
/// Pure-Dart (no Flutter dependency) per spec 014-pure-dart-core-split.
library;

import '../../core/benchmark/benchmark_contract.dart';

/// Provides benchmark scenarios from a plugin or app (FR-003, FR-014).
abstract class BenchmarkScenarioProvider {
  /// Returns the scenarios this provider contributes.
  ///
  /// Called during discovery; may be called again after new registrations,
  /// so implementations should return a fresh list rather than mutate
  /// shared state.
  List<BenchmarkContract> provideScenarios();
}
