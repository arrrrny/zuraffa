@Tags(['slow'])
// Bug #828 — cycle-log evidence integrity: run-state, artifacts, and
// cycle-log must never disagree.
//
// RED evidence: an interrupted run leaves run-state.json claiming a
// behavior green (or done) while tdd/cycle-log.md carries no matching
// evidence. The resume re-enters at refactor (state-implied window), the
// driver's evidence misfire gate correctly refuses (no red+green proof),
// and the run hard-stops with result=runner-error on EVERY resume — the
// corpus is stuck. These tests drive the full loop through the fixture's
// scripted fake zfa exactly like run_command_test.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';
import 'package:zuraffa/src/simulation/fixture_registry.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-828';

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

  Future<String> doctor() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'doctor',
      // Issue #1585: doctor takes the feature POSITIONALLY — it declares
      // only --json/--repair/--project, so a --feature flag is a usage error.
      feature,
      '--project',
      fx.root.path,
    ]);
  }

  Future<Map<String, dynamic>> readState() async =>
      jsonDecode(await File(fx.runStatePath).readAsString())
          as Map<String, dynamic>;

  /// The write-ahead transaction path (`tdd/transaction.json`), sibling
  /// of the run state file (renamed from `tdd/journal.json` by spec 1113
  /// — the unified TDD journal owns that name now).
  String journalPath() =>
      p.join(p.dirname(fx.runStatePath), 'transaction.json');

  Future<void> seedJournal({
    required String behavior,
    required String step,
    int? ownerPid,
  }) async {
    final file = File(journalPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'schema': 1,
        'feature': feature,
        'behavior': behavior,
        'step': step,
        'pid': ownerPid ?? 1,
        'at': '2026-09-01T00:00:00.000Z',
        'status': 'pending',
      }),
    );
  }

  Future<void> seedRefactorEvidence({required int exitCode}) async {
    await CycleLog(p.join(fx.root.path, 'specs', feature)).append(
      CycleLogEntry(
        behaviorId: '$feature-refactor',
        kind: CycleEntryKind.refactor,
        runnerCommand: 'dart test',
        exitCode: exitCode,
        capturedOutput: 're-proof exit: $exitCode',
        sourceCriterion: 'FR-3',
        testPath: 'test/',
        timestamp: '2026-09-01T00:00:01.000Z',
      ),
    );
  }

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

  group('resume reconciliation (evidence beats every claim)', () {
    test('bug 828 RED: a green claim with gen artifacts but NO cycle-log '
        'evidence is re-driven from the earliest incomplete step instead of '
        'hard-stopping at refactor', () async {
      // The interrupted-run state: gen completed (the registry has the
      // record), run-state says green, but the cycle-log lost/never got
      // the red and green entries. Pre-fix this re-enters at refactor,
      // the evidence misfire gate refuses, and the run stops with
      // result=runner-error — forever.
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRunState(states: {'B-001': 'green'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // Reset to the earliest incomplete step: red was never certified,
      // so the behavior re-drives the full cycle honestly.
      expect(fx.stepInvocations().first, 'gen B-001', reason: out);
      final state = await readState();
      expect(state['behavior_states']['B-001'], 'done', reason: out);
    });

    test('bug 828 RED: a green claim with red evidence but no green evidence '
        're-enters at make (the earliest incomplete step)', () async {
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'green'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // Red is certified, green is not: re-enter at make.
      expect(fx.stepInvocations().first, 'make B-001', reason: out);
      expect(
        fx.stepInvocations().where((l) => l == 'gen B-001'),
        isEmpty,
        reason: out,
      );
      final state = await readState();
      expect(state['behavior_states']['B-001'], 'done', reason: out);
    });

    test('bug 828: a green claim WITH complete red+green evidence keeps its '
        'resume semantics (re-enters at refactor) — legitimate state is not '
        'lost', () async {
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'green'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), ['refactor B-001'], reason: out);
    });
  });

  group('write-ahead journal (single transactional writer)', () {
    test('bug 828 RED: a pending journal whose evidence landed is replayed — '
        'the state advance is applied without re-spawning the step', () async {
      // Crash window: make's child appended the green evidence and
      // exited, the driver died before committing run-state. The dead
      // in-flight marker plus the pending journal describe the exact
      // interrupted step.
      final dead = await Process.start('sh', ['-c', 'exit 0']);
      final deadPid = dead.pid;
      await dead.exitCode;
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRunState(
        states: {'B-001': 'red'},
        inFlightBehaviorId: 'B-001',
        inFlightStep: 'make',
        inFlightOwnerPid: deadPid,
      );
      await seedJournal(behavior: 'B-001', step: 'make', ownerPid: deadPid);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // The journal replay completes the make transition: make is NOT
      // re-spawned; only the owed refactor runs.
      expect(fx.stepInvocations(), ['refactor B-001'], reason: out);
      final state = await readState();
      expect(state['behavior_states']['B-001'], 'done', reason: out);
    });

    test('bug 828: a pending journal whose evidence never landed is discarded '
        'and the interrupted step re-drives honestly', () async {
      final dead = await Process.start('sh', ['-c', 'exit 0']);
      final deadPid = dead.pid;
      await dead.exitCode;
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedRunState(
        states: {'B-001': 'red'},
        inFlightBehaviorId: 'B-001',
        inFlightStep: 'make',
        inFlightOwnerPid: deadPid,
      );
      await seedJournal(behavior: 'B-001', step: 'make', ownerPid: deadPid);

      final out = await drive();

      expect(exitCode, 0, reason: out);
      // No green evidence in the cycle-log: the journal cannot prove
      // the make completed, so make re-runs (write-ahead is intent,
      // not a claim of success).
      expect(fx.stepInvocations().first, 'make B-001', reason: out);
      final state = await readState();
      expect(state['behavior_states']['B-001'], 'done', reason: out);
    });

    test(
      'a failed refactor diagnostic does not complete journal replay',
      () async {
        final dead = await Process.start('sh', ['-c', 'exit 0']);
        final deadPid = dead.pid;
        await dead.exitCode;
        await fx.registerBehavior(id: 'B-001', description: 'first behavior');
        await fx.seedRedEvidence('B-001');
        await fx.seedGreenEvidence('B-001');
        await fx.seedRunState(
          states: {'B-001': 'green'},
          inFlightBehaviorId: 'B-001',
          inFlightStep: 'refactor',
          inFlightOwnerPid: deadPid,
        );
        await seedJournal(
          behavior: 'B-001',
          step: 'refactor',
          ownerPid: deadPid,
        );
        await seedRefactorEvidence(exitCode: 1);

        final out = await drive();

        expect(exitCode, 0, reason: out);
        expect(fx.stepInvocations(), ['refactor B-001'], reason: out);
      },
    );

    test(
      'a successful refactor entry still completes journal replay',
      () async {
        final dead = await Process.start('sh', ['-c', 'exit 0']);
        final deadPid = dead.pid;
        await dead.exitCode;
        await fx.registerBehavior(id: 'B-001', description: 'first behavior');
        await fx.seedRedEvidence('B-001');
        await fx.seedGreenEvidence('B-001');
        await fx.seedRunState(
          states: {'B-001': 'green'},
          inFlightBehaviorId: 'B-001',
          inFlightStep: 'refactor',
          inFlightOwnerPid: deadPid,
        );
        await seedJournal(
          behavior: 'B-001',
          step: 'refactor',
          ownerPid: deadPid,
        );
        await seedRefactorEvidence(exitCode: 0);

        final out = await drive();

        expect(exitCode, 0, reason: out);
        expect(fx.stepInvocations(), isEmpty, reason: out);
        expect(out, contains('refactor -> replayed'), reason: out);
      },
    );

    test('bug 828: every committed step clears the journal — a completed run '
        'leaves no pending transaction behind', () async {
      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(
        File(journalPath()).existsSync(),
        isFalse,
        reason: 'journal must be cleared after the final commit: $out',
      );
    });
  });

  group('zfa tdd doctor (drift reporting with fix lines)', () {
    test('bug 828 RED: doctor reports a green claim without evidence as drift '
        'and prescribes the resume fix', () async {
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRunState(states: {'B-001': 'green'});

      final out = await doctor();

      expect(exitCode, 1, reason: out);
      expect(out, contains('drift'), reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('B-001'), reason: out);
    });

    test('bug 828 RED: doctor exits 0 on consistent stores', () async {
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      // registerBehavior writes the registry record and the test file but
      // not the subject; the doctor's registry check reads both paths.
      final subject = File(fx.subjectPathOf('B-001'));
      await subject.parent.create(recursive: true);
      await subject.writeAsString('String b001() => "42";\n');
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'done'});

      final out = await doctor();

      expect(exitCode, 0, reason: out);
      // Issue #1585: the legacy `doctor: feature=<f> drifts=<n>` summary
      // line was replaced by the verdict envelope (bug #840 / issue
      // #969); zero drifts is now the empty `drifts` array on the final
      // machine-readable line.
      final verdict =
          jsonDecode(out.trim().split('\n').last) as Map<String, dynamic>;
      expect(verdict['verdict'], 'healthy', reason: out);
      expect(verdict['drifts'], isEmpty, reason: out);
    });

    test('bug 828 RED: a pending journal is reported as an interrupted '
        'transaction with a fix line', () async {
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRunState(states: {'B-001': 'red'});
      await seedJournal(behavior: 'B-001', step: 'make');

      final out = await doctor();

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
    });
  });

  group('versioned evidence schema with per-behavior hash chain', () {
    test('bug 828 RED: entries written through CycleLog carry schema + hash '
        'chain lines and chain per behavior (red -> green)', () async {
      final dir = await Directory.systemTemp.createTemp('bug828_chain_');
      addTearDown(() => dir.delete(recursive: true));
      final log = CycleLog(dir.path);
      final base = DateTime.now().toUtc().toIso8601String();

      await log.append(
        CycleLogEntry(
          behaviorId: 'B-001',
          kind: CycleEntryKind.red,
          runnerCommand: 'dart test b_001_test.dart',
          exitCode: 1,
          capturedOutput: 'Expected: <2>\n  Actual: <1>',
          classification: FailureClass.assertionFailure,
          sourceCriterion: 'FR-001',
          testPath: 'test/tdd/b_001_test.dart',
          timestamp: base,
        ),
      );
      await log.append(
        CycleLogEntry(
          behaviorId: 'B-001',
          kind: CycleEntryKind.green,
          runnerCommand: 'dart test b_001_test.dart',
          exitCode: 0,
          capturedOutput: 'All tests passed!',
          sourceCriterion: 'FR-001',
          testPath: 'test/tdd/b_001_test.dart',
          timestamp: base,
        ),
      );

      final raw = await File(
        p.join(dir.path, 'tdd', 'cycle-log.md'),
      ).readAsString();
      expect(raw, contains('- schema: 1'), reason: raw);
      expect(raw, contains('- hash: '), reason: raw);

      // Chain: the green entry's prev-hash is the red entry's hash.
      final hashes = RegExp(
        r'^- hash: ([0-9a-f]{64})$',
        multiLine: true,
      ).allMatches(raw).toList();
      final prevHashes = RegExp(
        r'^- prev-hash: (\S+)$',
        multiLine: true,
      ).allMatches(raw).toList();
      expect(hashes, hasLength(2), reason: raw);
      expect(prevHashes, hasLength(2), reason: raw);
      expect(prevHashes.last.group(1), hashes.first.group(1), reason: raw);
    });

    test('bug 828 RED: doctor detects a tampered hash chain and prescribes a '
        'fix', () async {
      // CycleLog takes a FEATURE dir and appends under <feature>/tdd/;
      // fx.cycleLogPath is <feature>/tdd/cycle-log.md.
      final log = CycleLog(p.dirname(p.dirname(fx.cycleLogPath)));
      await log.append(
        CycleLogEntry(
          behaviorId: 'B-001',
          kind: CycleEntryKind.red,
          runnerCommand: 'dart test b_001_test.dart',
          exitCode: 1,
          capturedOutput: 'Expected: <2>\n  Actual: <1>',
          classification: FailureClass.assertionFailure,
          sourceCriterion: 'FR-001',
          testPath: 'test/tdd/b_001_test.dart',
          timestamp: '2026-09-01T00:00:00.000Z',
        ),
      );
      // Tamper: rewrite the exit code in place; the hash no longer
      // matches the entry content.
      final file = File(fx.cycleLogPath);
      await file.writeAsString(
        (await file.readAsString()).replaceAll('- exit: 1', '- exit: 2'),
      );

      final out = await doctor();

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out.toLowerCase(), contains('hash'), reason: out);
    });

    test('bug 828 RED: doctor detects a broken prev-hash LINKAGE (the '
        'reordered/edited trail) and prescribes a fix', () async {
      // The content arm covers `- hash:`; the linkage arm covers
      // `- prev-hash:`. This pin isolates the linkage walk: the recorded
      // prev-hash no longer chains, so the drift must name the linkage
      // ("does not link") — a walk that only recomputed content digests
      // would read this trail as healthy.
      final log = CycleLog(p.dirname(p.dirname(fx.cycleLogPath)));
      await log.append(
        CycleLogEntry(
          behaviorId: 'B-001',
          kind: CycleEntryKind.red,
          runnerCommand: 'dart test b_001_test.dart',
          exitCode: 1,
          capturedOutput: 'Expected: <2>\n  Actual: <1>',
          classification: FailureClass.assertionFailure,
          sourceCriterion: 'FR-001',
          testPath: 'test/tdd/b_001_test.dart',
          timestamp: '2026-09-01T00:00:00.000Z',
        ),
      );
      // Tamper: sever the link to the genesis hash — the trail no longer
      // chains.
      final file = File(fx.cycleLogPath);
      await file.writeAsString(
        (await file.readAsString()).replaceAll(
          '- prev-hash: ${CycleLog.genesisHash}',
          '- prev-hash: '
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );

      final out = await doctor();

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('does not link'), reason: out);
    });

    test('review #1612: a fixtures section written through the converged '
        'certifier chain is NOT reported as tampering', () async {
      // The certifier writer chains through CycleLog.chainHashFromFields
      // (the canonical payload) and keeps the manifest digest in its own
      // `- digest:` field, so the doctor's walk verifies the section
      // instead of flagging every committed simulation certification.
      final fixturesDir = p.join(fx.featureDir, 'tdd', 'fixtures');
      await Directory(fixturesDir).create(recursive: true);
      await File(
        p.join(fixturesDir, 'auth-world.json'),
      ).writeAsString('{"uid":"u-1"}\n');
      final registry = FixtureRegistry(fixturesDir);
      await registry.writeManifest(families: ['firebase-auth']);
      await registry.appendCycleEvidence(
        featureDir: fx.featureDir,
        families: ['firebase-auth'],
        commandLine:
            'zfa simulate --scaffold specs/$feature --family firebase-auth',
      );

      final out = await doctor();

      expect(exitCode, 0, reason: out);
      final verdict =
          jsonDecode(out.trim().split('\n').last) as Map<String, dynamic>;
      expect(verdict['verdict'], 'healthy', reason: out);
      expect(verdict['drifts'], isEmpty, reason: out);
    });

    test('review #1612: a LEGACY foreign-writer section (the manifest '
        'digest in - hash:) is tolerated, never failed', () async {
      // The pre-convergence committed format: the certifier stamped the
      // manifest digest into `- hash:`, a payload the canonical walk
      // cannot rebuild. It must not read as tampering.
      await File(fx.cycleLogPath).parent.create(recursive: true);
      await File(fx.cycleLogPath).writeAsString(
        '# Cycle Log\n\n'
        '## 2026-09-01T00:00:00Z: certified simulation fixtures (bug #832)\n'
        '- behavior: $feature-fixtures\n'
        '- kind: fixtures\n'
        '- at: 2026-09-01T00:00:00Z\n'
        '- exit: 0\n'
        '- criterion: certified fixture world committed under tdd/fixtures/ '
        'and hashed into the manifest digest\n'
        '- command: `zfa simulate --scaffold specs/$feature`\n'
        '- schema: 1\n'
        '- prev-hash: genesis\n'
        '- hash: d08179e0${'0' * 56}\n',
      );

      final out = await doctor();

      expect(exitCode, 0, reason: out);
      expect(
        jsonDecode(out.trim().split('\n').last)['verdict'],
        'healthy',
        reason: out,
      );
    });

    test(
      'review #1612: a chain-claiming section whose - hash: line is '
      'rewritten to non-hex is reported — the hash-less tail bypass',
      () async {
        // The bypass the walk could not see: the LAST hashed entry of a
        // behavior, its `- hash:` line mangled (not deleted) so the parser
        // stops capturing it — the section still advertises `- schema: 1`
        // / `- prev-hash:`, so the guard must report it instead of
        // skipping.
        final log = CycleLog(p.dirname(p.dirname(fx.cycleLogPath)));
        await log.append(
          CycleLogEntry(
            behaviorId: 'B-001',
            kind: CycleEntryKind.red,
            runnerCommand: 'dart test b_001_test.dart',
            exitCode: 1,
            capturedOutput: 'Expected: <2>\n  Actual: <1>',
            classification: FailureClass.assertionFailure,
            sourceCriterion: 'FR-001',
            testPath: 'test/tdd/b_001_test.dart',
            timestamp: '2026-09-01T00:00:00.000Z',
          ),
        );
        final file = File(fx.cycleLogPath);
        final raw = await file.readAsString();
        final recorded = RegExp(
          r'^- hash: ([0-9a-f]{64})$',
          multiLine: true,
        ).firstMatch(raw)!;
        await file.writeAsString(
          raw.replaceFirst(
            recorded.group(0)!,
            '- hash: ${recorded.group(1)!.toUpperCase()}',
          ),
        );

        final out = await doctor();

        expect(exitCode, 1, reason: out);
        expect(out, contains('cannot be verified'), reason: out);
      },
    );
  });
}
