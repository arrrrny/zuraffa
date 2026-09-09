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

void main() {
  final pubspec = File('example/pubspec.yaml');

  test('B1: the example baseline declares the TDD dev_dependencies',
      () {
    expect(pubspec.existsSync(), isTrue,
        reason: 'example/pubspec.yaml is the shipped baseline');
    final doc = loadYaml(pubspec.readAsStringSync()) as Map;
    final devDeps = doc['dev_dependencies'] as Map;

    // The gen'd engine-lane tests import package:test (pure Dart —
    // engine discipline, zero Flutter imports).
    expect(devDeps.keys, contains('test'),
        reason: 'engine tests compile against the shipped baseline');
    // The mutation auditor + coverage collector (tdd verify preflight).
    expect(devDeps.keys, contains('coverage'));
    expect(devDeps.keys, contains('mutation_test'));
    // Flutter consumers keep the Flutter test kernel.
    expect(devDeps.keys, contains('flutter_test'));
  });

  test('B2: the TDD deps carry the writer-canonical constraints', () {
    final doc = loadYaml(pubspec.readAsStringSync()) as Map;
    final devDeps = doc['dev_dependencies'] as Map;

    // The constraints `zfa tdd init` writes (PubspecDevDependencies
    // Patcher.flutterDevDependencies) — the repair path and the shipped
    // baseline must agree, or init reports a misfire on its own tree.
    expect(devDeps['test'], '^1.0.0');
    expect(devDeps['coverage'], '^1.15.1');
    expect(devDeps['mutation_test'], '^1.8.0');
  });
}
