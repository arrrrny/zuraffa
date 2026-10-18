import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../cli/exit_protocol.dart';
import '../core/project/project_root.dart';

class BudgetCommand extends Command<void> {
  BudgetCommand() {
    addSubcommand(BudgetCheckCommand());
  }

  @override
  String get name => 'budget';

  @override
  String get description =>
      'Budgets as code: declare perf/size/startup budgets in zfa.yaml and '
      'check them (issue #819).';

  @override
  String get invocation => 'zfa budget check [options]';
}

class BudgetCheckCommand extends Command<void> {
  BudgetCheckCommand() {
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
    argParser.addOption(
      'root',
      help: 'Project root (defaults to detected project root).',
    );
    argParser.addFlag(
      'skip-tests',
      negatable: false,
      help: 'Skip the test wall-clock metric (faster, for local iteration).',
    );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Measure current metrics and compare against the budgets declared in '
      'zfa.yaml.';

  @override
  String get invocation => 'zfa budget check [options]';

  @override
  Future<void> run() async {
    final format = (argResults?['format'] as String?) ?? 'text';
    final skipTests = argResults?['skip-tests'] as bool? ?? false;
    final rootArg = argResults?['root'] as String?;
    final projectRoot = rootArg != null && rootArg.isNotEmpty
        ? p.normalize(p.absolute(rootArg))
        : ProjectRoot.find();

    final budgets = _readBudgets(projectRoot);

    final metrics = <String, num>{};
    final generatedSize = _generatedOutputSize(projectRoot);
    metrics['generated_output_size_bytes'] = generatedSize;

    if (!skipTests) {
      final testDir = Directory(p.join(projectRoot, 'test'));
      if (testDir.existsSync()) {
        final testWallClockMs = await _measureTestWallClock(projectRoot);
        if (testWallClockMs != null) {
          metrics['test_wall_clock_ms'] = testWallClockMs;
        }
      }
    }

    final violations = <Map<String, dynamic>>[];
    for (final entry in metrics.entries) {
      final budget = _lookupBudget(budgets, entry.key);
      if (budget != null && entry.value > budget) {
        violations.add({
          'metric': entry.key,
          'actual': entry.value,
          'budget': budget,
          'message': '${entry.key}: ${entry.value} exceeds budget $budget',
        });
      }
    }

    final passed = violations.isEmpty;

    if (format == 'json') {
      print(
        jsonEncode({
          'projectRoot': projectRoot,
          'budgets': budgets,
          'metrics': metrics,
          'violations': violations,
          'passed': passed,
        }),
      );
    } else {
      print('Budget check: ${passed ? "PASS" : "FAIL"}');
      print('Project: $projectRoot');
      print('Budgets: ${budgets.isEmpty ? "(none declared)" : budgets}');
      print('Metrics:');
      for (final entry in metrics.entries) {
        final budget = _lookupBudget(budgets, entry.key);
        final status = budget == null
            ? ''
            : (entry.value <= budget ? ' (within budget)' : ' (EXCEEDS)');
        print('  ${entry.key} = ${entry.value}$status');
      }
      if (violations.isNotEmpty) {
        print('Violations:');
        for (final v in violations) {
          print('  ${v['message']}');
        }
      }
    }

    exitCode = passed ? ExitProtocol.success : ExitProtocol.failure;
  }

  Map<String, dynamic> _readBudgets(String projectRoot) {
    final configFile = File(p.join(projectRoot, 'zfa.yaml'));
    if (!configFile.existsSync()) return {};
    try {
      final doc = loadYaml(configFile.readAsStringSync());
      if (doc is! Map) return {};
      final budgets = doc['budgets'];
      if (budgets is! Map) return {};
      return Map<String, dynamic>.from(budgets);
    } catch (_) {
      return {};
    }
  }

  num? _lookupBudget(Map<String, dynamic> budgets, String metric) {
    final direct = budgets[metric];
    if (direct is num) return direct;
    final aliases = <String, List<String>>{
      'generated_output_size_bytes': <String>[
        'generated_output_size',
        'output_size_bytes',
        'output_size',
      ],
      'test_wall_clock_ms': <String>[
        'test_wall_clock',
        'test_duration_ms',
        'test_time_ms',
      ],
    };
    for (final alias in (aliases[metric] ?? const <String>[])) {
      final v = budgets[alias];
      if (v is num) return v;
    }
    if (metric == 'test_wall_clock_ms') {
      for (final key in <String>['test_wall_clock_s', 'test_duration_s']) {
        final v = budgets[key];
        if (v is num) return v * 1000;
      }
    }
    if (metric == 'generated_output_size_bytes') {
      for (final key in <String>[
        'generated_output_size_kb',
        'output_size_kb',
      ]) {
        final v = budgets[key];
        if (v is num) return v * 1024;
      }
    }
    return null;
  }

  int _generatedOutputSize(String projectRoot) {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return 0;
    var total = 0;
    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int?> _measureTestWallClock(String projectRoot) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await Process.run('dart', [
        'test',
      ], workingDirectory: projectRoot);
      stopwatch.stop();
      if (result.exitCode == 0 || result.exitCode == 1) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }
}
