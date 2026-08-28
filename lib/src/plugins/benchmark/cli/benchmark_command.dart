/// `zfa benchmark` command and subcommands (FR-011, FR-012).
///
/// Subcommands:
///   zfa benchmark run [--scenario MYID]... [--tags A,B] [--dry-run]
///                     [--config JSON] [--json] [--timeout MS]
///                     [--concurrency N] [--store DIR]
///   zfa benchmark list [--json]
///   zfa benchmark baseline save MYSCENARIO [--label L] [--store DIR]
///   zfa benchmark baseline load MYSCENARIO [--label L] [--store DIR]
///   zfa benchmark baseline compare MYSCENARIO [--baseline L]
///                                  [--tolerance P] [--store DIR] [--json]
///   zfa benchmark baseline list [--store DIR]
///   zfa benchmark report [--store DIR]   (prints the latest suite result)
///
/// The command is pure-Dart and writes only through the plugin's runner and
/// baseline store; exit codes are exposed through [exitCode] so hosts (the
/// CliRunner, tests) decide how to terminate the process.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../../../core/benchmark/baseline_store.dart';
import '../benchmark_plugin.dart';

/// The `zfa benchmark` command (FR-011).
class BenchmarkCommand extends Command<void> {
  /// Creates the command bound to [plugin].
  BenchmarkCommand(this.plugin);

  /// The benchmark plugin providing registry + runner.
  final BenchmarkPlugin plugin;

  /// Exit code of the last invocation: 0 on success, 1 on benchmark
  /// failure/regression, 64 on usage errors.
  int exitCode = 0;

  @override
  String get name => 'benchmark';

  @override
  String get description =>
      'Run, list, and compare Zuraffa benchmarks (metric-driven quality '
      'gates).';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  static const _usage = '''
usage: zfa benchmark SUBCOMMAND [options]

subcommands:
  run [options]                 Run registered benchmark scenarios
  list [--json]                 List registered benchmark scenarios
  baseline save <id> --label L  Save a baseline from a fresh run
  baseline load <id>            Load the latest (or --label) baseline
  baseline compare <id>         Compare a fresh run against a baseline
  baseline list                 List all saved baselines
  report                        Print the latest suite report

run options:
  --scenario <id>               Run only the named scenario (repeatable)
  --tags <a,b>                  Run only scenarios with any of the tags
  --dry-run                     Validate configuration without executing
  --config <json>               Global config JSON merged into every scenario
  --json                        Machine-readable JSON output
  --timeout <ms>                Per-scenario timeout in milliseconds
  --concurrency <n>             Worker-pool size for the suite run
  --store <dir>                 Baseline store directory (default:
                                benchmarks/baselines)''';

  @override
  Future<void> run() async {
    final args = argResults!.arguments;
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      print(_usage);
      return;
    }

    final subcommand = args.first;
    final rest = args.sublist(1);

