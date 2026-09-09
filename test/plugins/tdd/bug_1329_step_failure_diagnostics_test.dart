@Tags(['slow'])
// Bug #1329 — failed step zero diagnostics: the run driver's
// error-outcome path records the same diagnostic evidence the red/green
// cycles already record (the spawned command, the exit code, and the
// truncated stderr/stdout tail) in BOTH the append-only cycle log and
// the lane journal entry, appended (never overwritten) so a transient
// failure keeps its audit trail after a successful retry.
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
import 'package:zuraffa/zuraffa.dart' show JournalSchema;

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1329-diagnostics';

  Future<String> drive({String? zfaBin}) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin ?? fx.fakeZfaBin,
    ]);
  }

  Future<void> seedOne() => fx.seedTestList([
    (
      id: 'B-001',
      description: 'first behavior',
      traces: 'FR-001',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);

  /// The cycle-log's `## `-delimited sections in file order, as
  /// (behavior, kind) pairs — sections without a behavior line skipped.
  Future<List<(String, String)>> cycleSections() async {
    final raw = await File(fx.cycleLogPath).readAsString();
    final sections = <(String, String)>[];
    for (final section in raw.split('\n## ')) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      final kind =
          RegExp(
            r'^- kind: (\S+)',
            multiLine: true,
          ).firstMatch(section)?.group(1) ??
          '';
      sections.add((behavior.group(1)!, kind));
    }
    return sections;
  }

  Future<Map<String, dynamic>> readJournal() async =>
      jsonDecode(
            await File(
              p.join(fx.featureDir, 'tdd', 'journal.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;

  /// The journal's lane `drive` entries in append order.
  Future<List<Map<String, dynamic>>> laneEntries() async {
    final journal = await readJournal();
    return [
      for (final entry in journal['entries'] as List)
        if ((entry as Map<String, dynamic>)['cycle'] == 'engine' &&
            entry['phase'] == 'drive')
          entry,
    ];
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await seedOne();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'U-1329-1: a failing gen step appends ONE cycle-log error entry with '
    'the spawned command, the exit code, and the child output tail',
    () async {
      await fx.setStepOutcome('gen', 'B-001', 'boom');

      final out = await drive();

      // The stop contract is unchanged (FR-004).
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('[run] B-001 gen -> error'), reason: out);
      expect(out, contains('stopped_at=B-001:gen'), reason: out);

      // FR-001: the error entry exists, in the same evidence shape the
      // red/green cycles record.
      final sections = await cycleSections();
      expect(
        sections,
        contains(('B-001', 'error')),
        reason:
            'cycle-log missing the error entry:\n'
            '${await File(fx.cycleLogPath).readAsString()}',
      );
      final log = await File(fx.cycleLogPath).readAsString();
      final errorSection = log
          .split('\n## ')
          .firstWhere((s) => s.contains('- kind: error'));
      expect(errorSection, contains('- behavior: B-001'));
      expect(errorSection, contains('- outcome: error'));
      // The spawned command line (the fake zfa spawn carrying the step
      // argv).
      expect(errorSection, contains('tdd gen B-001'));
      // The step process's exit code.
      expect(errorSection, contains('- exit: 1'));
      // The child's stderr/stdout tail.
      expect(errorSection, contains('zfa tdd gen: boom'));
    },
  );

  test('U-1329-2: the lane journal entry carries the structured error object '
      'and the step_error violations line, schema-valid', () async {
    await fx.setStepOutcome('gen', 'B-001', 'boom');

    final out = await drive();
    expect(exitCode, isNot(0), reason: out);

    final entries = await laneEntries();
    expect(entries, isNotEmpty, reason: out);
    final stopped = entries.last;

    // FR-002: not just "violations": ["stopped_at=..."].
    final violations = (stopped['violations'] as List).cast<String>();
    expect(violations, contains('stopped_at=B-001:gen'));
    expect(
      violations.any(
        (v) =>
            v.startsWith('step_error=B-001:gen') &&
            v.contains('outcome=error') &&
            v.contains('exit=1'),
      ),
      isTrue,
      reason: '$violations',
    );

    final error = stopped['error'] as Map<String, dynamic>;
    expect(error['behavior'], 'B-001');
    expect(error['step'], 'gen');
    expect(error['outcome'], 'error');
    expect(error['exit_code'], 1);
    expect('$error', contains('tdd gen B-001'));
    expect('$error', contains('boom'));

    // The written journal validates against the generated schema walk
    // (the error object is schema-declared, never additional).
    expect(JournalSchema.validateEntry(stopped), isEmpty);
  });

  test('U-1329-3: the error entry is NOT red/green evidence — the retry '
      're-drives gen and the full cycle completes', () async {
    // Attempt 1 fails (boom), attempt 2 succeeds (ok) — the
    // non-deterministic-transient shape from the issue.
    await fx.setStepOutcome('gen', 'B-001', 'boom\nok');

    final first = await drive();
    expect(exitCode, isNot(0), reason: first);

    final second = await drive();
    expect(exitCode, 0, reason: second);

    // The retry re-drove gen (gen invoked once per run). Had the error
    // entry polluted the red evidence, reconciliation would have
    // promoted B-001 to red and re-entered at make — no second gen.
    expect(fx.stepInvocations(), [
      'gen B-001',
      'gen B-001',
      'verify-red B-001',
      'make B-001',
      'refactor B-001',
    ]);
    final state =
        jsonDecode(await File(fx.runStatePath).readAsString())
            as Map<String, dynamic>;
    expect(state['behavior_states']['B-001'], 'done');
  });

  test(
    'U-1329-4: a successful retry PRESERVES the failure diagnostics '
    '(appended, never overwritten) in the cycle log and the journal',
    () async {
      await fx.setStepOutcome('gen', 'B-001', 'boom\nok');

      final first = await drive();
      expect(exitCode, isNot(0), reason: first);
      final second = await drive();
      expect(exitCode, 0, reason: second);

      // Cycle log: failure entry first, the retry's red/green appended
      // after — the audit trail survives the success.
      final kinds = [
        for (final (behavior, kind) in await cycleSections())
          if (behavior == 'B-001') kind,
      ];
      expect(kinds, ['error', 'red', 'green']);

      // Journal: both lane drive entries exist in append order; the
      // first (the failed run) still carries the error object.
      final entries = await laneEntries();
      expect(entries.length, 2);
      final failed = entries.first;
      final retried = entries.last;
      expect((failed['error'] as Map<String, dynamic>)['step'], 'gen');
      expect(failed['gate_state'], 'red');
      expect(retried.containsKey('error'), isFalse);
      expect(retried['gate_state'], 'green');

      // The failure's child output survives verbatim in the cycle log.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('zfa tdd gen: boom'));
    },
  );

  test('U-1329-5: output longer than 200 lines is truncated to the LAST 200 '
      'with an honest truncation marker', () async {
    await fx.setStepOutcome('gen', 'B-001', 'flood');

    final out = await drive();
    expect(exitCode, isNot(0), reason: out);

    final log = await File(fx.cycleLogPath).readAsString();
    final errorSection = log
        .split('\n## ')
        .firstWhere((s) => s.contains('- kind: error'));
    // The tail: the final error line survives; the head is dropped.
    // Line-anchored matches — 'gen noise line 1' is a substring of
    // every kept 1XX line, so bare `contains` would false-positive.
    bool hasNoiseLine(int i) =>
        RegExp('^gen noise line $i\$', multiLine: true).hasMatch(errorSection);
    expect(errorSection, contains('zfa tdd gen: final error line'));
    expect(hasNoiseLine(250), isTrue);
    expect(hasNoiseLine(52), isTrue);
    expect(hasNoiseLine(1), isFalse);
    expect(hasNoiseLine(51), isFalse);
    // The marker names the truncation honestly.
    expect(errorSection, contains('truncated'));
    expect(errorSection, contains('200 of 251'));
    // The journal error object carries the same tail.
    final entries = await laneEntries();
    final error = entries.last['error'] as Map<String, dynamic>;
    expect('$error', contains('final error line'));
    expect('$error', contains('200 of 251'));
  });

  test('U-1329-6: a failing make step records the make spawn and its own '
      'outcome token; a spawn failure records exit -1 and the failure '
      'message', () async {
    await fx.setStepOutcome('make', 'B-001', 'crashed');

    final out = await drive();
    expect(exitCode, isNot(0), reason: out);
    expect(out, contains('stopped_at=B-001:make'), reason: out);

    final log = await File(fx.cycleLogPath).readAsString();
    final errorSection = log
        .split('\n## ')
        .firstWhere((s) => s.contains('- kind: error'));
    expect(errorSection, contains('- outcome: crashed'));
    expect(errorSection, contains('tdd make B-001'));
    expect(errorSection, contains('- exit: 1'));
    expect(errorSection, contains('outcome=crashed'));
    // The certified red evidence from verify-red is untouched.
    expect(log, contains('- kind: red'));

    // Spawn failure: the zfa binary does not exist — exit -1, the
    // spawn-failure message is the recorded output.
    fx.dispose();
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await seedOne();
    final missing = p.join(fx.root.path, 'missing-zfa');
    final out2 = await drive(zfaBin: missing);
    expect(exitCode, isNot(0), reason: out2);
    final log2 = await File(fx.cycleLogPath).readAsString();
    final error2 = log2
        .split('\n## ')
        .firstWhere((s) => s.contains('- kind: error'));
    expect(error2, contains('- exit: -1'));
    expect(error2, contains('spawn failed'));
    expect(error2, contains('tdd gen B-001'));
    final entries = await laneEntries();
    final journalError = entries.last['error'] as Map<String, dynamic>;
    expect(journalError['outcome'], 'runner-error');
    expect(journalError['exit_code'], -1);
  });

  test('U-1329-7: a fully green run records no error evidence (backward '
      'compatibility)', () async {
    final out = await drive();

    expect(exitCode, 0, reason: out);
    final sections = await cycleSections();
    expect(sections, contains(('B-001', 'red')));
    expect(sections, contains(('B-001', 'green')));
    expect(sections.where((s) => s.$2 == 'error'), isEmpty, reason: out);
    final entries = await laneEntries();
    expect(entries.last.containsKey('error'), isFalse);
    expect(entries.last['gate_state'], 'green');
  });
}
