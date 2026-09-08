@Tags(['slow'])
// Issue #1323 — the hand-delta-required stop surfaces in the run driver
// (driver level, slow tier). The make-level suite
// (issue_1323_hand_delta_seam_test.dart) covers the make stop itself;
// this suite drives the REAL run loop over a scripted fake zfa binary:
//
//   U-1323-6 — a `hand-delta-required` make stop reports the named hand
//              step `stopped_at=<id>:hand` (the issue #1308 hand-step
//              contract), prints the exact edit remedy, and the lane
//              journal entry carries the hand-step violation
//              (FR-006 / SC-5).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  /// The scripted fake zfa binary: gen is ok, verify-red certifies red,
  /// make stops `hand-delta-required` (the new #1323 outcome shape),
  /// refactor is clean.
  Future<void> writeIssue1323FakeZfa() async {
    await Directory(fx.fakeZfaDir).create(recursive: true);
    final logPath = p.join(fx.fakeZfaDir, 'log');
    await File(logPath).writeAsString('');
    const script = r'''#!/bin/sh
# Fake zfa CLI for the #1323 driver test.
echo "$@" >> "__ARGVLOG__"
STEP="$2"
ID="$3"
HEAD="$1"
FEATURE=""
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done
if [ "$HEAD" != "tdd" ]; then
  exit 0
fi
echo "$STEP $ID" >> "__LOG__"
CYCLE="$PROJECT/specs/$FEATURE/tdd/cycle-log.md"
case "$STEP" in
  gen)
    exit 0 ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0
    ;;
  make)
    echo "   target test exit: 1"
    echo "zfa tdd make: the failure is the GENERATED _arg0() placeholder for a non-scalar declared param (issue #1323)."
    echo "   --> fix: replace _arg0() in test/tdd/1323-hand-delta/u1_test.dart with a representative Object — then re-run zfa tdd make $ID."
    echo "make: behavior=$ID outcome=hand-delta-required feature=$FEATURE"
    exit 1
    ;;
  refactor)
    echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"
    exit 0
    ;;
  *)
    echo "zfa tdd $STEP: unknown step"
    exit 1
    ;;
esac
''';
    final bin = File(fx.fakeZfaBin);
    await bin.writeAsString(
      script
          .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
          .replaceAll('__LOG__', logPath),
    );
    Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
  }

  /// The placeholder-carrying generated test file at the #827 namespaced
  /// layout — the content the driver's hand-step probe reads.
  Future<String> seedPlaceholderTestFile(String feature) async {
    final testPath = p.join(
      fx.root.path,
      'test',
      'tdd',
      feature,
      'u1_test.dart',
    );
    await File(testPath)
        .create(recursive: true)
        .then(
          (file) => file.writeAsString('''
// GENERATED TEST — `zfa tdd gen U1` (issue #1323 shape).
library;

import 'package:test/test.dart';

void main() {
  test('U1 — reason reports the error class', () {
    Object _arg0() => throw UnimplementedError('provide a representative argument for subject_u1 (declared param 0: Object)');
    final result = (() {
      try {
        return subject.subject_u1(_arg0());
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isA<String>());
  });
}
'''),
        );
    return testPath;
  }

  Future<String> drive(String feature) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  test('U-1323-6: the hand-delta-required make stop reports the named hand '
      'step with the exact edit remedy', () async {
    const feature = '1323-hand-delta-driver';
    fx = await TddFixture.create(featureName: feature);
    addTearDown(fx.dispose);
    await writeIssue1323FakeZfa();
    await seedPlaceholderTestFile(feature);
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'reason reports the error class',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);

    final out = await drive(feature);

    // The honest stop carries the make outcome verbatim...
    expect(
      out,
      contains('behavior=U1 step=make outcome=hand-delta-required'),
      reason: out,
    );
    // ...the named hand step REPLACES the generic stopped_at=<id>:make
    // (the #1308 contract, FR-006 / SC-5)...
    expect(out, contains('stopped_at=U1:hand'), reason: out);
    expect(out, isNot(contains('stopped_at=U1:make')), reason: out);
    // ...and the remedy names the EXACT edit: the placeholder, the
    // test file, the declared type, the re-run command.
    expect(out, contains('replace _arg0()'), reason: out);
    expect(
      out,
      contains(p.join('test', 'tdd', feature, 'u1_test.dart')),
      reason: out,
    );
    expect(out, contains('representative Object'), reason: out);
    expect(out, contains('then re-run zfa tdd make U1'), reason: out);

    // The journal entry carries the ONE explicit, named hand step.
    final journalFile = File(p.join(fx.featureDir, 'tdd', 'journal.json'));
    expect(journalFile.existsSync(), isTrue, reason: out);
    final journal =
        jsonDecode(journalFile.readAsStringSync()) as Map<String, dynamic>;
    final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
    final violations = entries
        .expand((e) => ((e['violations'] ?? <String>[]) as List).cast<String>())
        .toList();
    expect(
      violations.any((v) => v.contains('hand-step=U1:hand')),
      isTrue,
      reason: 'journal violations: $violations',
    );
    expect(
      violations.any((v) => v.contains('_arg0()')),
      isTrue,
      reason: 'journal violations: $violations',
    );
  });
}