    switch (subcommand) {
      case 'run':
        await _run(rest);
      case 'list':
        await _list(rest);
      case 'baseline':
        await _baseline(rest);
      case 'report':
        await _report(rest);
      default:
        print('Unknown benchmark subcommand: \$subcommand');
        print(_usage);
        exitCode = 64;
    }
  }

  // --- run ---

  Future<void> _run(List<String> rest) async {
    final parser = _runParser();
    final results = _parseOrUsage(parser, rest);
    if (results == null) return;

    final scenarioIds = results['scenario'] as List<String>;
    final configJson = results['config'] as String?;
    Map<String, dynamic>? config;
    if (configJson != null) {
      try {
        config =
            jsonDecode(configJson) as Map<String, dynamic>;
      } catch (error) {
        print('Invalid --config JSON: $error');
        exitCode = 64;
        return;
      }
    }

    await plugin.discoverAndRegisterScenarios();

    var selected =
        (await plugin.registry.getAll()).cast<dynamic>().toList();
    selected = _filterSelection(selected, scenarioIds, results);

    final dryRun = results['dry-run'] as bool;
    final asJson = results['json'] as bool;

    if (dryRun) {
      final dryRuns = <Map<String, dynamic>>[];
      for (final scenario in selected) {
        final dry = await plugin.runner.dryRun(scenario, config: config);
        dryRuns.add(dry.toJson());
      }
      if (asJson) {
        print(jsonEncode({'dryRuns': dryRuns}));
      } else {
        for (final dry in dryRuns) {
          final verdict = dry['valid'] as bool ? 'valid' : 'INVALID';
          print('${dry['scenarioId']}: $verdict');
          for (final error in dry['errors'] as List<dynamic>) {
            print('  - $error');
          }
        }
      }
      exitCode = dryRuns.any((d) => d['valid'] != true) ? 1 : 0;
      return;
    }

    if (selected.isEmpty) {
      print('No benchmark scenarios registered.');
      exitCode = 64;
      return;
    }

    final suite = await plugin.runner.run(
      selected.cast(),
      globalConfig: config,
      concurrency: int.tryParse(results['concurrency'] as String? ?? '') ?? 1,
    );

    if (asJson) {
      print(jsonEncode(suite.toJson()));
    } else {
      _printSuiteReport(suite);
    }

    exitCode = suite.overallStatus == BenchmarkStatus.passed ? 0 : 1;

    // Persist the report for `zfa benchmark report`.
    final store = JsonBaselineStore(directory: _storeDir(results));
    final reportFile = File('${_storeDir(results)}/last-report.json');
    try {
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString('${jsonEncode(suite.toJson())}\n');
      await store.listAll(); // Ensures the store directory exists.
    } catch (_) {
      // Report persistence is best-effort.
    }
  }

  // --- list ---

  Future<void> _list(List<String> rest) async {
    final parser = ArgParser()
      ..addFlag('json', negatable: false, help: 'Machine-readable output');
    final results = _parseOrUsage(parser, rest);
    if (results == null) return;

    await plugin.discoverAndRegisterScenarios();
    final scenarios = await plugin.registry.getAll();

    if (results['json'] as bool) {
      print(jsonEncode({
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
      }));
      return;
    }

    if (scenarios.isEmpty) {
      print('No benchmark scenarios registered.');
      return;
    }
    for (final scenario in scenarios) {
      final tags =
          scenario.tags.isEmpty ? '' : ' [${scenario.tags.join(', ')}]';
      print('${scenario.id} — ${scenario.name} '
          '(v${scenario.version})$tags');
      if (scenario.description.isNotEmpty) {
        print('    ${scenario.description}');
      }
    }
  }

  // --- baseline ---

  Future<void> _baseline(List<String> rest) async {
    if (rest.isEmpty) {
      print(_usage);
      exitCode = 64;
      return;
    }
    final action = rest.first;
    final argsRest = rest.sublist(1);

    switch (action) {
      case 'save':
        await _baselineSave(argsRest);
      case 'load':
        await _baselineLoad(argsRest);
      case 'compare':
        await _baselineCompare(argsRest);
      case 'list':
        await _baselineList(argsRest);
      default:
        print('Unknown baseline action: $action');
        print(_usage);
        exitCode = 64;
    }
  }

  Future<void> _baselineSave(List<String> rest) async {
    final parser = _baselineParser();
    final results = _parseOrUsage(parser, rest, positional: 'scenario-id');
    if (results == null) return;
    if (!_requirePositional(results, 'scenario-id')) return;

    final scenarioId = results.rest.first;
    await plugin.discoverAndRegisterScenarios();
    final scenario = await plugin.registry.get(scenarioId);
    if (scenario == null) {
      print('Unknown scenario: $scenarioId');
      exitCode = 64;
      return;
    }

    final result = await plugin.runner.runSingle(scenario);
    final label = results['label'] as String? ??
        'run-${DateTime.now().millisecondsSinceEpoch}';
    final store = JsonBaselineStore(directory: _storeDir(results));

    await store.save(
      Baseline(
        scenarioId: scenario.id,
        scenarioVersion: scenario.version,
        label: label,
        metrics: result.metrics,
        timestamp: DateTime.now(),
        gitCommit: result.gitCommit,
        environment: {
          'os': Platform.operatingSystem,
          'dart': Platform.version.split(' ').first,
        },
      ),
    );
    print('Saved baseline "$label" for $scenarioId '
        '(${result.metrics.length} metrics)');
  }

  Future<void> _baselineLoad(List<String> rest) async {
    final parser = _baselineParser();
    final results = _parseOrUsage(parser, rest, positional: 'scenario-id');
    if (results == null) return;
    if (!_requirePositional(results, 'scenario-id')) return;

    final scenarioId = results.rest.first;
    final store = JsonBaselineStore(directory: _storeDir(results));
    final label = results['label'] as String?;
    final baseline = label == null
        ? await store.load(scenarioId)
        : await store.loadByLabel(scenarioId, label);

    if (baseline == null) {
      print('No baseline found for $scenarioId${label == null ? '' : ' (label: $label)'}');
      exitCode = 64;
      return;
    }

    print('Baseline "${baseline.label}" for ${baseline.scenarioId} '
        '(v${baseline.scenarioVersion}, ${baseline.timestamp.toIso8601String()}):');
    final sorted = baseline.metrics.keys.toList()..sort();
    for (final metric in sorted) {
      print('  $metric = ${baseline.metrics[metric]}');
    }
  }

  Future<void> _baselineCompare(List<String> rest) async {
    final parser = _baselineParser()
      ..addOption(
        'tolerance',
        help: 'Tolerance percentage (default 10)',
        abbr: 't',
      )
      ..addFlag('json', negatable: false, help: 'Machine-readable output');
    final results = _parseOrUsage(parser, rest, positional: 'scenario-id');
    if (results == null) return;
    if (!_requirePositional(results, 'scenario-id')) return;

    final scenarioId = results.rest.first;
    final store = JsonBaselineStore(directory: _storeDir(results));
    final label = results['baseline'] as String?;
    final baseline = label == null
        ? await store.load(scenarioId)
        : await store.loadByLabel(scenarioId, label);

    if (baseline == null) {
      print('No baseline found for $scenarioId${label == null ? '' : ' (label: $label)'}');
      exitCode = 64;
      return;
    }

    await plugin.discoverAndRegisterScenarios();
    final scenario = await plugin.registry.get(scenarioId);
    if (scenario == null) {
      print('Unknown scenario: $scenarioId');
      exitCode = 64;
      return;
    }

    final current = await plugin.runner.runSingle(scenario);
    final tolerance =
        num.tryParse(results['tolerance'] as String? ?? '') ?? 10;
    final comparison = compareBaselines(
      baseline,
      current.metrics,
      tolerancePercent: tolerance,
    );

    if (results['json'] as bool) {
      print(jsonEncode(comparison.toJson()));
    } else {
      print('Comparison for $scenarioId against "${baseline.label}" '
          '(tolerance $tolerance%):');
      final sorted = comparison.changes.keys.toList()..sort();
      for (final metric in sorted) {
        final change = comparison.changes[metric]!;
        final severity = change.severity == null
            ? ''
            : ' [${change.severity}]';
      print('  $metric: ${change.baselineValue} -> '
          '${change.currentValue} '
          '(${change.percentChange.toStringAsFixed(1)}%, '
          '${change.direction.name})$severity');
      }
      if (sorted.isEmpty) {
        print('  no comparable metrics');
      }
      print('Overall: ${comparison.overallStatus.name}');
    }

    exitCode =
        comparison.overallStatus == ComparisonStatus.regressed ? 1 : 0;
  }

  Future<void> _baselineList(List<String> rest) async {
    final parser = _baselineParser();
    final results = _parseOrUsage(parser, rest);
    if (results == null) return;

    final store = JsonBaselineStore(directory: _storeDir(results));
    final baselines = await store.listAll();
    if (baselines.isEmpty) {
      print('No baselines saved.');
      return;
    }
    for (final baseline in baselines) {
      print('${baseline.scenarioId} — "${baseline.label}" '
          '(${baseline.timestamp.toIso8601String()}, '
          '${baseline.metrics.length} metrics)');
    }
  }

  // --- report ---

  Future<void> _report(List<String> rest) async {
    final parser = ArgParser()
      ..addOption('store', help: 'Baseline store directory');
    final results = _parseOrUsage(parser, rest);
    if (results == null) return;

    final reportFile = File('${_storeDir(results)}/last-report.json');
    if (!await reportFile.exists()) {
      print('No benchmark report found. Run `zfa benchmark run` first.');
      exitCode = 64;
      return;
    }
    final suite = BenchmarkSuiteResult.fromJson(
      jsonDecode(await reportFile.readAsString())
          as Map<String, dynamic>,
    );
    _printSuiteReport(suite);
    exitCode = suite.overallStatus == BenchmarkStatus.passed ? 0 : 1;
  }

  // --- helpers ---

  ArgParser _runParser() {
    return ArgParser()
      ..addMultiOption(
        'scenario',
        abbr: 's',
        help: 'Run only the named scenario (repeatable)',
      )
      ..addOption('tags', help: 'Comma-separated tag filter')
      ..addFlag('dry-run', negatable: false, help: 'Validate without running')
      ..addOption('config', help: 'Global config JSON')
      ..addFlag('json', negatable: false, help: 'Machine-readable output')
      ..addOption('timeout', help: 'Per-scenario timeout (ms)')
      ..addOption('concurrency', help: 'Worker-pool size')
      ..addOption('store', help: 'Baseline store directory');
  }

  ArgParser _baselineParser() {
    return ArgParser()
      ..addOption('label', abbr: 'l', help: 'Baseline label')
      ..addOption('baseline', abbr: 'b', help: 'Baseline label to compare')
      ..addOption('store', help: 'Baseline store directory');
  }

  ArgResults? _parseOrUsage(
    ArgParser parser,
    List<String> rest, {
    String? positional,
  }) {
    try {
      return parser.parse(rest);
    } on FormatException catch (error) {
      print(error.message);
      print(_usage);
      exitCode = 64;
      return null;
    }
  }

  bool _requirePositional(ArgResults results, String name) {
    if (results.rest.isEmpty) {
      print('Missing $name');
      print(_usage);
      exitCode = 64;
      return false;
    }
    return true;
  }

  String _storeDir(ArgResults results) =>
      results['store'] as String? ?? 'benchmarks/baselines';

  List<dynamic> _filterSelection(
    List<dynamic> scenarios,
    List<String> scenarioIds,
    ArgResults results,
  ) {
    var selected = scenarios;
    if (scenarioIds.isNotEmpty) {
      final wanted = scenarioIds.toSet();
      selected = selected
          .where((s) => wanted.contains(s.id as String))
          .toList();
    }
    final tagsOption = results['tags'] as String?;
    if (tagsOption != null && tagsOption.isNotEmpty) {
      final tags = tagsOption.split(',').map((t) => t.trim()).toSet();
      selected = selected
          .where((s) => (s.tags as List<dynamic>).any(tags.contains))
          .toList();
    }
    return selected;
  }

  void _printSuiteReport(BenchmarkSuiteResult suite) {
    print('Benchmark suite: ${suite.results.length} scenario(s), '
        'overall ${suite.overallStatus.name}');
    for (final result in suite.results) {
      final violations = result.thresholdViolations.isEmpty
          ? ''
          : ' — ${result.thresholdViolations.map((v) => v.message).join('; ')}';
      print('  ${result.scenarioId}: ${result.status.name}'
          '${result.metadata['error'] != null ? ' (${result.metadata['error']})' : ''}$violations');
      final sorted = result.metrics.keys.toList()..sort();
      final shown = sorted.take(6).map((m) => '$m=${result.metrics[m]}');
      if (shown.isNotEmpty) {
        print('      ${shown.join('  ')}');
      }
    }
    print('Total: ${suite.totalDuration.inMilliseconds}ms');
  }
}
