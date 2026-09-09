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

    // One authoritative listing: every dependency the init writer
    // prescribes is declared, and `^`-constraints agree verbatim — the
    // shipped baseline and the repair path can never disagree.
    for (final entry
        in PubspecDevDependenciesPatcher.flutterDevDependencies.entries) {
      expect(
        devDeps.keys,
        contains(entry.key),
        reason: '${entry.key} is part of the prescribed TDD baseline',
      );
      final constraint = entry.value;
      if (constraint.startsWith('^')) {
        expect(
          devDeps[entry.key],
          constraint,
          reason: '${entry.key} carries the writer-canonical constraint',
        );
      }
    }
  });
}
