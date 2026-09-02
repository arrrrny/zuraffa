@Tags(['slow', 'integration'])
// SC-022 — `zfa replay` full-history e2e (spec 066-zfa-replay, issue #806).
//
// The issue's Done-when pair as one executable scenario:
//   1. Replaying a feature's FULL recorded history passes clean — every
//      behavior's recorded cycle (red evidence + green entry with recorded
//      generation steps and a recorded green command) replays in the
//      sandbox with identical artifacts and a green verify, exit 0.
//   2. An injected mutation into any replayed step is caught, with the
//      step named — history tamper (chain mismatch naming the green
//      entry), artifact drift (gen drift naming the path), and verify
//      divergence (expected/actual exits), each exit 1.
//
// The fixture history is seeded through the REAL `CycleLog.append` writer
// (schema-1 chain lines), standing in for the todo example's full recorded
// history — the machine format every pipeline-driven feature's history
// uses. The `example/` Flutter app predates that format (its specs/031 log
// is narrative) and is covered by the zero-parseable-entries case (A5,
// fast tier). Recorded gen steps target the scripted fake zfa binary and
// the recorded green commands target shell check scripts — no `dart test`
// is spawned (kernel-cache safe).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart';

import '../helpers/replay_fixture.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
  });

  Future<String> drive(ReplayFixture fx, {List<String> extra = const []}) {
    return runner.runCapturing([
      'tdd',
      'replay',
      fx.featureName,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaPath,
      ...extra,
    ]);
  }

  String lastLine(String out) =>
      out.trim().split('\n').where((l) => l.trim().isNotEmpty).last;

  test('SC-022: the full recorded history replays clean', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeFakeZfa();
    await fx.appendCycle(
      '066-scaffold-entity',
      marker: 'SC22-OK-1',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-entity'))],
    );
    await fx.appendCycle(
      '066-scaffold-usecase',
      marker: 'SC22-OK-2',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-usecase'))],
    );
    await fx.appendCycle(
      '066-scaffold-repository',
      marker: 'SC22-OK-3',
      genSteps: [
        genStep(fx.genCommandOf('066-scaffold-repository')),
        genStep('zfa build', purpose: 'build the generated sources'),
      ],
    );
    final before = await TreeSnapshot.capture(fx.root.path);

    final out = await drive(fx);

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('[replay] 066-scaffold-repository gen -> identical (0 paths)'),
    );
    expect(
      lastLine(out),
      'replay: feature=066-replay-fixture result=clean '
      'replayed=3 skipped=0 diverged=0',
    );
    final after = await TreeSnapshot.capture(fx.root.path);
    expect(
      before.changedPaths(after),
      isEmpty,
      reason: 'replay is read-only against the real project',
    );
  });

  test('SC-022: a history tamper is caught with the entry named', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeFakeZfa();
    await fx.appendCycle(
      '066-scaffold-entity',
      marker: 'SC22-OK-1',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-entity'))],
    );
    // Injected mutation: rewrite a certified fact in the green entry.
    final log = File(fx.cycleLogPath);
    await log.writeAsString(
      (await log.readAsString()).replaceFirst('- exit: 0\n', '- exit: 1\n'),
    );

    final out = await drive(fx);

    expect(exitCode, 1, reason: out);
    expect(
      out,
      contains(
        '[replay] 066-scaffold-entity integrity -> diverged '
        '(chain mismatch: green)',
      ),
    );
    // The tampered history's commands never execute.
    final fakeLog = await File(fx.fakeZfaLogPath).readAsString();
    expect(fakeLog, isNot(contains('066-scaffold-entity')));
  });

  test('SC-022: artifact drift is caught with the path named', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeFakeZfa();
    await fx.appendCycle(
      '066-scaffold-entity',
      marker: 'SC22-OK-1',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-entity'))],
    );
    // The generator drifted: regeneration now produces a different body.
    await fx.writeDriftConfig(
      '066-scaffold-entity',
      'lib/066_scaffold_entity_subject.dart',
      '// subject: regenerated with a newer template\n',
    );

    final out = await drive(fx);

    expect(exitCode, 1, reason: out);
    expect(
      out,
      contains(
        '[replay] 066-scaffold-entity gen -> drift '
        '(1 path: lib/066_scaffold_entity_subject.dart modified)',
      ),
    );
  });

  test('SC-022: a verify divergence is caught with the exits named', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeFakeZfa();
    await fx.appendCycle(
      '066-scaffold-entity',
      marker: 'SC22-OK-1',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-entity'))],
    );
    // Broke between Tuesday and Wednesday.
    await fx.writeSubject('066-scaffold-entity', 'BROKEN');

    final out = await drive(fx);

    expect(exitCode, 1, reason: out);
    expect(
      out,
      contains(
        '[replay] 066-scaffold-entity verify -> diverged '
        '(exit expected 0, actual 1)',
      ),
    );
  });

  test('SC-022: replay regains context for a stateless agent', () async {
    // The issue's agent story: a fresh instance replays the log and knows
    // exactly where the loop stands — behaviors with only red evidence are
    // reported as skipped (still in progress), not as failures.
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeFakeZfa();
    await fx.appendCycle(
      '066-scaffold-entity',
      marker: 'SC22-OK-1',
      genSteps: [genStep(fx.genCommandOf('066-scaffold-entity'))],
    );
    await fx.appendRedOnly('066-scaffold-di');
    final eventsPath = p.join(fx.root.path, 'agent-recovery.ndjson');

    final out = await drive(fx, extra: ['--events', eventsPath]);

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains(
        '[replay] 066-scaffold-di gen -> skipped '
        '(no generation block)',
      ),
    );
    expect(
      lastLine(out),
      'replay: feature=066-replay-fixture result=clean '
      'replayed=1 skipped=1 diverged=0',
    );
    // The NDJSON event log carries the machine recovery summary.
    final eventsText = await File(eventsPath).readAsString();
    expect(eventsText, contains('"event":"replay.start"'));
    expect(
      eventsText,
      contains(
        '"event":"replay.end","result":"clean","replayed":1,'
        '"skipped":1,"diverged":0,"exit":0',
      ),
    );
  });
}
