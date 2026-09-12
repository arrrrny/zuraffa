// Issue #1482 — the `zfa tdd run` routing-provenance preflight's COMMAND
// WIRING, in the FAST tier. The service contract lives in
// issue_1482_run_preflight_test.dart; the --force interaction lives in the
// slow-tagged issue_1482_run_preflight_driver_test.dart. The refusal
// wiring below is lifted here (untagged) because `dart_test.yaml` excludes
// `slow` by default — CI never ran the refusal path, so a wiring
// regression (a dropped gate, a swallowed journal, a stray spawn) could
// ship uncaught.
//
//   U-1482-4 — a feature whose routing provenance marks fallback-routed
//              unit rows refuses BEFORE the first gen: the exact refusal
//              block (header, one line per offending row, the Suggested
//              remedy), the all-zero result=stopped summary line, exit 1,
//              ZERO step spawns, and the preflight_red journal entry
//              (FR-002 / FR-004 / SC-1).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

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
      await fx.writeFakeZfa();
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
}
