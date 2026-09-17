// Issue #1652 — on a forward `zfa tdd run`, every behavior's phase-1
// refactor spawn follows its make-green with zero external edits in
// between, yet it re-pays the full pipeline (full-suite preflight + pass
// registry + re-proof). The #1624/#1588 pass-batch ledger can never
// inherit here: forward progress changes `lib/` on every make, so each
// spawn's tree differs from the LAST REFRACTOR's proved tree — by
// construction. What it does equal is the THIS MAKE's certified
// post-state, and make just ran its live green evidence on exactly that
// tree.
//
// Fix under test: the driving run records make's certified post-state
// (`tdd/make-post-state.json`); a `--pass-batch` refactor spawn whose
// tree and gate context match that record inherits the pipeline — the
// same inherit semantics, honest evidence, and fallback rules as the
// #1588 ledger hit.
//
// Harness: the #1588 command-level shape — the real `zfa tdd refactor`
// against a fixture project, with the suite template pointed at a
// logging wrapper so the economics assertions count actual suite spawns.
// Every mismatch dimension (drift, baseline, config, exempt set, corrupt
// record, missing opt-in, --full-reproof) must keep running the full
// pipeline — the guards are green-by-design pre-fix.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/pass_batch_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  group('command level — make-post-state inheritance (--pass-batch)', () {
    late TddFixture fx;
    late String fakeZfa;
    late String suiteLogPath;
    late String suiteScript;

    Future<String> runRefactor({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
        '--zfa-bin',
        fakeZfa,
        ...extraArgs,
      ]);
    }

    Future<int> suiteSpawnCount() async {
      final file = File(suiteLogPath);
      if (!await file.exists()) return 0;
      final raw = await file.readAsString();
      return raw.split('\n').where((l) => l.trim().isNotEmpty).length;
    }

    /// Write a make-post-state record for the CURRENT tree under the
    /// CURRENT gate context (the same helpers the driving run and the
    /// refactor both use). [exempt] seeds a differing exempt set;
    /// [baselinePath] ties the record to a baseline file's bytes.
    Future<File> writeRecord({
      List<String> exempt = const [],
      String? baselinePath,
      String behaviorId = 'U1',
    }) async {
      final libNow = await TreeSnapshot.capture(
        fx.root.path,
        trees: const ['lib'],
      );
      final testNow = await TreeSnapshot.capture(
        fx.root.path,
        trees: const ['test'],
      );
      final record = {
        'captured_at': '2026-09-15T10:00:00.000Z',
        'behavior_id': behaviorId,
        'suite': suiteScript,
        'baseline_key': await PassBatchLedger.baselineKeyFor(baselinePath),
        'config_key': await PassBatchLedger.configKeyFor(fx.root.path),
        'exempt_behaviors': exempt,
        'lib_digest': PassBatchLedger.treeDigest(libNow),
        'test_digest': PassBatchLedger.treeDigest(testNow),
        'green_verdict':
            'make $behaviorId outcome=green exit 0 (post-generation green '
            'evidence)',
      };
      final file = File(p.join(fx.featureDir, 'tdd', 'make-post-state.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(record));
      return file;
    }

    setUp(() async {
      fx = await TddFixture.create();
      fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
      await fx.seedAlreadyCleanLib();
      // A suite template that logs each spawn and delegates to the real
      // `dart test` — the economics assertions count preflights +
      // re-proofs (the #1588 harness shape).
      final binDir = Directory(p.join(fx.root.path, 'suite_bin'));
      await binDir.create(recursive: true);
      suiteScript = p.join(binDir.path, 'suite.sh');
      suiteLogPath = p.join(fx.root.path, 'suite_spawns.log');
      await File(suiteScript).writeAsString('''
#!/usr/bin/env bash
echo "suite spawn: \$*" >> "$suiteLogPath"
exec dart test "\$@"
''');
      await Process.run('chmod', ['+x', suiteScript]);
      // Point the profile's full-suite key at the logging wrapper.
      final memoryDir = Directory(p.join(fx.root.path, '.specify', 'memory'));
      await memoryDir.create(recursive: true);
      await File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `dart test --plain-name x`
- Full suite: `$suiteScript`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test --plain-name x'
suite: '$suiteScript'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('T1 (tripwire): the fixture\'s make-generated tree is dart '
        'format-clean — the premise the inherited rung rests on', () async {
      // With the make-post-state record, on an unchanged tree BOTH the
      // phase-1 spawn and the first phase-2b spawn inherit — the pass
      // registry (dart format / dart fix) runs nowhere between
      // make-green and the feature-completion gate. That is safe only
      // while make-generated output stays format/fix-clean (research
      // R2's one-time measurement). Pin the premise on the fixture
      // tree so a drift here turns red instead of silently
      // accumulating until feature completion.
      final result = await Process.run('dart', [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        p.join(fx.root.path, 'lib'),
        p.join(fx.root.path, 'test'),
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test(
      'A1: a --pass-batch refactor on the make-certified tree inherits the '
      'pipeline — zero suite spawns, honest evidence, ledger untouched',
      () async {
        await writeRecord(behaviorId: 'U2');
        final ledgerPath = p.join(fx.featureDir, 'tdd', 'pass-batch.json');

        final out = await runRefactor(extraArgs: ['--pass-batch']);

        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains(RegExp(r'outcome=(clean|refactored)')),
          reason: out,
        );
        // THE economics assertion: the pipeline is inherited — zero
        // suite spawns (no preflight, no re-proof).
        expect(await suiteSpawnCount(), 0, reason: out);
        // The inheritance is named honestly: which issue, which make,
        // and that the full suite did NOT run at this tree.
        expect(out, contains('1652'));
        expect(out, contains('make-post-state'));
        expect(out, contains('U2'));
        // The cycle-log entry records the no-op inheritance.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('1652'));
        expect(cycleLog, contains('U2'));
        // The record never overwrites the refactor-proved ledger
        // (FR-007): none existed, none was fabricated.
        expect(File(ledgerPath).existsSync(), isFalse);
      },
    );

    test('A1s (issue #1676): a skip-written record inherits too — the '
        'refactor side is verdict-agnostic, the evidence printed is the '
        'skip transition\'s own', () async {
      // The hand-step flow's terminal state: make `skipped` recorded the
      // post-state (issue #1676 write-side gate). The consumer matches
      // context + digests, never the verdict text — the inheritance must
      // engage and print the HONEST evidence (outcome=skipped), so the
      // printed trail names the skip transition's certification.
      await writeRecord(behaviorId: 'U2');
      final recordPath = p.join(fx.featureDir, 'tdd', 'make-post-state.json');
      final record =
          jsonDecode(await File(recordPath).readAsString())
              as Map<String, dynamic>;
      record['green_verdict'] =
          'make U2 outcome=skipped exit 0 '
          '(skip-transition target-test green evidence on the current '
          'tree; issue #1676)';
      await File(recordPath).writeAsString(jsonEncode(record));
      final ledgerPath = p.join(fx.featureDir, 'tdd', 'pass-batch.json');

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      // THE economics assertion: the pipeline is inherited — zero suite
      // spawns (no preflight, no re-proof).
      expect(await suiteSpawnCount(), 0, reason: out);
      // The inheritance names the skip transition's own evidence.
      expect(out, contains('make-post-state'));
      expect(out, contains('U2'));
      expect(out, contains('outcome=skipped'));
      // The record never overwrites the refactor-proved ledger
      // (FR-007): none existed, none was fabricated.
      expect(File(ledgerPath).existsSync(), isFalse);
    });

    test(
      'A1d (issue #1676 composition): a record the DRIVER wrote on a '
      'skipped make flows into the inheritance — zero suite spawns',
      () async {
        // The composition pin the three single-piece suites cannot give:
        // U5b (driver writes on `skipped`) + A1s (a skip-verdict record
        // inherits) are pinned separately, but A1s hand-edits the verdict
        // on a helper-written record — a future change to the driver's
        // digest/context keys could break the real chain while both suites
        // stay green. Here the DRIVER writes the record end to end (the
        // scripted fake zfa ends B-002 at the #694 skip transition, the
        // post-#1651 hand-step shape), and the real `zfa tdd refactor
        // --pass-batch` then inherits it: the inheritance line names the
        // driver-written skip verdict, and the suite wrapper is never
        // spawned.
        await fx.seedTestList([
          (
            id: 'B-001',
            description: 'first behavior',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
          (
            id: 'B-002',
            description: 'second behavior',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await fx.writeFakeZfa();
        await fx.setStepOutcome('verify-red', 'B-002', 'unexpected-green');
        await fx.setStepOutcome('make', 'B-002', 'skip');
        await fx.seedRedEvidence('B-002');

        final driverRunner = CliRunner(exitOnCompletion: false);
        final runOut = await driverRunner.runCapturing([
          'tdd',
          'run',
          fx.featureName,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        expect(exitCode, 0, reason: runOut);

        // The driver actually wrote the record, under B-002's skip
        // certification — no hand-editing anywhere in this chain.
        final recordPath = p.join(fx.featureDir, 'tdd', 'make-post-state.json');
        final record =
            jsonDecode(await File(recordPath).readAsString())
                as Map<String, dynamic>;
        expect(record['behavior_id'], 'B-002', reason: runOut);
        expect(
          record['green_verdict'] as String,
          contains('outcome=skipped'),
          reason: runOut,
        );
        expect(record['suite'], suiteScript, reason: runOut);
        // The run captured its once-per-run suite baseline (issue #741 —
        // the seeded green fixture gives the capture something parseable)
        // and the record keys on it, exactly like every driver-written
        // record in the real hand-step flow. That capture is the driver's
        // own cost — it already went through the logging wrapper, so the
        // economics assertion below counts only spawns AFTER the drive.
        expect(File(fx.runBaselinePath).existsSync(), isTrue, reason: runOut);
        expect(record['baseline_key'], isNotEmpty, reason: runOut);
        final spawnsAfterDrive = await suiteSpawnCount();
        final ledgerPath = p.join(fx.featureDir, 'tdd', 'pass-batch.json');

        // The driver hands its cached baseline to the spawned refactor
        // steps (issue #922) — this invocation plays that spawn, so it
        // carries the same flags the driver's spawn does.
        final out = await runRefactor(
          extraArgs: ['--pass-batch', '--suite-baseline', fx.runBaselinePath],
        );

        expect(exitCode, 0, reason: out);
        // THE economics assertion: the driver-written record inherits —
        // the refactor adds ZERO suite spawns (no preflight, no re-proof).
        expect(await suiteSpawnCount(), spawnsAfterDrive, reason: out);
        // The inheritance names the driver-written skip evidence.
        expect(out, contains('make-post-state'));
        expect(out, contains('B-002'));
        expect(out, contains('outcome=skipped'));
        // The record never overwrites the refactor-proved ledger
        // (FR-007): none existed, none was fabricated.
        expect(File(ledgerPath).existsSync(), isFalse);
      },
    );

    test('A2: tree drift after the make re-runs the full pipeline — the '
        'drifted tree is never inherited', () async {
      await writeRecord();
      // Drift the lib/ tree (still formatted, still green).
      await File(
        p.join(fx.root.path, 'lib', 'baseline.dart'),
      ).writeAsString('int answer() {\n  return 42;\n}\n// drift\n');

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      // The pipeline ran: the preflight spawn happened.
      expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test('U1a: a baseline rewrite after the make is a different gate — '
        'the full pipeline runs', () async {
      final baselinePath = p.join(fx.root.path, 'baseline.json');
      await File(
        baselinePath,
      ).writeAsString('{"captured_at": "2026-01-01T00:00:00Z"}');
      await writeRecord(baselinePath: baselinePath);
      await File(
        baselinePath,
      ).writeAsString('{"captured_at": "2026-01-02T00:00:00Z"}');

      final out = await runRefactor(
        extraArgs: ['--pass-batch', '--suite-baseline', baselinePath],
      );

      expect(exitCode, 0, reason: out);
      expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test('U1b: a suite-configuration rewrite after the make is a different '
        'gate — the full pipeline runs', () async {
      await writeRecord();
      await File(
        p.join(fx.root.path, 'dart_test.yaml'),
      ).writeAsString('concurrency: 1\n');

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test('U1c: an exempt-set difference between the record and the spawn '
        'is a different gate — the full pipeline runs', () async {
      await writeRecord(exempt: ['C1']);

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test('U2: a corrupt or mistyped record falls back to the full pipeline '
        '(safe failure)', () async {
      final recordPath = p.join(fx.featureDir, 'tdd', 'make-post-state.json');

      for (final payload in const ['{"lib_digest": 42}', '{ not json']) {
        // The previous iteration's green application wrote the #1588
        // ledger — delete it so the corrupt-RECORD fallback is what is
        // actually exercised (a valid ledger legally inherits first).
        final ledger = File(p.join(fx.featureDir, 'tdd', 'pass-batch.json'));
        if (ledger.existsSync()) await ledger.delete();
        await Directory(p.dirname(recordPath)).create(recursive: true);
        await File(recordPath).writeAsString(payload);
        final spawnsBefore = await suiteSpawnCount();

        final out = await runRefactor(extraArgs: ['--pass-batch']);

        expect(exitCode, 0, reason: out);
        // No inherited gate: the preflight ran.
        expect(await suiteSpawnCount(), greaterThan(spawnsBefore), reason: out);
        expect(out, isNot(contains('make-post-state')));
      }
    });

    test('U2b: a partially-mistyped exempt list is a corrupt record — the '
        'full pipeline runs (no silent whereType coercion)', () async {
      await writeRecord();
      // Corrupt one element of an otherwise-valid record: `[42]` must
      // read as mistyped, not coerce to `[]` — otherwise the record
      // inherits when the surviving list coincides with the effective
      // exempt set.
      final recordPath = p.join(fx.featureDir, 'tdd', 'make-post-state.json');
      final record =
          jsonDecode(await File(recordPath).readAsString())
              as Map<String, dynamic>;
      record['exempt_behaviors'] = <int>[42];
      await File(recordPath).writeAsString(jsonEncode(record));
      final spawnsBefore = await suiteSpawnCount();

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      expect(await suiteSpawnCount(), greaterThan(spawnsBefore), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test('U3: a flag-less standalone refactor never reads the record, and '
        '--full-reproof never inherits — the full pipeline runs', () async {
      await writeRecord();
      final spawnsAfterRecord = await suiteSpawnCount();

      final standalone = await runRefactor();
      expect(exitCode, 0, reason: standalone);
      expect(
        await suiteSpawnCount(),
        greaterThan(spawnsAfterRecord),
        reason: standalone,
      );
      expect(standalone, isNot(contains('make-post-state')));

      final fullReproof = await runRefactor(
        extraArgs: ['--pass-batch', '--full-reproof'],
      );
      expect(exitCode, 0, reason: fullReproof);
      expect(
        await suiteSpawnCount(),
        greaterThan(spawnsAfterRecord),
        reason: fullReproof,
      );
      expect(fullReproof, isNot(contains('make-post-state')));
    });

    test('U7 (verify remediation, kills M1): a test/ drift after the make '
        're-runs the full pipeline — both trees are load-bearing', () async {
      await writeRecord();
      // Drift the test/ tree only (still a valid, formatted test).
      await File(
        p.join(fx.root.path, 'test', 'later_test.dart'),
      ).writeAsString('void main() {}\n');

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
      expect(out, isNot(contains('make-post-state')));
    });

    test(
      'U8 (verify remediation, kills M7): a suite-template change between '
      'the make and the spawn is a different gate — the full pipeline runs',
      () async {
        // The record claims the make's evidence ran under a DIFFERENT
        // suite template than this invocation resolves: not the same
        // gate, never inherited.
        await writeRecord();
        final recordPath = p.join(fx.featureDir, 'tdd', 'make-post-state.json');
        final record =
            jsonDecode(await File(recordPath).readAsString())
                as Map<String, dynamic>;
        record['suite'] = 'dart test --preset=other';
        await File(recordPath).writeAsString(jsonEncode(record));

        final out = await runRefactor(extraArgs: ['--pass-batch']);

        expect(exitCode, 0, reason: out);
        expect(await suiteSpawnCount(), greaterThanOrEqualTo(1), reason: out);
        expect(out, isNot(contains('make-post-state')));
      },
    );

    test('U4: a matching pass-batch ledger keeps precedence — its full-'
        'pipeline proof is the inherited gate, not the make record', () async {
      final libNow = await TreeSnapshot.capture(
        fx.root.path,
        trees: const ['lib'],
      );
      final testNow = await TreeSnapshot.capture(
        fx.root.path,
        trees: const ['test'],
      );
      final ledger = {
        'captured_at': '2026-09-15T09:00:00.000Z',
        'suite': suiteScript,
        'baseline_key': '',
        'config_key': await PassBatchLedger.configKeyFor(fx.root.path),
        'exempt_behaviors': <String>[],
        'lib_digest': PassBatchLedger.treeDigest(libNow),
        'test_digest': PassBatchLedger.treeDigest(testNow),
        'preflight_verdict': 'preflight exit 0 (full pipeline)',
        'reproof_verdict': 're-proof inherited (registry changed nothing)',
      };
      final ledgerFile = File(p.join(fx.featureDir, 'tdd', 'pass-batch.json'));
      await ledgerFile.parent.create(recursive: true);
      await ledgerFile.writeAsString(jsonEncode(ledger));
      // The make record ALSO matches the tree — the ledger must win.
      await writeRecord();

      final out = await runRefactor(extraArgs: ['--pass-batch']);

      expect(exitCode, 0, reason: out);
      // Zero suite spawns either way — but the evidence names the
      // LEDGER's full-pipeline proof, not the make record.
      expect(await suiteSpawnCount(), 0, reason: out);
      expect(out, contains('pass-batch ledger hit'));
      expect(out, isNot(contains('make-post-state')));
    });
  });
}
