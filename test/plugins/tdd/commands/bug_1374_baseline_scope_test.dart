// Issue #1374 — bootstrapping deadlock on constrained agents: tdd run /
// tdd make unconditionally run the FULL-suite baseline (`dart test` over
// the whole tree ≈ 6.5 GB kernel cache), which cannot execute on a
// 10 GB-disk agent (`No space left on device`), and no verb can produce
// the FIRST run-baseline.json without that very run.
//
// Fix under test (spec 1374-baseline-scope-flag): `--baseline-scope
// <dir>` scopes the baseline suite command to a path (the canonical
// value: the feature's test directory), on both verbs. A scoped baseline
// is per-feature — the corpus-wide cache is bypassed entirely.
//
// Behaviors:
//   B1 — `zfa tdd run <f> --baseline-scope test/tdd/<f>` prints the
//        SCOPED baseline command (the suite line names the scope).
//   B2 — `zfa tdd make <id> --baseline-scope ...` prints the scoped
//        baseline command in its live-baseline branch.
//   B3 — without the flag, the baseline line is the UNSCOPED suite
//        command (guard).

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
    );
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  test('B1: run accepts --baseline-scope and prints the scoped command',
      () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'run',
      fx.featureName,
      '--project',
      fx.root.path,
      '--baseline-scope',
      'test/tdd/${fx.featureName}',
    ]);

    // The option must exist (no parser refusal)...
    expect(output, isNot(contains('Could not find an option named')));
    // ...and the baseline command carries the scope.
    expect(
      output,
      contains('suite baseline: dart test test/tdd/${fx.featureName}'),
      reason: output,
    );
  });

  test('B2: make accepts --baseline-scope and prints the scoped command',
      () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'make',
      'A1',
      '--project',
      fx.root.path,
      '--baseline-scope',
      'test/tdd/${fx.featureName}',
    ]);

    expect(output, isNot(contains('Could not find an option named')));
    expect(
      output,
      contains('suite baseline: dart test test/tdd/${fx.featureName}'),
      reason: output,
    );
  });

  test('B3: without the flag the baseline command stays unscoped (guard)',
      () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'make',
      'A1',
      '--project',
      fx.root.path,
    ]);

    expect(output, contains('suite baseline: dart test'), reason: output);
    expect(
      output,
      isNot(contains('suite baseline: dart test test/tdd/')),
      reason: output,
    );
  });
}
