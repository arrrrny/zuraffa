@Tags(['slow'])
// Issue #1482 — the `zfa tdd run` routing-provenance preflight (driver
// tier, slow tier). The fast tier (issue_1482_run_preflight_test.dart)
// covers the service contract; this suite drives the REAL RunCommand
// in-process through CliRunner over a scripted fake zfa binary:
//
//   U-1482-4 — a feature whose routing provenance marks fallback-routed
//              unit rows refuses BEFORE the first gen: the exact refusal
//              block (header, one line per offending row, the Suggested
//              remedy), the all-zero result=stopped summary line, exit 1,
//              ZERO step spawns, and the preflight_red journal entry
//              (FR-002 / FR-004 / SC-1).
//   U-1482-5 — --force bypasses ONLY the routing preflight: the run
//              proceeds into the engine lane and the existing honest
//              vacuous-green stop stays byte-identical (FR-003 / SC-2);
//              the #1303 dependency-overrides gate keeps refusing on its
//              own condition even with --force.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  /// The scripted fake zfa binary: every step is `ok`; a per-step config
  /// file (`<step>-<id>`) overrides the outcome (make's `vacuous-green`
  /// drives the honest stop in the --force scenario).
  Future<void> writeFakeZfa() async {
    await Directory(fx.fakeZfaDir).create(recursive: true);
    final configDir = p.join(fx.fakeZfaDir, 'config');
    await Directory(configDir).create(recursive: true);
    await File(p.join(fx.fakeZfaDir, 'log')).writeAsString('');
    const script = r'''#!/bin/sh
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
  gen) exit 0 ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-09-10T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0 ;;
  make)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-09-10T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
        echo "make: behavior=$ID outcome=green feature=$FEATURE"
        exit 0 ;;
      vacuous-green)
        echo "make: behavior=$ID outcome=vacuous-green feature=$FEATURE"
        exit 1 ;;
      *) echo "make: behavior=$ID outcome=$OUTCOME feature=$FEATURE"; exit 1 ;;
    esac ;;
  refactor)
    echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"
    exit 0 ;;
  *)
    echo "zfa tdd $STEP: unknown step"
    exit 1 ;;
esac
''';
    final bin = File(fx.fakeZfaBin);
    await bin.writeAsString(
      script
          .replaceAll('__LOG__', p.join(fx.fakeZfaDir, 'log'))
          .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
          .replaceAll('__CFG__', configDir),
    );
    Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
  }

  /// A feature whose test list marks U1 and U2 fallback-routed units —
  /// the #1482 repro shape (no generated tests, fresh plan).
  Future<void> seedFallbackFeature(String feature) async {
    await fx.seedTestList([
      (
        id: 'A1',
        description: 'renders the todo list header',
        traces: 'FR-010',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U1',
        description: 'lets the user add a todo with a title',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U2',
        description: 'syncs the queued todos when the network returns',
        traces: 'FR-002',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    final list = File(fx.testListPath);
    await list.writeAsString('''
${await list.readAsString()}
## Routing provenance

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
''');
  }

  Future<String> drive(String feature, {List<String> extra = const []}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
      ...extra,
    ]);
  }

  test(
    'U-1482-4: the preflight refuses before the first gen and names ALL offending rows at once',
    () async {
      const feature = '1482-preflight-refusal';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      await seedFallbackFeature(feature);

      final out = await drive(feature);

      // The structured refusal block (FR-002) — header, ALL offending
      // rows at once, the Suggested remedy.
      expect(
        out,
        contains(
          'run: preflight failed — 2 unit behaviour(s) cannot pass make:',
        ),
        reason: out,
      );
      expect(
        out,
        contains(
          '  U1 — lets the user add a todo with a title '
          '(no declared contract trace, fallback to FR-001)',
        ),
        reason: out,
      );
      expect(
        out,
        contains(
          '  U2 — syncs the queued todos when the network returns '
          '(no declared contract trace, fallback to FR-002)',
        ),
        reason: out,
      );
      expect(
        out,
        contains(
          'Suggested: fix routing in plan, or run `zfa tdd run --force` '
          'to skip preflight.',
        ),
        reason: out,
      );
      // The summary machine contract survives (FR-004): the all-zero
      // stopped line is the run's final stdout line.
      expect(
        out,
        contains(
          'run: feature=$feature result=stopped pending=0 red=0 green=0 done=0',
        ),
        reason: out,
      );
      expect(
        out.trim().split('\n').where((l) => l.trim().isNotEmpty).last,
        contains('result=stopped'),
        reason: out,
      );
      // Exit non-zero (the stopped class).
      expect(CliRunner.lastDispatchedExitCode, 1, reason: out);
      // ZERO steps spawned (SC-1): no gen, no verify-red, no make.
      expect(fx.stepInvocations(), isEmpty, reason: out);
      expect(fx.stepArgvLog(), isEmpty, reason: out);
      // The refusal is journaled preflight_red at the gate phase with
      // one violation per offending row (FR-004).
      final journalFile = File(p.join(fx.featureDir, 'tdd', 'journal.json'));
      expect(journalFile.existsSync(), isTrue, reason: out);
      final journal =
          jsonDecode(journalFile.readAsStringSync()) as Map<String, dynamic>;
      final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry['gate_state'], 'preflight_red');
      expect(entry['phase'], 'gate');
      expect(entry['result'], 'stopped');
      final violations = (entry['violations'] as List<dynamic>).cast<String>();
      expect(violations, hasLength(2), reason: violations.join('\n'));
      expect(violations.first, contains('U1'));
      expect(violations.last, contains('U2'));
    },
  );

  test(
    'U-1482-5: --force bypasses the preflight — the loop drives and the honest vacuous-green stop stays byte-identical',
    () async {
      const feature = '1482-preflight-force';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      await seedFallbackFeature(feature);
      // The engine lane stops honestly at U1:make (the #1308 fallback
      // shape) — exactly as it would have without any preflight.
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

      final out = await drive(feature, extra: const ['--force']);

      // The loop RAN (the preflight was bypassed, not the pipeline):
      // gen + verify-red for A1, then gen + verify-red for U1.
      expect(fx.stepInvocations(), contains('gen A1'), reason: out);
      expect(fx.stepInvocations(), contains('verify-red A1'), reason: out);
      expect(fx.stepInvocations(), contains('make U1'), reason: out);
      // The honest stop is byte-identical to today's (SC-2): same
      // vacuous-green outcome, same stopped_at machine contract, same
      // #1308 remedy line.
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(
        out,
        contains(
          'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
          're-run zfa tdd gen, re-run zfa tdd run',
        ),
        reason: out,
      );
      expect(CliRunner.lastDispatchedExitCode, 1, reason: out);
      // No preflight refusal line anywhere in the transcript.
      expect(out, isNot(contains('preflight failed')), reason: out);
    },
  );

  test(
    'U-1482-5b: a declared-routed feature passes the preflight and drives unchanged (no --force needed)',
    () async {
      const feature = '1482-preflight-declared';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'formats the stored title',
          traces: 'FR-001, Formatter.format',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      final list = File(fx.testListPath);
      await list.writeAsString('''
${await list.readAsString()}
## Routing provenance

route: U1 -> unit lane (func surface) [declared: contract row Formatter.format]
''');

      final out = await drive(feature);

      // The loop drove A1-less: gen U1 straight through to green.
      expect(fx.stepInvocations(), contains('gen U1'), reason: out);
      expect(fx.stepInvocations(), contains('make U1'), reason: out);
      expect(out, contains('result=complete'), reason: out);
      expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
    },
  );

  test(
    'U-1482-5c: --force does NOT bypass the #1303 dependency-overrides gate',
    () async {
      const feature = '1482-preflight-force-1303';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      await seedFallbackFeature(feature);
      // A stale path override pointing at a directory without a
      // pubspec.yaml — the #1303 preflight's own condition.
      await File(p.join(fx.root.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dependency_overrides:
  some_pkg:
    path: ../../does-not-exist
''');

      final out = await drive(feature, extra: const ['--force']);

      // The #1303 gate fired DESPITE --force (its own semantics intact).
      expect(out, contains('preflight: dependency_overrides'), reason: out);
      expect(fx.stepInvocations(), isEmpty, reason: out);
      expect(CliRunner.lastDispatchedExitCode, 3, reason: out);
      // And the routing preflight never ran (the #1303 gate sits first).
      expect(out, isNot(contains('cannot pass make')), reason: out);
    },
  );
}
