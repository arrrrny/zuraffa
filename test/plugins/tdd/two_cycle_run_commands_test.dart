@Tags(['slow'])
// Two-cycle driver tests (spec 1008-two-cycle-driver, issue #1008): the
// run-engine / run-skin / run (meta) / status commands over a fixture
// feature `004-login-ui` with CORE/SKIN/BOTH-tagged behaviors. The
// commands run in-process through CliRunner.runCapturing; the four step
// commands are the fixture's scripted fake zfa binary spawned as real
// sub-processes (same conventions as run_command_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  // The issue's exit-criteria feature name: 004-login-ui.
  const feature = '004-login-ui';

  Future<String> run(String subcommand, {String? zfaBin}) async {
    final args = ['tdd', subcommand, feature, '--project', fx.root.path];
    // `status` reads receipts only — no step spawning, no --zfa-bin.
    if (subcommand != 'status') {
      args.addAll(['--zfa-bin', zfaBin ?? fx.fakeZfaBin]);
    }
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args);
  }

  /// The lane-tagged test list: two CORE rows (U1, U2), two SKIN rows
  /// (W1, W2) and one BOTH row (A1) — the minimal split that exercises
  /// every lane combination of issue #1008.
  Future<void> seedLanes() async {
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the acceptance behavior exercised by both lanes [both] | FR-001 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
| U2 | the second core behavior [core] | FR-001 | PENDING |
| W1 | the first skin behavior [skin] | FR-002 | PENDING |
| W2 | the second skin behavior [skin] | FR-002 | PENDING |
''');
  }

  /// A legacy (untagged) test list: three plain unit behaviors.
  Future<void> seedLegacy() async {
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-001 | first behavior | FR-001 | PENDING |
| B-002 | second behavior | FR-001 | PENDING |
| B-003 | third behavior | FR-001 | PENDING |
''');
  }

  String engineReceiptPath() =>
      p.join(fx.featureDir, 'tdd', '04-engine-receipt.json');

  String skinReceiptPath() =>
      p.join(fx.featureDir, 'tdd', '04-skin-receipt.json');

  Future<Map<String, dynamic>> readReceipt(String path) async =>
      jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('run-engine (US1)', () {
    setUp(seedLanes);

    test('U1/US1.AC1: drives ONLY the CORE+BOTH behaviors, exit 0', () async {
      final out = await run('run-engine');

      expect(exitCode, 0, reason: out);
      // A1, U1 and U2 driven in list order (A1's outer-loop section
      // comes first in the file); W1/W2 never spawn.
      expect(fx.stepInvocations(), [
        'gen A1',
        'verify-red A1',
        'make A1',
        'refactor A1',
        'gen U1',
        'verify-red U1',
        'make U1',
        'refactor U1',
        'gen U2',
        'verify-red U2',
        'make U2',
        'refactor U2',
      ]);
      expect(
        fx.stepInvocations().where((l) => l.contains('W')),
        isEmpty,
        reason: 'skin rows must not be driven by the engine lane',
      );
    });

    test('U2/US1.AC2: writes the engine receipt with verdict green', () async {
      final out = await run('run-engine');

      expect(exitCode, 0, reason: out);
      final receipt = await readReceipt(engineReceiptPath());
      expect(receipt['schema'], 1);
      expect(receipt['feature'], feature);
      expect(receipt['lane'], 'engine');
      expect(receipt['verdict'], 'green');
      expect(receipt['result'], 'complete');
      expect((receipt['behaviors'] as List).toSet(), {'U1', 'U2', 'A1'});
      final counts = receipt['counts'] as Map<String, dynamic>;
      expect(counts['total'], 3);
      expect(counts['done'], 3);
      expect(counts['pending'], 0);
      // A machine summary line for the lane.
      expect(out, contains('result=complete'));
    });

    test('U3/US1.AC3: legacy feature — every behavior is engine', () async {
      await seedLegacy();

      final out = await run('run-engine');

      expect(exitCode, 0, reason: out);
      expect(fx.stepInvocations(), [
        'gen B-001',
        'verify-red B-001',
        'make B-001',
        'refactor B-001',
        'gen B-002',
        'verify-red B-002',
        'make B-002',
        'refactor B-002',
        'gen B-003',
        'verify-red B-003',
        'make B-003',
        'refactor B-003',
      ]);
      final receipt = await readReceipt(engineReceiptPath());
      expect(receipt['verdict'], 'green');
      expect((receipt['behaviors'] as List).toSet(), {
        'B-001',
        'B-002',
        'B-003',
      });
    });

    test(
      'U4/US1.AC4: an honest stop writes the receipt with verdict red',
      () async {
        await fx.setStepOutcome('make', 'U2', 'not-certified-red');

        final out = await run('run-engine');

        // Honest stop, driver exit code 1 (stopped).
        expect(exitCode, 1, reason: out);
        expect(out, contains('stopped_at=U2:make'), reason: out);
        final receipt = await readReceipt(engineReceiptPath());
        expect(receipt['verdict'], 'red');
        expect(receipt['result'], 'stopped');
        expect(receipt['stopped_at'], 'U2:make');
      },
    );

    test('missing <feature> argument is a usage error', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run-engine',
        '--project',
        fx.root.path,
      ]);
      expect(out, contains('missing <feature>'));
    });
  });

  group('run-skin gate (US2)', () {
    setUp(seedLanes);

    test(
      'U5/US2.AC1: no engine receipt — exit 2, zero steps, no skin receipt',
      () async {
        final out = await run('run-skin');

        expect(exitCode, 2, reason: out);
        expect(out, contains('04-engine-receipt.json'), reason: out);
        expect(out, contains('run-engine'), reason: out);
        expect(fx.stepInvocations(), isEmpty);
        expect(await File(skinReceiptPath()).exists(), isFalse);
        expect(await File(engineReceiptPath()).exists(), isFalse);
      },
    );

    test('U6/US2.AC2: non-green engine receipt — exit 2, zero steps', () async {
      // An honestly-red engine receipt (produced by a stopped engine run).
      await fx.setStepOutcome('make', 'U1', 'not-certified-red');
      await run('run-engine');
      exitCode = 0;
      fx.clearStepInvocations();

      final out = await run('run-skin');

      expect(exitCode, 2, reason: out);
      expect(out, contains('red'), reason: out);
      expect(fx.stepInvocations(), isEmpty);
      expect(await File(skinReceiptPath()).exists(), isFalse);
    });

    test(
      'U7/US2.AC3: green engine receipt — drives ONLY skin+BOTH, skips done BOTH',
      () async {
        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        fx.clearStepInvocations();
        exitCode = 0;

        final out = await run('run-skin');

        expect(exitCode, 0, reason: out);
        // W1, W2 driven in list order; A1 is already DONE (engine lane) and
        // is skipped, never re-driven from gen.
        expect(fx.stepInvocations(), [
          'gen W1',
          'verify-red W1',
          'make W1',
          'refactor W1',
          'gen W2',
          'verify-red W2',
          'make W2',
          'refactor W2',
        ]);
        expect(fx.stepInvocations().where((l) => l.contains('A1')), isEmpty);

        final receipt = await readReceipt(skinReceiptPath());
        expect(receipt['lane'], 'skin');
        expect(receipt['verdict'], 'green');
        expect((receipt['behaviors'] as List).toSet(), {'W1', 'W2', 'A1'});
        final counts = receipt['counts'] as Map<String, dynamic>;
        // A1 counts as done within the skin lane too (it is a BOTH behavior).
        expect(counts['done'], 3);
        expect(counts['total'], 3);
      },
    );

    test(
      'U8/US2.AC4: legacy feature — vacuous skin lane, green receipt',
      () async {
        await seedLegacy();
        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        fx.clearStepInvocations();
        exitCode = 0;

        final out = await run('run-skin');

        expect(exitCode, 0, reason: out);
        expect(fx.stepInvocations(), isEmpty);
        final receipt = await readReceipt(skinReceiptPath());
        expect(receipt['verdict'], 'green');
        expect(receipt['behaviors'], isEmpty);
        final counts = receipt['counts'] as Map<String, dynamic>;
        expect(counts['total'], 0);
      },
    );

    test('skin lane stops honestly — exit 1, red skin receipt', () async {
      final engineOut = await run('run-engine');
      expect(exitCode, 0, reason: engineOut);
      fx.clearStepInvocations();
      exitCode = 0;
      await fx.setStepOutcome('make', 'W1', 'not-certified-red');

      final out = await run('run-skin');

      expect(exitCode, 1, reason: out);
      expect(out, contains('stopped_at=W1:make'), reason: out);
      final receipt = await readReceipt(skinReceiptPath());
      expect(receipt['verdict'], 'red');
    });
  });

  group('run meta-driver (US3)', () {
    setUp(seedLanes);

    test(
      'U9/US3.AC1: engine steps strictly before skin steps, both receipts',
      () async {
        final out = await run('run');

        expect(exitCode, 0, reason: out);
        final invocations = fx.stepInvocations();
        // 3 engine behaviors + 2 skin behaviors (A1 done by engine) = 20.
        expect(invocations.length, 20, reason: invocations.join('\n'));
        final lastEngineIndex = invocations.lastIndexWhere(
          (l) => l.endsWith(' A1') || l.endsWith(' U1') || l.endsWith(' U2'),
        );
        final firstSkinIndex = invocations.indexWhere(
          (l) => l.endsWith(' W1') || l.endsWith(' W2'),
        );
        expect(lastEngineIndex, greaterThanOrEqualTo(0));
        expect(firstSkinIndex, greaterThan(lastEngineIndex));
        final engine = await readReceipt(engineReceiptPath());
        final skin = await readReceipt(skinReceiptPath());
        expect(engine['verdict'], 'green');
        expect(skin['verdict'], 'green');
      },
    );

    test('U9b/US3.AC1: both receipts green after the meta run', () async {
      final out = await run('run');

      expect(exitCode, 0, reason: out);
      final engine = await readReceipt(engineReceiptPath());
      final skin = await readReceipt(skinReceiptPath());
      expect(engine['verdict'], 'green');
      expect(skin['verdict'], 'green');
    });

    test('U10/US3.AC2: fails fast on the first red engine step', () async {
      await fx.setStepOutcome('make', 'U2', 'not-certified-red');

      final out = await run('run');

      expect(exitCode, 1, reason: out);
      expect(out, contains('stopped_at=U2:make'), reason: out);
      // No skin step ever spawned, no skin receipt written.
      expect(
        fx.stepInvocations().where((l) => l.contains('W')),
        isEmpty,
        reason: fx.stepInvocations().join('\n'),
      );
      expect(await File(skinReceiptPath()).exists(), isFalse);
      // The engine receipt records the honest red.
      final receipt = await readReceipt(engineReceiptPath());
      expect(receipt['verdict'], 'red');
    });

    test(
      "U11/US3.AC3: unified journal entry names both receipts + summary line",
      () async {
        final out = await run('run');

        expect(exitCode, 0, reason: out);
        // The machine summary line keeps the run driver's shape.
        expect(
          out,
          contains(
            'run: feature=$feature result=complete pending=0 red=0 green=0 '
            'done=5',
          ),
          reason: out,
        );
        // The unified journal entry in tdd/cycle-log.md.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('04-engine-receipt.json'));
        expect(cycleLog, contains('04-skin-receipt.json'));
      },
    );

    test(
      'U12/US3.AC4: legacy feature — byte-compatible with the pre-split run',
      () async {
        await seedLegacy();

        final out = await run('run');

        expect(exitCode, 0, reason: out);
        // Exactly the pre-split driver's step sequence.
        expect(fx.stepInvocations(), [
          'gen B-001',
          'verify-red B-001',
          'make B-001',
          'refactor B-001',
          'gen B-002',
          'verify-red B-002',
          'make B-002',
          'refactor B-002',
          'gen B-003',
          'verify-red B-003',
          'make B-003',
          'refactor B-003',
        ]);
        expect(
          out,
          contains(
            'run: feature=$feature result=complete pending=0 red=0 green=0 '
            'done=3',
          ),
          reason: out,
        );
        // Plus the two receipts and the unified entry.
        expect((await readReceipt(engineReceiptPath()))['verdict'], 'green');
        expect((await readReceipt(skinReceiptPath()))['verdict'], 'green');
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('04-engine-receipt.json'));
      },
    );
  });

  group('status (US4)', () {
    setUp(seedLanes);

    test('U13/US4.AC1: both lanes green — one line, exit 0', () async {
      final metaOut = await run('run');
      expect(exitCode, 0, reason: metaOut);
      exitCode = 0;

      final out = await run('status');

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains('status: feature=$feature engine=green skin=green'),
        reason: out,
      );
    });

    test(
      'U14/US4.AC2: missing receipts are named absent, non-zero exit',
      () async {
        final out = await run('status');

        expect(exitCode, isNot(0), reason: out);
        expect(
          out,
          contains('status: feature=$feature engine=absent skin=absent'),
          reason: out,
        );
      },
    );

    test(
      'U14b: engine green, skin missing — mixed verdict, non-zero exit',
      () async {
        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        exitCode = 0;

        final out = await run('status');

        expect(exitCode, isNot(0), reason: out);
        expect(
          out,
          contains('status: feature=$feature engine=green skin=absent'),
          reason: out,
        );
      },
    );

    test('U14c: a red engine receipt is named red, non-zero exit', () async {
      await fx.setStepOutcome('make', 'U1', 'not-certified-red');
      await run('run-engine');
      exitCode = 0;

      final out = await run('status');

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains('status: feature=$feature engine=red skin=absent'),
        reason: out,
      );
    });

    test('US4.AC3: no feature directory — misfire stop', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'status',
        '999-no-such-feature',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('999-no-such-feature'), reason: out);
    });
  });

  group('lane plan files (plan)', () {
    test(
      'U15: 04-ENGINE.md/04-SKIN.md plan files win over tags (ids in both = BOTH)',
      () async {
        // Seed the lane-tagged list, then overlay the post-#1000 plan pair:
        // engine plan carries U1, U2, A1; skin plan carries W1, A1.
        await seedLanes();
        await File(p.join(fx.featureDir, 'tdd', '04-ENGINE.md')).writeAsString(
          '''
# Engine plan (CORE + BOTH)

| id | behavior |
| -- | -------- |
| U1 | core one |
| U2 | core two |
| A1 | shared acceptance |
''',
        );
        await File(p.join(fx.featureDir, 'tdd', '04-SKIN.md')).writeAsString('''
# Skin plan (SKIN + BOTH)

| id | behavior |
| -- | -------- |
| W1 | skin one |
| A1 | shared acceptance |
''');

        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        expect(fx.stepInvocations().map((l) => l.split(' ')[1]).toSet(), {
          'U1',
          'U2',
          'A1',
        }, reason: fx.stepInvocations().join('\n'));
        // The plan pair reassigns W2 (tagged skin) to... nothing: it is in
        // NEITHER plan file, so it defaults to the engine lane (CORE).
        // Wait — the plan files are the lane source of truth; W2 tagged
        // [skin] but absent from both plans. The ids come from the files:
        // engine = {U1, U2, A1}, skin = {W1, A1}. W2 is driven by neither.
        expect(
          fx.stepInvocations().map((l) => l.split(' ')[1]).contains('W2'),
          isFalse,
        );

        fx.clearStepInvocations();
        exitCode = 0;
        final skinOut = await run('run-skin');
        expect(exitCode, 0, reason: skinOut);
        expect(fx.stepInvocations().map((l) => l.split(' ')[1]).toSet(), {
          'W1',
        }, reason: fx.stepInvocations().join('\n'));
        final receipt = await readReceipt(skinReceiptPath());
        expect((receipt['behaviors'] as List).toSet(), {'W1', 'A1'});
      },
    );
  });
}
