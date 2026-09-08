@Tags(['slow'])
// Issue #1308 — the vacuous-green remedy surfaces (driver level, slow
// tier). The fast tier (issue_1308_vacuous_guard_remedy_test.dart) covers
// the vocabulary and the writer's gen-time warning; this suite drives the
// REAL RunDriverCore over a scripted fake zfa binary:
//
//   U-1308-5 — a vacuous-green make stop on a FALLBACK-ROUTED behavior
//              (the generated test carries no vacuous-guard marker)
//              prints the exact remedy and keeps the summary machine
//              contract `stopped_at=<id>:make` (FR-001 / SC-1).
//   U-1308-6 — a vacuous-green make stop on a TRACED entity/void behavior
//              (the generated test CARRIES the marker) reports the named
//              hand step `stopped_at=<id>:hand`, names what to write and
//              where, and the lane journal entry carries the hand-step
//              violation (FR-004 / SC-3).
//   U-1308-4 — the gen child's guard-only warning lines are FORWARDED
//              into the run transcript (the run captures the gen child's
//              output; a successful gen prints none of it without the
//              forward — FR-003).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  /// The scripted fake zfa binary for the #1308 scenarios: gen is silent
  /// or warns (the writer's exact warning shape), verify-red certifies
  /// red, make is green or refuses vacuous-green (the issue #1259 shape).
  Future<void> writeIssue1308FakeZfa() async {
    await Directory(fx.fakeZfaDir).create(recursive: true);
    final configDir = p.join(fx.fakeZfaDir, 'config');
    await Directory(configDir).create(recursive: true);
    final logPath = p.join(fx.fakeZfaDir, 'log');
    await File(logPath).writeAsString('');
    const script = r'''#!/bin/sh
# Fake zfa CLI for the #1308 driver tests.
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
CFG="__CFG__/$STEP-$ID"
if [ -f "$CFG" ]; then
  OUTCOME=$(cat "$CFG")
else
  OUTCOME="ok"
fi
CYCLE="$PROJECT/specs/$FEATURE/tdd/cycle-log.md"
case "$STEP" in
  gen)
    case "$OUTCOME" in
      ok) exit 0 ;;
      warn)
        echo "zfa tdd gen: WARNING [zfa:tdd: guard-only] behavior \"$ID\" — the generated unit test assertion set is only the bare UnimplementedError guard: no traces: line derives a real outcome assertion (issue #1259, #1308)."
        echo "   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run"
        exit 0 ;;
      *) echo "zfa tdd gen: $OUTCOME"; exit 1 ;;
    esac
    ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0
    ;;
  make)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
        echo "make: behavior=$ID outcome=green feature=$FEATURE"
        exit 0 ;;
      vacuous-green)
        echo "make: behavior=$ID outcome=vacuous-green feature=$FEATURE"
        exit 1 ;;
      *) echo "make: behavior=$ID outcome=$OUTCOME feature=$FEATURE"; exit 1 ;;
    esac
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
          .replaceAll('__LOG__', logPath)
          .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
          .replaceAll('__CFG__', configDir),
    );
    Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
  }

  /// The marker-carrying generated test file (the traced entity/void
  /// path's #1259 shape) at the #827 namespaced layout.
  Future<String> seedMarkerTestFile(String feature) async {
    final snakeId = 'u1';
    final testPath = p.join(
      fx.root.path,
      'test',
      'tdd',
      feature,
      '${snakeId}_test.dart',
    );
    await File(testPath)
        .create(recursive: true)
        .then(
          (file) => file.writeAsString('''
// GENERATED TEST — `zfa tdd gen U1`.
library;

import 'package:test/test.dart';

void main() {
  test('U1 — traced entity contract', () {
    final result = (() {
      try {
        return subject.subjectU1();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    // ${'zfa:tdd: vacuous-guard'} (issue #1259): the assertion set below is the
    // UnimplementedError guard ONLY — replace this guard with an
    // assertion on the observable outcome, remove this marker, and
    // re-run make.
    expect(result, isNot(isA<UnimplementedError>()));
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

  test(
    'U-1308-5: the fallback vacuous-green stop prescribes the exact traces remedy (stopped_at=<id>:make)',
    () async {
      const feature = '1308-fallback-remedy';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeIssue1308FakeZfa();
      // The fallback path: the traces cell carries only the criterion
      // token (FR-001) — NO declared contract row, so routing falls back
      // (the issue's repro shape; RoutingResolver skips criterion
      // tokens and returns RoutingUndeclared).
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'lets the user add a todo with a title',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

      final out = await drive(feature);

      // The honest stop names the vacuous-green outcome...
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      // ...prescribes the EXACT remedy (FR-001 / SC-1)...
      expect(
        out,
        contains(
          'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
          're-run zfa tdd gen, re-run zfa tdd run',
        ),
        reason: out,
      );
      // ...and the summary machine contract is PRESERVED on the fallback
      // path (the stop is still the make step).
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
    },
  );

  test(
    'U-1308-6: the traced entity/void vacuous-green stop reports the named hand step in the journal',
    () async {
      const feature = '1308-hand-seam';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeIssue1308FakeZfa();
      // The TRACED path: the generated test carries the vacuous-guard
      // marker (the #1259 entity/void shape).
      final testPath = await seedMarkerTestFile(feature);
      expect(
        File(testPath).readAsStringSync(),
        contains('zfa:tdd: vacuous-guard'),
      );
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'creates the user entity',
          traces: 'FR-001, UserRepo',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

      final out = await drive(feature);

      // The named hand step REPLACES the generic stopped_at=<id>:make
      // (FR-004 / SC-3): what to write (the outcome assertion) and where.
      expect(out, contains('stopped_at=U1:hand'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:make')), reason: out);
      expect(out, contains('assertion on the observable outcome'), reason: out);
      expect(
        out,
        contains(p.join('test', 'tdd', feature, 'u1_test.dart')),
        reason: out,
      );

      // The journal entry carries the ONE explicit, named hand step: the
      // ENGINE lane's drive entry (the meta aggregate entry carries no
      // stopped_at by design).
      final journalPath = p.join(fx.featureDir, 'tdd', 'journal.json');
      final decoded =
          jsonDecode(File(journalPath).readAsStringSync())
              as Map<String, dynamic>;
      final entries = (decoded['entries'] as List).cast<Map<String, dynamic>>();
      final entry = entries.lastWhere(
        (e) => e['cycle'] == 'engine' && e['phase'] == 'drive',
      );
      expect(entry['stopped_at'], 'U1:hand');
      final violations = (entry['violations'] as List).cast<String>().join(
        '\n',
      );
      expect(violations, contains('hand-step=U1:hand'));
      expect(violations, contains('zfa:tdd: vacuous-guard'));
      expect(
        violations,
        contains(p.join('test', 'tdd', feature, 'u1_test.dart')),
        reason: violations,
      );
      expect(violations, contains('assertion on the observable outcome'));
    },
  );

  test('U-1308-7: an unreadable generated test fails OPEN — the stop is the '
      'fallback remedy, not a crash', () async {
    const feature = '1308-unreadable-marker';
    fx = await TddFixture.create(featureName: feature);
    addTearDown(fx.dispose);
    await writeIssue1308FakeZfa();
    // The marker-carrying file EXISTS (so the namespaced resolution
    // finds it) but is UNREADABLE: the marker read must fail OPEN —
    // marker absent — falling into the fallback-remedy arm instead of
    // throwing an unhandled FileSystemException out of the driver.
    final testPath = await seedMarkerTestFile(feature);
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'creates the user entity',
        traces: 'FR-001, UserRepo',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await File(
      p.join(fx.fakeZfaDir, 'config', 'make-U1'),
    ).writeAsString('vacuous-green');

    await Process.run('chmod', ['000', testPath]);
    String out;
    try {
      out = await drive(feature);
    } finally {
      await Process.run('chmod', ['644', testPath]);
    }

    // The run driver SURVIVED (no unhandled read crash) and the stop is
    // the honest fallback arm...
    expect(out, contains('stopped_at=U1:make'), reason: out);
    expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
    expect(
      out,
      contains(
        'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
        're-run zfa tdd gen, re-run zfa tdd run',
      ),
      reason: out,
    );
  });

  test(
    'U-1308-4: the gen child guard-only warning is forwarded into the run transcript',
    () async {
      const feature = '1308-gen-warn-forward';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeIssue1308FakeZfa();
      // The gen step WARNS (the writer's exact warning shape) and exits 0
      // — the step does not fail; the warning must still reach the run
      // output (FR-003).
      await File(
        p.join(fx.fakeZfaDir, 'config', 'gen-U1'),
      ).writeAsString('warn');
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'lets the user add a todo with a title',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive(feature);

      // The run COMPLETED (the gen step did not fail) and the warning is
      // impossible to miss in the run output.
      expect(out, contains('result=complete'), reason: out);
      expect(out, contains('zfa:tdd: guard-only'), reason: out);
      expect(
        out,
        contains(
          'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
          're-run zfa tdd gen, re-run zfa tdd run',
        ),
        reason: out,
      );
    },
  );
}
