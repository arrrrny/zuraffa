import 'dart:async';
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
  String get invocation => 'zfa budget';
}

class BudgetCheckCommand extends Command<void> {
  String? _configError;
  bool _testRunFailed = false;

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
    if (format != 'text' && format != 'json') {
      print('❌ Unknown format: $format');
      print(
        ExitProtocol.fixLine(
          'pass --format text or --format json (got "$format")',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }
    final skipTests = argResults?['skip-tests'] as bool? ?? false;
    final rootArg = argResults?['root'] as String?;
    final projectRoot = rootArg != null && rootArg.isNotEmpty
        ? p.normalize(p.absolute(rootArg))
        : ProjectRoot.find();

    _configError = null;
    _testRunFailed = false;
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
          'fix':
              'reduce ${entry.key} to at most $budget or raise the budget in '
              'zfa.yaml',
        });
      }
    }

    if (_configError != null) {
      violations.add({
        'metric': 'config',
        'actual': 0,
        'budget': 0,
        'message': 'zfa.yaml budgets could not be parsed: $_configError',
        'fix': 'fix the budgets: section of zfa.yaml (see error above)',
      });
    }
    if (_testRunFailed) {
      violations.add({
        'metric': 'test_run',
        'actual': 0,
        'budget': 0,
        'message': 'dart test did not complete successfully',
        'fix': 'fix the test suite (compile/runtime errors) before budgeting',
      });
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
          print('  ${ExitProtocol.fixLine(v['fix'] as String)}');
        }
      }
      if (_configError != null) {
        print(
          '  ${ExitProtocol.fixLine('fix the budgets: section of zfa.yaml')}',
        );
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
      if (budgets == null) return {};
      if (budgets is! Map) {
        _configError = 'budgets: must be a map, got ${budgets.runtimeType}';
        stderr.writeln('Warning: $_configError');
        return {};
      }
      return Map<String, dynamic>.from(budgets);
    } catch (e) {
      _configError = e.toString();
      stderr.writeln('Warning: failed to parse zfa.yaml: $e');
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

  /// Sum of file sizes under `lib/`. Named `generated_output_size_bytes`
  /// in the report because generated artifacts live under `lib/`; the metric
  /// intentionally measures the whole `lib/` tree (generated + hand-written)
  /// so a growing codebase is visible regardless of origin.
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
    // Budget check must never block indefinitely on a hanging suite, and a
    // non-compiling/misconfigured suite must not be reported as "passed".
    const timeout = Duration(seconds: 300);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await Process.run('dart', [
        'test',
      ], workingDirectory: projectRoot).timeout(timeout);
      stopwatch.stop();
      if (result.exitCode != 0 && result.exitCode != 1) {
        _testRunFailed = true;
        stderr.writeln(
          'Warning: dart test exited with code ${result.exitCode}: '
          '${result.stderr}',
        );
      }
      return stopwatch.elapsedMilliseconds;
    } on TimeoutException {
      stopwatch.stop();
      _testRunFailed = true;
      stderr.writeln(
        'Warning: dart test timed out after ${timeout.inSeconds}s',
      );
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      stopwatch.stop();
      _testRunFailed = true;
      stderr.writeln('Warning: failed to run dart test: $e');
      return null;
    }
  }
}
