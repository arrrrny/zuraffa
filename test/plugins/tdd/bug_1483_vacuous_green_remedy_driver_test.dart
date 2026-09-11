// Bug #1483 — the vacuous-green remedy must name the seam that EXISTS
// for the feature shape it is talking to.
//
// Issue #1320 introduced the shared remedy wording with the lane plan
// hardcoded: "hand-edit the lane plan (04-ENGINE.md) traces cell". For a
// LEGACY single-file feature (no `## Lanes` in its spec — the shape
// `zfa tdd plan` produces with no lane split) there is no 04-ENGINE.md
// and there never will be: the author following the stop message edits a
// nonexistent file while the real seam — the traces cell of
// `tdd/test-list.md` — sits untouched. The remediation is messaging-only:
//
//   1. the run driver's fallback vacuous-green make stop branches the
//      remedy by feature shape — the lane plan's traces cell
//      (04-ENGINE.md) ONLY when the lane plan pair is actually on disk;
//      the legacy single-file feature hand-edits the TEST LIST's traces
//      cell — and prints the FULL path of the file to edit (a bare
//      filename hides the feature dir).
//   2. NOTHING else changes: the vacuous-green detection, the stop
//      result and the `stopped_at=<id>:make` machine contract, and the
//      loop semantics are untouched.
//
// The fast tier (the remedy VOCABULARY, vacuous_guard.dart) lives in
// bug_1483_vacuous_green_remedy_shape_test.dart; this suite drives the
// REAL RunDriverCore over a scripted fake zfa binary (the issue #1308
// driver-suite convention).
//
// Test map:
//   U-1483-2 (driver) — a legacy single-file feature's vacuous-green
//            stop names `specs/<feature>/tdd/test-list.md` and NEVER
//            04-ENGINE.md; `stopped_at=U1:make` preserved.
//   U-1483-3 (driver) — a lane-split feature's vacuous-green stop
//            names `specs/<feature>/tdd/04-ENGINE.md` (the plan pair is
//            the seam there); `stopped_at=U1:make` preserved.
//   U-1483-4 (driver) — a run-skin over an ORPHAN `tdd/04-SKIN.md`
//            (engine plan absent, green engine receipt on disk) names
//            `specs/<feature>/tdd/04-SKIN.md` — the skin plan is the
//            seam there; `stopped_at=U1:make` preserved. (The meta-run
//            shapes cannot reach this branch: a meta-index list missing
//            a plan file runner-errors in the lane-split reader, and
//            the meta run drives nothing when the engine pass is
//            empty.)
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1483 — the run driver stop message (driver level)', () {
    late TddFixture fx;

    /// The scripted fake zfa binary (the issue #1308 shape): gen is
    /// silent, verify-red certifies red, make refuses vacuous-green.
    Future<void> writeBug1483FakeZfa() async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = p.join(fx.fakeZfaDir, 'config');
      await Directory(configDir).create(recursive: true);
      final logPath = p.join(fx.fakeZfaDir, 'log');
      await File(logPath).writeAsString('');
      const script = r'''#!/bin/sh
# Fake zfa CLI for the #1483 driver tests.
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
      *) echo "zfa tdd gen: $OUTCOME"; exit 1 ;;
    esac
    ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-09-01T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0
    ;;
  make)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-09-01T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
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

    /// Drive `zfa tdd run <feature>` against the fake binary and return
    /// the captured output. [command] selects the driver entrypoint
    /// (`run` = the meta two-cycle run, `run-skin` = the SKIN lane).
    Future<String> drive(String feature, {String command = 'run'}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        command,
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
    }

    /// The ONE `--> fix:` remedy line the driver prints on the fallback
    /// vacuous-green stop (the line the bug is about).
    String remedyLine(String out) => out
        .split('\n')
        .firstWhere((l) => l.contains('--> fix:'), orElse: () => '');

    Future<void> seedVacuousStop(String feature) async {
      await writeBug1483FakeZfa();
      // The fallback-routed shape: the traces cell carries only the
      // criterion token (FR-001), no declared contract row — make
      // refuses vacuous-green (issue #1259) and the stop prescribes the
      // traces remedy (issue #1308's arm, #1483's wording).
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
    }

    test('U-1483-2: LEGACY single-file feature — the stop names the test-list '
        'traces cell (full path), NOT the nonexistent 04-ENGINE.md', () async {
      const feature = '1483-single-file-seam';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await seedVacuousStop(feature);
      // The legacy single-file shape: NO lane plan pair on disk.
      expect(
        File(p.join(fx.featureDir, 'tdd', '04-ENGINE.md')).existsSync(),
        isFalse,
      );

      final out = await drive(feature);

      // The honest stop is unchanged: the fallback vacuous-green arm,
      // the make step machine contract preserved (no behavior change).
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
      // THE FIX: the remedy names the seam that EXISTS — the test
      // list's traces cell, with the FULL path (feature dir included).
      expect(
        remedyLine(out),
        contains(
          'hand-edit the test list '
          '(${p.join('specs', feature, 'tdd', 'test-list.md')}) '
          'traces cell',
        ),
        reason: out,
      );
      // ...and never sends the author to the nonexistent lane plan.
      expect(remedyLine(out), isNot(contains('04-ENGINE')), reason: out);
    });

    test('U-1483-3: LANE-SPLIT feature — the stop still names the lane plan '
        'traces cell (full path)', () async {
      const feature = '1483-lane-split-seam';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeBug1483FakeZfa();
      // The lane-split shape: the test list is the META-INDEX (the
      // `## Lane split` section pointing at the plan pair) and the
      // behaviors live in the lane plan files (issue #1000).
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Lane split

The behaviors live in the lane plan pair (issue #1000).

- engine plan: `04-ENGINE.md`
- skin plan: `04-SKIN.md`
- engine/skin contract: `04-CONTRACT.md`
''');
      await File(p.join(fx.featureDir, 'tdd', '04-ENGINE.md')).writeAsString('''
# Engine Plan: $feature (CORE + BOTH)

The engine lane (issue #1000): pure Dart.

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo with a title | FR-001 | PENDING |
''');
      await File(p.join(fx.featureDir, 'tdd', '04-SKIN.md')).writeAsString('''
# Skin Plan: $feature (SKIN + BOTH)

The skin lane (issue #1000): Flutter allowed.
''');
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

      final out = await drive(feature);

      // The stop machine contract is unchanged on the lane-split shape.
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
      // The lane plan pair IS the seam here — named with the full path.
      expect(
        remedyLine(out),
        contains(
          'hand-edit the lane plan '
          '(${p.join('specs', feature, 'tdd', '04-ENGINE.md')}) '
          'traces cell',
        ),
        reason: out,
      );
      expect(remedyLine(out), isNot(contains('test-list.md')), reason: out);
    });

    test('U-1483-4: SKIN-ONLY pair — the run-skin stop names the SKIN plan '
        'traces cell (full path), never the absent 04-ENGINE.md', () async {
      const feature = '1483-skin-only-seam';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeBug1483FakeZfa();
      // The SKIN branch of the seam resolution: the engine plan is
      // ABSENT from disk while the skin plan EXISTS and carries the
      // behavior. Two prior shapes cannot reach this branch — a
      // meta-index test list missing a plan file runner-errors in the
      // lane-split reader before any step spawns (test_list_reader.dart),
      // and the meta run routes plan-file features into lane passes
      // where an empty engine pass drives nothing — so the reachable
      // state is the direct `zfa tdd run-skin` over the orphan plan,
      // gated open by a persisted GREEN engine receipt (issue #1008:
      // the skin lane requires the engine certified; the receipt
      // outlives a deleted 04-ENGINE.md).
      await seedVacuousStop(feature);
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      // The orphan skin plan: U1's row lives HERE (the skin bucket's
      // ids resolve from this file), the engine plan does not exist.
      await File(p.join(fx.featureDir, 'tdd', '04-SKIN.md')).writeAsString('''
# Skin Plan: $feature (SKIN + BOTH)

The skin lane (issue #1000): Flutter allowed.

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo with a title | FR-001 | PENDING |
''');
      // The green engine receipt (schema 1, lane_receipts.dart) that
      // opens the engine gate with the engine plan file gone.
      await File(
        p.join(fx.featureDir, 'tdd', '04-engine-receipt.json'),
      ).writeAsString('''
{
  "schema": 1,
  "feature": "$feature",
  "lane": "engine",
  "verdict": "green",
  "result": "complete",
  "behaviors": [],
  "counts": {"total": 0, "pending": 0, "red": 0, "green": 0, "done": 0},
  "stopped_at": null,
  "at": "2026-09-01T00:00:00.000Z"
}
''');
      expect(
        File(p.join(fx.featureDir, 'tdd', '04-ENGINE.md')).existsSync(),
        isFalse,
        reason: 'the seam under test is the skin plan ONLY',
      );

      final out = await drive(feature, command: 'run-skin');

      // The stop machine contract is unchanged on the skin-only shape.
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
      // The skin plan IS the seam here — named with the full path.
      expect(
        remedyLine(out),
        contains(
          'hand-edit the lane plan '
          '(${p.join('specs', feature, 'tdd', '04-SKIN.md')}) '
          'traces cell',
        ),
        reason: out,
      );
      expect(remedyLine(out), isNot(contains('04-ENGINE')), reason: out);
      expect(remedyLine(out), isNot(contains('test-list.md')), reason: out);
    });
  });
}
