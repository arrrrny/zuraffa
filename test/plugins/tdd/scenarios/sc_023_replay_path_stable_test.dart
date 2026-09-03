@Tags(['slow', 'integration'])
// SC-023 — path-stable full-history replay (spec 0806-zfa-replay, issue
// #806's literal Done-when pair, over a recorded-elsewhere history).
//
// The fixture mirrors `examples/todo_tdd`'s recorded shape — the todo
// example's cycle-log as it was written on the recording agent's machine:
//   - `- test:` fields anchored at `<recordedRoot>/./…` (a root that does
//     not exist locally);
//   - generation steps carrying the machine-absolute entrypoint pair
//     `<recorded dart> <recorded zfa.dart>`;
//   - a `tdd/artifacts.json` registry whose paths carry the same anchor.
//
//   1. The FULL recorded history replays clean on this machine (exit 0,
//      result=clean) — integrity re-anchored, commands stripped to
//      sandbox-relative, the entrypoint pair re-resolved through
//      `--zfa-bin`, the sandbox registry re-anchored (the fake zfa asserts
//      it), and no recorded root survives into any spawn.
//   2. An injected mutation into a replayed step is caught with the step
//      named (gen drift naming the project-relative path, exit 1).
//
// No `dart test` is ever spawned — the fake zfa + shell check scripts keep
// the scenario kernel-cache safe.
library;

import 'dart:io';

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

  /// Drive the dream surface with the cycle-log PATH (the `zfa replay
  /// tdd/cycle-log.md` form) against a recorded-elsewhere fixture.
  Future<String> drive(ReplayFixture fx, {List<String> extra = const []}) {
    return runner.runCapturing([
      'replay',
      fx.cycleLogPath,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaPath,
      ...extra,
    ]);
  }

  String lastLine(String out) =>
      out.trim().split('\n').where((l) => l.trim().isNotEmpty).last;

  test('SC-023: a recorded-elsewhere full history replays clean', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeAnchoredFakeZfa();
    await fx.writeAnchoredRegistry([
      '0806-scaffold-entity',
      '0806-scaffold-usecase',
    ]);
    await fx.appendAnchoredCycle(
      '0806-scaffold-entity',
      marker: 'SC23-OK-1',
      genSteps: [genStep(fx.recordedEntrypointOf('0806-scaffold-entity'))],
    );
    await fx.appendAnchoredCycle(
      '0806-scaffold-usecase',
      marker: 'SC23-OK-2',
      genSteps: [
        genStep(fx.recordedEntrypointOf('0806-scaffold-usecase')),
        genStep(
          '/gone/sdk/bin/dart /gone/zuraffa/bin/zfa.dart build',
          purpose: 'build the generated sources',
        ),
      ],
    );
    final before = await TreeSnapshot.capture(fx.root.path);

    final out = await drive(fx);

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('[replay] 0806-scaffold-entity integrity -> verified'),
      reason: 'the re-anchored red path resolved against the local tree',
    );
    expect(
      out,
      contains('[replay] 0806-scaffold-entity gen -> identical (0 paths)'),
    );
    expect(
      lastLine(out),
      'replay: feature=066-replay-fixture result=clean '
      'replayed=2 skipped=0 diverged=0',
    );
    // The executed commands ran re-anchored: the entrypoint pair resolved
    // through --zfa-bin (recorded args, no recorded root), and the green
    // command's anchored subject path stripped to sandbox-relative form.
    final log = await File(fx.fakeZfaLogPath).readAsString();
    expect(log, contains('tdd gen 0806-scaffold-entity'));
    expect(log, isNot(contains('/gone/')));
    expect(log, isNot(contains(fx.recordedRoot)));
    // Read-only contract over the real project.
    final after = await TreeSnapshot.capture(fx.root.path);
    expect(before.changedPaths(after), isEmpty);
  });

  test('SC-023: an injected mutation into a re-anchored step is caught, '
      'path named', () async {
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeAnchoredFakeZfa();
    await fx.writeAnchoredRegistry(['0806-scaffold-entity']);
    await fx.appendAnchoredCycle(
      '0806-scaffold-entity',
      marker: 'SC23-OK-1',
      genSteps: [genStep(fx.recordedEntrypointOf('0806-scaffold-entity'))],
    );
    // Injected mutation: the generator drifted — regeneration now writes
    // a different body than the recorded tree carries.
    await fx.writeDriftConfig(
      '0806-scaffold-entity',
      'lib/0806_scaffold_entity_subject.dart',
      '// subject: regenerated with a newer template\n',
    );

    final out = await drive(fx);

    expect(exitCode, 1, reason: out);
    expect(
      out,
      contains(
        '[replay] 0806-scaffold-entity gen -> drift '
        '(1 path: lib/0806_scaffold_entity_subject.dart modified)',
      ),
      reason: 'the drift path is project-relative — path-stable',
    );
    expect(
      lastLine(out),
      'replay: feature=066-replay-fixture result=divergent '
      'replayed=0 skipped=0 diverged=1',
    );
  });

  test('SC-023: a leaked registry anchor is a named runner-error '
      '(the fake zfa refuses)', () async {
    // The negative control for the sandbox re-anchor: if the registry
    // were copied verbatim (recorded root still inside), the gen step's
    // zfa exits 7 and replay reports the step as a runner-error — never
    // a silent pass.
    final fx = await ReplayFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));
    await fx.writeAnchoredFakeZfa();
    await fx.writeAnchoredRegistry(['0806-scaffold-entity']);
    // Sabotage re-anchoring: no anchored history means no detected root.
    await fx.appendCycle(
      '0806-scaffold-entity',
      marker: 'SC23-OK-1',
      genSteps: [genStep(fx.genCommandOf('0806-scaffold-entity'))],
    );

    final out = await drive(fx);

    expect(exitCode, 1, reason: out);
    expect(
      out,
      contains(
        '[replay] 0806-scaffold-entity gen -> diverged (runner-error: '
        'recorded gen step failed (exit 7)',
      ),
    );
  });
}
