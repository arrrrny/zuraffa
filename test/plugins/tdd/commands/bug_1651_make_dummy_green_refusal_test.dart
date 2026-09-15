@Tags(['e2e'])
// Issue #1651 — the make-level repro: the issue's exact flow certifies a
// dummy-body green on master.
//
//   1. `zfa tdd gen U1` — a traced scalar-declared contract
//      (`Calculator: add(int a, int b) -> int`) emits the typed outcome
//      assertion `expect(result, isA<int>())`.
//   2. `zfa tdd verify-red U1` — the throwing stub is the honest red.
//   3. `zfa tdd func U1` — the #1517 scaffold pass fills the subject
//      with `return 0;`.
//   4. `zfa tdd make U1` — the type-only test PASSES on the dummy… and
//      pre-#1651 make CERTIFIED green. The remediation: the generated
//      test carries the `zfa:tdd: vacuous-guard` marker, so make refuses
//      with `outcome=vacuous-green` and the run stops at the designed
//      hand step (write a value assertion from the spec's scenario,
//      implement the subject, remove the marker, re-run make).
//
// e2e tier (#1510 convention): spawns a real `dart test` inside the
// fixture; honest under direct `dart test <file>` invocation, excluded
// from CI's fast lane.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

import '../helpers/tdd_fixture.dart';

/// The spec declaring the issue's calculator contract (the zcalc probe's
/// shape, reduced to the scalar row under test).
const calcSpec = '''
# Calculator

### Layer Contracts

**Function**:
- `Calculator`: `add(int a, int b) -> int`
''';

/// The registry record's portable project-relative form (issue #1397)
/// resolved against the fixture root.
String _resolved(TddFixture fx, String recorded) =>
    p.isAbsolute(recorded) ? recorded : p.join(fx.root.path, recorded);

Future<String> genSubjectOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(_resolved(fx, record['subject_path'] as String)).readAsString();
}

Future<String> genTestOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(_resolved(fx, record['test_path'] as String)).readAsString();
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '1651-vacuous-green');
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('U4: gen → verify-red → func → make — the dummy-body pair is '
      'refused vacuous-green, never certified', () async {
    const description =
        'the calculator MUST add two integers via `Calculator.add` and '
        'return their sum';
    await fx.seedTestList([
      (
        id: 'U1',
        description: description,
        traces: 'Calculator.add',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await Directory(fx.featureDir).create(recursive: true);
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(calcSpec);

    final runner = CliRunner(exitOnCompletion: false);

    // 1. gen — the typed assertion + the marker land on disk.
    final gen = await runner.runCapturing([
      'tdd',
      'gen',
      'U1',
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: 'gen must succeed: $gen');
    final testContent = await genTestOf(fx, 'U1');
    expect(
      testContent,
      contains('expect(result, isA<int>())'),
      reason: 'the declared scalar outcome is asserted mechanically',
    );
    expect(
      testContent,
      contains(vacuousGuardMarker),
      reason:
          'the type-only assertion carries the marker so make refuses the '
          'dummy-body green (issue #1651)',
    );

    // 2. verify-red — the throwing stub is the honest red.
    final red = await runner.runCapturing([
      'tdd',
      'verify-red',
      'U1',
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: 'the gen pair must certify red: $red');

    // 3. func — the #1517 scaffold fills the subject with the dummy.
    final func = await runner.runCapturing([
      'tdd',
      'func',
      'U1',
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 0, reason: 'func must scaffold: $func');
    final subject = await genSubjectOf(fx, 'U1');
    expect(
      subject,
      contains('return 0;'),
      reason: 'the issue\u2019s dummy body — the vacuous-green trigger',
    );

    // 4. make — the dummy satisfies the type check, but the marker
    //    refuses the green (pre-#1651 this certified: exit 0).
    final make = await runner.runCapturing([
      'tdd',
      'make',
      'U1',
      '--project',
      fx.root.path,
    ]);
    expect(exitCode, 1, reason: 'a dummy-body green must not certify: $make');
    expect(make, contains('outcome=vacuous-green'), reason: make);
    expect(make, contains(vacuousGuardMarker), reason: make);

    // No green evidence may be appended for the refused green.
    final log = await File(fx.cycleLogPath).readAsString();
    expect(
      log,
      isNot(contains('## Cycle: U1 (green)')),
      reason: 'no green evidence may be appended for a vacuous green',
    );
  });
}
