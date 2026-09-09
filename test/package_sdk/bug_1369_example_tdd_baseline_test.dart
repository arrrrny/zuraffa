// Issue #1369 — the shipped `example/` baseline lacked the TDD
// dev_dependencies (`test`, `coverage`) that gen'd engine-lane tests
// require: `zfa tdd run 004-login-ui` died on its first engine behavior
// with `Couldn't resolve the package 'test'` (compile-error) because the
// project baseline could not compile a PURE-DART `package:test` import.
//
// Contract under test (spec 1369-tdd-baseline-dev-deps): the example
// baseline declares the FULL TDD baseline the `zfa tdd init` writer
// prescribes (flutter_test + test + coverage + mutation_test) — so the
// meta-run's engine lane compiles against the shipped tree without a
// manual `zfa tdd init` repair pass.

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';

void main() {
  final pubspec = File('example/pubspec.yaml');

  test('B1: the shipped baseline equals the writer-prescribed TDD set', () {
    expect(
      pubspec.existsSync(),
      isTrue,
      reason: 'example/pubspec.yaml is the shipped baseline',
    );
    final doc = loadYaml(pubspec.readAsStringSync()) as Map;
    final devDeps = doc['dev_dependencies'] as Map;

    // Presence: every dependency the init writer prescribes is declared.
    for (final entry
        in PubspecDevDependenciesPatcher.flutterDevDependencies.entries) {
      expect(
        devDeps.keys,
        contains(entry.key),
        reason: '${entry.key} is part of the prescribed TDD baseline',
      );
    }

    // Issue #1370 (supersedes this file's original `test` pin): plain
    // `test` is UNRESOLVABLE in this Flutter graph — the baseline must
    // NOT declare it (flutter_test re-exports the API the gen'd tests
    // use, issue #1351).
    expect(
      devDeps.keys,
      isNot(contains('test')),
      reason: 'the unresolvable test pin stays out of Flutter consumers',
    );

    // Constraint equality is pinned only for the TDD-critical pair the
    // mutation auditor and coverage collector consume — build tooling
    // (build_runner, json_serializable) stays example-managed.
    const writerCanonical = {'coverage': '^1.15.1', 'mutation_test': '^1.8.0'};
    for (final entry in writerCanonical.entries) {
      expect(
        devDeps[entry.key],
        entry.value,
        reason: '${entry.key} carries the writer-canonical constraint',
      );
    }
  });
}
