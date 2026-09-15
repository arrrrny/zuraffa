// zfa:tdd: A1:hand — hand step completed before first red certification
// (issue #1411). The acceptance lane's guard-only fallback (issue #1512)
// cannot carry a real AC-1 assertion, so this hand-written scenario runner
// drives the production init path end to end and records the observable
// outcome for the paired test to assert (issue #1653): default
// `zfa tdd init` on an empty pure-Dart project must add the testing
// baseline dev_dependencies WITHOUT `mutation_test`.
// ignore_for_file: non_constant_identifier_names
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';

/// Dev-dependency map observed by the last [subject_a1] run — the paired
/// test asserts the AC-1 outcome on it, outside the generated guard
/// capture (issue #1411 hand-step contract).
Map<String, String> a1ObservedDevDeps = const {};

/// Scenario runner for behavior A1 (AC-1).
///
/// Creates an empty pure-Dart project in a temp dir, runs the production
/// `zfa tdd init` with DEFAULT flags through [CliRunner] (the same
/// in-process entrypoint the #1653 unit suites use — no JIT spawn), then
/// records the resulting `dev_dependencies` into [a1ObservedDevDeps].
///
/// Throws [StateError] if the baseline is absent or `mutation_test` was
/// injected — the observable AC-1 violations.
Future<void> subject_a1() async {
  final dir = Directory.systemTemp.createTempSync('a1_1653_init_');
  try {
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: a11653fixture
environment:
  sdk: ^3.11.0
dependencies: {}
dev_dependencies: {}
''');
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(['tdd', 'init', '--project', dir.path]);
    final doc =
        loadYaml(File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync())
            as YamlMap;
    final devDeps = (doc['dev_dependencies'] as YamlMap?) ?? YamlMap();
    a1ObservedDevDeps = {
      for (final entry in devDeps.entries) '${entry.key}': '${entry.value}',
    };
    if (a1ObservedDevDeps.isEmpty) {
      throw StateError(
        'AC-1 violated: default `zfa tdd init` added NO dev_dependencies',
      );
    }
    if (a1ObservedDevDeps.containsKey('mutation_test')) {
      throw StateError(
        'AC-1 violated: default init injected mutation_test '
        '(issue #1653: the dep must be opt-in via --mutation)',
      );
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
