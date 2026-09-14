// Bug #1626 — the run driver's make-vacuous-green stop for an ACCEPTANCE
// row must name the hand step (the traces remedy cannot work there).
//
// The make-surface suite (bug_1626_acceptance_vacuous_remedy_test.dart)
// pins the step-3c refusal; this suite drives the REAL RunDriverCore over
// a scripted fake zfa binary (the issue #1308 driver-suite convention,
// mirroring bug_1483_vacuous_green_remedy_driver_test.dart) so the STOP
// transcript — the `--> fix:` line a fresh `zfa tdd run` actually prints —
// is pinned end to end.
//
// Test map:
//   U-1626-d1 — an acceptance row's marker-absent vacuous-green stop
//        prints the hand-step remedy with BOTH paths (test + subject);
//        `stopped_at=A1:make` preserved (the honest fallback-routed
//        class, #1512 — the machine contract is untouched).
//   U-1626-d2 — a unit/fallback row's stop keeps the traces remedy (the
//        #1483 wording, kind-cell rows) — contract preservation
//        (criterion 3: the traces remedy WORKS on the unit lane).
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1626 — the run driver vacuous-green stop (driver level)', () {
    late TddFixture fx;

    /// The scripted fake zfa binary (the issue #1308 shape): gen is
    /// silent, verify-red certifies red, make refuses vacuous-green.
    Future<void> writeBug1626FakeZfa() async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = p.join(fx.fakeZfaDir, 'config');
      await Directory(configDir).create(recursive: true);
      final logPath = p.join(fx.fakeZfaDir, 'log');
      await File(logPath).writeAsString('');
      const script = r'''#!/bin/sh
# Fake zfa CLI for the #1626 driver tests.
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
    /// the captured output.
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

    /// The ONE `--> fix:` remedy line the driver prints on the fallback
    /// vacuous-green stop (the line the bug is about).
    String remedyLine(String out) => out
        .split('\n')
        .firstWhere((l) => l.contains('--> fix:'), orElse: () => '');

    /// Seed the vacuous stop for [id] with [kind]: the test list row, the
    /// generated test at the #827 namespaced layout (guard-only content —
    /// NO vacuous-guard marker, so the stop lands in the marker-absent
    /// branch), and the fake make outcome.
    Future<void> seedVacuousStop(String feature, String id, String kind) async {
      await writeBug1626FakeZfa();
      await fx.seedTestList([
        (
          id: id,
          description: 'lets the user add a todo with a title',
          traces: 'FR-001',
          state: 'PENDING',
          kind: kind,
        ),
      ]);
      final snake = id.toLowerCase().replaceAll('-', '_');
      final testFile = File(
        p.join(fx.root.path, 'test', 'tdd', feature, '${snake}_test.dart'),
      );
      await testFile.parent.create(recursive: true);
      // The acceptance fallback shape (#1512): the guard WITHOUT the
      // vacuous-guard marker — the marker absence is what routes the run
      // driver's stop into the fallback arm.
      await testFile.writeAsString('''
import 'package:test/test.dart';

void main() {
  test('$id — the scenario completes', () {
    final result = (() {
      try {
        return null;
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''');
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-$id'),
      ).writeAsString('vacuous-green');
    }

    test('U-1626-d1: an ACCEPTANCE row\'s stop names the hand step with '
        'both paths; stopped_at=A1:make preserved', () async {
      const feature = '1626-acceptance-stop';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await seedVacuousStop(feature, 'A1', 'acceptance');

      final out = await drive(feature);

      // The stop is the fallback-routed class (the machine contract is
      // untouched — #1308/#1512).
      expect(
        out,
        contains('behavior=A1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=A1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=A1:hand')), reason: out);
      // THE FIX: the hand step is named with both paths (criteria 2+4).
      expect(remedyLine(out), contains('OUTSIDE the capture'), reason: out);
      expect(
        remedyLine(out),
        contains('implement the scenario runner in'),
        reason: out,
      );
      expect(
        remedyLine(out),
        contains(p.join('test', 'tdd', feature, 'a1_test.dart')),
        reason: out,
      );
      expect(
        out,
        contains(p.join('lib', 'tdd', feature, 'a1_subject.dart')),
        reason:
            'the subject path is named (registry-less conventional '
            'layout fallback): $out',
      );
      expect(
        remedyLine(out),
        contains('`zfa tdd make A1 --born-green`'),
        reason: out,
      );
      // The traces remedy is GONE from the acceptance stop.
      expect(
        remedyLine(out),
        isNot(contains('re-run zfa tdd plan')),
        reason: out,
      );
      expect(remedyLine(out), isNot(contains('add traces:')), reason: out);
    });

    test('U-1626-d2: a UNIT/fallback row\'s stop keeps the traces remedy '
        '(the #1483 wording, kind-cell rows)', () async {
      const feature = '1626-unit-stop';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await seedVacuousStop(feature, 'U1', 'unit');

      final out = await drive(feature);

      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      // The traces remedy is KEPT for unit/fallback rows (criterion 3) —
      // where it works.
      expect(
        remedyLine(out),
        contains(
          'hand-edit the test list '
          '(${p.join('specs', feature, 'tdd', 'test-list.md')}) traces cell',
        ),
        reason: out,
      );
      // No hand-step vocabulary leaks into the unit stop.
      expect(
        remedyLine(out),
        isNot(contains('OUTSIDE the capture')),
        reason: out,
      );
      expect(remedyLine(out), isNot(contains('--born-green')), reason: out);
    });
  });
}
