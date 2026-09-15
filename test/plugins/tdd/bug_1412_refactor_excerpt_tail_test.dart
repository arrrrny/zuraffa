// Issue #1412 — failed refactor step's console excerpt shows the
// diagnostic TAIL, not the passing preflight head.
//
// The run driver's `_printOutputExcerpt` used `take(3)` — for a refactor
// step the transcript always OPENS with the passing preflight block, so
// the operator saw `runner-error` + `preflight exit: 0` (a contradiction)
// and the real failing pass was only discoverable in the journal. Issue
// #1329 established the tail semantics for the RECORDED evidence (the
// `_outputTail` helper); this suite pins the same semantics for the
// CONSOLE excerpt, and pins the recorded path as byte-identical (the
// hard constraint: cycle-log/journal untouched).
//
// Driver-level tests: the command runs in-process through
// CliRunner.runCapturing; the step commands are the fixture's scripted
// fake zfa binary spawned as real sub-processes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1412-excerpt-tail';

  Future<String> drive() async {
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

  /// The cycle-log's `## `-delimited error section for [behavior].
  Future<String> errorSection(String behavior) async {
    final raw = await File(fx.cycleLogPath).readAsString();
    return raw.split('\n## ').firstWhere(
          (s) =>
              s.contains('- kind: error') &&
              s.contains('- behavior: $behavior'),
        );
  }

  Future<Map<String, dynamic>> readJournal() async =>
      jsonDecode(
            await File(
              p.join(fx.featureDir, 'tdd', 'journal.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'U-1412-1: a failing refactor step shows the failing-pass tail in the '
    'console excerpt, never the passing preflight head (SC-1)',
    () async {
      await fx.setStepOutcome('refactor', 'B-001', 'flood');

      final out = await drive();

      // The stop contract is unchanged (FR-007).
      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains('stopped_at=B-001:refactor'),
        reason: out,
      );

      // The DIAGNOSTIC TAIL is visible: the failing pass is named with
      // its exit code and the misfire-stop verdict (AC-2 of the issue).
      expect(out, contains('pass: build'), reason: out);
      expect(
        RegExp(r'^\s*exit: 1$', multiLine: true).hasMatch(out),
        isTrue,
        reason: 'the failing pass exit code must be visible: $out',
      );
      expect(out, contains('pass "build" failed — misfire-stop.'), reason: out);

      // The PASSING PREFLIGHT HEAD is gone: pre-fix, take(3) printed
      // exactly the preflight block — the issue's contradiction
      // (`runner-error` next to `preflight exit: 0`).
      expect(
        out,
        isNot(contains('preflight exit: 0')),
        reason: 'the passing preflight head must not be the excerpt: $out',
      );
      expect(
        out,
        isNot(contains('preflight noise line 1')),
        reason: 'the head noise must be dropped: $out',
      );
    },
  );

  test(
    'U-1412-2: a transcript deeper than the excerpt carries the honest '
    '_outputTail truncation marker in the console (SC-2 — the reuse proof)',
    () async {
      await fx.setStepOutcome('refactor', 'B-001', 'flood');

      final out = await drive();
      expect(exitCode, isNot(0), reason: out);

      // The marker wording is _outputTail's own (issue #1329) — proof the
      // console path reuses the helper instead of a second implementation.
      expect(out, contains('truncated'), reason: out);
      expect(out, contains('last 10 of 251 lines'), reason: out);
    },
  );

  test(
    'U-1412-3: a short failed transcript prints its lines with NO marker '
    '(SC-3 — the common small-failure case is content-unchanged)',
    () async {
      await fx.setStepOutcome('refactor', 'B-001', 'boom');

      final out = await drive();
      expect(exitCode, isNot(0), reason: out);

      // The failing transcript IS the summary line — it must survive the
      // excerpt verbatim.
      expect(
        out,
        contains('refactor: behavior=B-001 outcome=boom'),
        reason: out,
      );
      // No truncation happened — no marker.
      expect(out, isNot(contains('truncated')), reason: out);
    },
  );

  test(
    'U-1412-4: the RECORDED evidence path is byte-identical to #1329 — '
    'the cycle-log error entry still keeps the last 200 of 251 and the '
    'journal error object still carries the tail (SC-4, hard constraint)',
    () async {
      await fx.setStepOutcome('refactor', 'B-001', 'flood');

      final out = await drive();
      expect(exitCode, isNot(0), reason: out);

      final section = await errorSection('B-001');
      // The #1329 truncation contract, unchanged: last 200 of 251.
      expect(section, contains('truncated'));
      expect(section, contains('200 of 251'));
      // The tail carries the failing pass; the head is dropped —
      // line-anchored (noise lines share prefixes).
      bool hasNoise(int i) => RegExp(
            '^preflight noise line $i\$',
            multiLine: true,
          ).hasMatch(section);
      expect(section, contains('pass "build" failed — misfire-stop.'));
      // The 3 preflight head lines shift the noise index: noise line i is
      // transcript line i+3, so the last-200 window (transcript 52..251)
      // keeps noise lines 49..241 and drops noise lines 1..48.
      expect(hasNoise(49), isTrue);
      expect(hasNoise(48), isFalse);
      expect(section, isNot(contains('preflight exit: 0')));

      // The journal error object carries the same tail (the structured
      // record the run UI re-reads).
      final entries = await readJournal();
      final stopped = [
        ...((entries['entries'] as List).cast<Map<String, dynamic>>())
            .where((e) => e['cycle'] == 'engine' && e['phase'] == 'drive'),
      ].last;
      final error = stopped['error'] as Map<String, dynamic>;
      expect(error['step'], 'refactor');
      expect('$error', contains('misfire-stop'));
      expect('$error', contains('200 of 251'));
    },
  );
}
