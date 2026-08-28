/// `zfa benchmark` command (FR-011) — stub.
///
/// The full subcommand surface (run/list/baseline/report) is driven by the
/// TDD cycle for behaviors U61–U67; this placeholder exists so the plugin
/// wiring compiles before that cycle turns it green.
library;

import 'package:args/command_runner.dart';

import '../benchmark_plugin.dart';

/// The `zfa benchmark` command.
class BenchmarkCommand extends Command<void> {
  /// Creates the command bound to [plugin].
  BenchmarkCommand(this.plugin);

  /// The benchmark plugin providing the registry and runner.
  final BenchmarkPlugin plugin;

  @override
  String get name => 'benchmark';

  @override
  String get description => 'Run, list, and compare Zuraffa benchmarks.';
}
