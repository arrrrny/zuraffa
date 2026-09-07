@Tags(['slow'])
// Bug #1271 (tdd-run-widget-lane-stalls-engine): widget-kind behaviors in
// the ENGINE lane bucket stall the engine lane instead of being deferred to
// the skin lane. Per spec 1008 (two-cycle runner), widget-lane behaviors
// are skin-lane work: the engine lane must mark them pending, skip the
// engine steps, and queue them for run-skin behind a green engine receipt.
//
// The commands run in-process through CliRunner.runCapturing; the four step
// commands are the fixture's scripted fake zfa binary spawned as real
// sub-processes (same conventions as two_cycle_run_commands_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '004-login-ui';

  Future<String> run(String subcommand) async {
    final args = [
      'tdd',
      subcommand,
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ];
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args);
  }

  /// The lane-tagged test list of the issue's shape: CORE rows U1/U2 plus
  /// a `## Outer loop: widget behaviors` section carrying A1 — a
  /// WIDGET-kind row tagged [both] (the issue's first widget-lane
  /// behavior sitting in the engine bucket) — and the skin widget rows
  /// W1/W2 tagged [skin].
  Future<void> seedLanes() async {
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
| U2 | the second core behavior [core] | FR-001 | PENDING |

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the widget seam behavior asserted on both lanes [both] | FR-001 | PENDING |
| W1 | the first skin widget behavior [skin] | FR-002 | PENDING |
| W2 | the second skin widget behavior [skin] | FR-002 | PENDING |
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

  group('bug 1271: engine lane defers widget-kind behaviors (run-engine)', () {
    setUp(seedLanes);

    test(
      'the engine lane does not drive the widget-kind BOTH row — no stall',
      () async {
        // The issue's stall script: verify-red on the widget subject sees
        // it already green (unexpected-green, exit 1) → the driver's skip
        // transition advances past verify-red → make refuses
        // not-certified-red (exit 1) → the engine lane stops honestly at
        // A1:make and every subsequent behavior is blocked.
        await fx.setStepOutcome('verify-red', 'A1', 'unexpected-green');
        await fx.setStepOutcome('make', 'A1', 'not-certified-red');

        final out = await run('run-engine');

        // FIXED: the engine defers A1 (pending, no engine steps) and
        // completes green over its non-widget bucket. BUGGY: exit 1 with
        // stopped_at=A1:make.
        expect(exitCode, 0, reason: out);
        expect(out, isNot(contains('stopped_at=A1:make')), reason: out);

        final invocations = fx.stepInvocations();
        expect(
          invocations.where((l) => l.endsWith(' A1')),
          isEmpty,
          reason:
              'engine lane must defer widget-kind behaviors to the skin '
              'lane (no engine step may spawn for them); got: '
              '${invocations.join('\n')}',
        );
        // The CORE behaviors are still driven, exactly as before.
        expect(invocations, [
          'gen U1',
          'verify-red U1',
          'make U1',
          'refactor U1',
          'gen U2',
          'verify-red U2',
          'make U2',
          'refactor U2',
        ]);

        final receipt = await readReceipt(engineReceiptPath());
        expect(receipt['verdict'], 'green');
        expect(receipt['result'], 'complete');
        expect((receipt['behaviors'] as List).toSet(), {'U1', 'U2'});
      },
    );
  });

  group('bug 1271: the meta run queues deferred widget rows for run-skin', () {
    setUp(seedLanes);

    test(
      'widget-kind rows are driven by the SKIN lane, after the engine lane',
      () async {
        // No scripted failures: every step succeeds, so the ONLY
        // difference is the routing. BUGGY: A1 (widget-kind BOTH, first in
        // list order) is driven through the ENGINE lane — its steps come
        // BEFORE U1/U2's. FIXED: A1 is deferred to the skin lane — its
        // steps come AFTER the last engine step.
        final out = await run('run');

        expect(exitCode, 0, reason: out);
        final invocations = fx.stepInvocations();
        final lastEngineIndex = invocations.lastIndexWhere(
          (l) => l.endsWith(' U1') || l.endsWith(' U2'),
        );
        final firstA1Index = invocations.indexWhere(
          (l) => l.startsWith('gen A1'),
        );
        expect(lastEngineIndex, greaterThanOrEqualTo(0));
        expect(
          firstA1Index,
          greaterThan(lastEngineIndex),
          reason:
              'the deferred widget behavior must be driven by the skin '
              'lane, after the engine lane; got: ${invocations.join('\n')}',
        );

        // The engine receipt names exactly the engine-driven behaviors;
        // the skin receipt owns the deferred widget row.
        final engine = await readReceipt(engineReceiptPath());
        final skin = await readReceipt(skinReceiptPath());
        expect(engine['verdict'], 'green');
        expect(skin['verdict'], 'green');
        expect((engine['behaviors'] as List).toSet(), {'U1', 'U2'});
        expect((skin['behaviors'] as List).toSet(), {'A1', 'W1', 'W2'});

        // The skin receipt is written AFTER a green engine receipt (the
        // run-skin gate order is preserved — the meta run chains lanes).
        expect(File(engineReceiptPath()).existsSync(), isTrue);
        expect(File(skinReceiptPath()).existsSync(), isTrue);
      },
    );
  });

  group('bug 1271: standalone run-skin picks the deferred widget row up', () {
    test(
      'untagged widget-kind row (CORE default bucket) is deferred to run-skin',
      () async {
        await seedLanes();
        // W2 becomes an UNTAGGED widget row: the legacy CORE default puts
        // it in the engine bucket — exactly the bucket the fix must
        // detect widget-kind rows in, whatever route they took there.
        await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| W2 | the untagged widget behavior | FR-002 | PENDING |
| W1 | the first skin widget behavior [skin] | FR-002 | PENDING |
''');

        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        // The engine defers the untagged widget row and completes green.
        expect(
          fx.stepInvocations().where((l) => l.endsWith(' W2')),
          isEmpty,
          reason: fx.stepInvocations().join('\n'),
        );
        final engine = await readReceipt(engineReceiptPath());
        expect(engine['verdict'], 'green');
        expect((engine['behaviors'] as List).toSet(), {'U1'});

        fx.clearStepInvocations();
        exitCode = 0;

        final skinOut = await run('run-skin');
        expect(exitCode, 0, reason: skinOut);
        // run-skin picks the deferred row up behind the green receipt.
        expect(fx.stepInvocations(), [
          'gen W2',
          'verify-red W2',
          'make W2',
          'refactor W2',
          'gen W1',
          'verify-red W1',
          'make W1',
          'refactor W1',
        ], reason: skinOut);
        final skin = await readReceipt(skinReceiptPath());
        expect(skin['verdict'], 'green');
        expect((skin['behaviors'] as List).toSet(), {'W1', 'W2'});
      },
    );
  });
}
