/// The built-in Zuraffa benchmark plugin (feature 015).
///
/// Wires the pure benchmark contract library (`lib/src/core/benchmark/`)
/// into the Zuraffa plugin system: it owns a [BenchmarkRegistry] and a
/// [BenchmarkRunner], discovers scenarios from registered
/// [BenchmarkScenarioProvider]s (cross-plugin registration, FR-003/FR-014),
/// and exposes the `zfa benchmark` CLI command through [CliAwarePlugin]
/// (FR-011).
///
/// The plugin is pure-Dart — no `package:flutter` import anywhere in this
/// file or the library it uses (spec 014-pure-dart-core-split).
library;

import 'package:args/command_runner.dart';

import '../../core/benchmark/benchmark_contract.dart';
import '../../core/benchmark/benchmark_registry.dart';
import '../../core/benchmark/benchmark_runner.dart';
import '../../core/benchmark/isolate_benchmark_runner.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import 'capabilities/list_benchmarks_capability.dart';
import 'capabilities/register_benchmark_capability.dart';
import 'capabilities/run_benchmark_capability.dart';
import 'cli/benchmark_command.dart';
import 'scenario_provider.dart';

export '../../core/benchmark/benchmark_contract.dart';
export '../../core/benchmark/benchmark_registry.dart';
export '../../core/benchmark/benchmark_result.dart';
export '../../core/benchmark/benchmark_runner.dart';
export 'scenario_provider.dart';

/// The built-in benchmark plugin.
///
/// Apps and plugins register [BenchmarkScenarioProvider]s against it; the
/// plugin collects their scenarios into its registry and runs them through
/// the standard runner. Because scenarios depend only on
/// [BenchmarkContract], third-party code never imports the plugin itself
/// (FR-015).
class BenchmarkPlugin extends ZuraffaPlugin implements CliAwarePlugin {
  /// Creates the benchmark plugin.
  BenchmarkPlugin({
    BenchmarkRegistry? registry,
    BenchmarkRunner? runner,
  })  : registry = registry ?? InMemoryBenchmarkRegistry(),
        runner = runner ?? DefaultBenchmarkRunner();

  /// The plugin's registry — scenarios land here.
  final BenchmarkRegistry registry;

  /// The plugin's runner — executes registered scenarios.
  final BenchmarkRunner runner;

  final List<BenchmarkScenarioProvider> _providers = [];

  /// Plugin id, following the repo's convention of short domain ids.
  @override
  String get id => 'benchmark';

  @override
  String get name => 'Benchmark';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => const [];

  /// The three capabilities this plugin exposes (U57).
  @override
  List<ZuraffaCapability> get capabilities => [
        RunBenchmarkCapability(this),
        ListBenchmarksCapability(this),
        RegisterBenchmarkCapability(this),
      ];

  /// The `zfa benchmark` command (FR-011).
  @override
  Command<void> createCommand() => BenchmarkCommand(this);

  /// Registers a scenario provider (FR-003).
  void registerScenarioProvider(BenchmarkScenarioProvider provider) {
    _providers.add(provider);
  }

  /// Pulls scenarios from every registered provider into the registry.
  ///
  /// Duplicate ids across providers are skipped (first provider wins) so a
  /// misbehaving plugin cannot break discovery for the rest.
  Future<void> discoverAndRegisterScenarios() async {
    for (final provider in _providers) {
      for (final scenario in provider.provideScenarios()) {
        final existing = await registry.get(scenario.id);
        if (existing == null) {
          await registry.register(scenario);
        }
      }
    }
  }

  /// Convenience wrapper used by the list capability and the CLI.
  Future<ExecutionResult> listBenchmarks() async {
    final scenarios = await registry.getAll();
    return ExecutionResult(
      success: true,
      data: {
        'scenarios': [
          for (final scenario in scenarios)
            {
              'id': scenario.id,
              'name': scenario.name,
              'version': scenario.version,
              'description': scenario.description,
              'tags': scenario.tags,
              'thresholds': {
                for (final entry in scenario.thresholds.entries)
                  entry.key: entry.value.toJson(),
              },
            },
        ],
      },
    );
  }

  /// Convenience wrapper used by the run capability and the CLI: runs the
  /// registered scenarios (all, or [scenarioIds]) through the runner and
  /// returns the suite result.
  ///
  /// When [useIsolate] is `true` the scenarios run in per-scenario isolates
  /// (FR-007). [timeout] overrides the runner's per-scenario timeout.
  Future<ExecutionResult> runBenchmarks({
    List<String>? scenarioIds,
    Map<String, dynamic>? config,
    bool dryRun = false,
    bool useIsolate = false,
    Duration? timeout,
  }) async {
    final all = await registry.getAll();
    var selected = all;
    if (scenarioIds != null && scenarioIds.isNotEmpty) {
      final wanted = scenarioIds.toSet();
      selected = all.where((s) => wanted.contains(s.id)).toList();
    }

    if (dryRun) {
      final dryRuns = <Map<String, dynamic>>[];
      for (final scenario in selected) {
        final dry = await runner.dryRun(scenario, config: config);
        dryRuns.add(dry.toJson());
      }
      return ExecutionResult(success: true, data: {'dryRuns': dryRuns});
    }

    // FR-007: opt into per-scenario isolates when requested (CLI `--isolate`).
    final effectiveRunner = useIsolate
        ? IsolateBenchmarkRunner(
            config: BenchmarkRunnerConfig(
              timeout: timeout ?? const Duration(minutes: 5),
            ),
          )
        : runner;
    final suite = await effectiveRunner.run(
      selected,
      globalConfig: config,
      timeout: timeout,
    );
    // The capability invocation itself succeeded — the benchmark verdict
    // lives in the suite payload (overallStatus), which the CLI maps to an
    // exit code.
    return ExecutionResult(
      success: true,
      data: {'suite': suite.toJson()},
    );
  }
}
