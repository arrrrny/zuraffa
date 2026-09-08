@Tags(['slow', 'integration'])
// SC-024 — acceptance entity-reuse fallback e2e (issue #1330): the
// REAL-pipeline proof that a one-shot `zfa make <Row>` resolving to nothing
// on an already-generated contract-row entity no longer dead-ends the make
// or wedges the run.
//
// Before the fix the #826 pre-flight aborted the whole make with
// `verdict: no-op` the moment the #829 entity gate left the bare
// `make <Entity>` as the plan's first step — the subject-edit step that
// turned the earlier siblings green was never reached, and phase 2
// re-planned the identical steps into the identical no-op
// (`result=stopped stopped_at=<id>:make`).
//
//   (a) make-level: real gen + verify-red, a hand-tuned entity pre-seeded,
//       then the REAL `zfa tdd make` with NO `--zfa-bin` flag reaching the
//       make child (the pre-flight is active inside it) — the make falls
//       back to the `tdd wire` subject edit and certifies GREEN while the
//       hand-tuned entity file survives byte-identical.
//   (b) run-level: TWO acceptance behaviors referencing the SAME contract
//       row (the issue repro shape) complete the run — A1 scaffolds the
//       entity through the normal path, A2 reuses it through the fallback;
//       `result=complete`, no make deferral, no no-op, no stopped_at.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// Absolute path to the zuraffa repo root (the real zfa CLI source).
String _findZuraffaRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}

Future<ProcessResult> _runRealZfa(
  String repoRoot,
  List<String> args, {
  required String workingDirectory,
}) {
  return Process.run(Platform.resolvedExecutable, [
    p.join(repoRoot, 'bin', 'zfa.dart'),
    ...args,
  ], workingDirectory: workingDirectory);
}

File _dispatchEntityFile(TddFixture fx) => File(
  p.join(
    fx.root.path,
    'lib',
    'src',
    'domain',
    'entities',
    'dispatch_service',
    'dispatch_service.dart',
  ),
);

void main() {
  late TddFixture fx;
  late String repoRoot;
  late String forwarderPath;

  setUp(() async {
    fx = await TddFixture.create();
    repoRoot = _findZuraffaRoot();

    // Enrich the fixture into a real buildable project (same provisioning
    // as SC-017/SC-021: the real pipeline needs zorphy + json codegen).
    await File(p.join(fx.root.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy: any
  zorphy_annotation: any
  json_annotation: any
dev_dependencies:
  build_runner: any
  json_serializable: any
  test: ^1.25.0
''');
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
    ], workingDirectory: fx.root.path);
    expect(
      pubGet.exitCode,
      0,
      reason: 'pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
    );

    // Pure exec forwarder to the REAL zfa CLI (transport only — it adds
    // no generation semantics; SC-017's pattern).
    final binDir = Directory(p.join(fx.root.path, 'fake_bin'));
    await binDir.create(recursive: true);
    forwarderPath = p.join(binDir.path, 'zfa');
    await File(forwarderPath).writeAsString(
      '#!/usr/bin/env bash\nexec '
      '"${Platform.resolvedExecutable}" '
      '"${p.join(repoRoot, 'bin', 'zfa.dart')}" '
      '"\$@"\n',
    );
    await Process.run('chmod', ['+x', forwarderPath]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('SC-024a: the gated one-shot make falls back to the subject edit and '
      'certifies green — the hand-tuned entity is byte-identical', () async {
    const feature = '001-dispatch-reuse';
    const description = 'the DispatchService repository records a delivery';
    final featureDir = Directory(p.join(fx.root.path, 'specs', feature));
    await featureDir.create(recursive: true);
    await Directory(p.join(featureDir.path, 'tdd')).create(recursive: true);
    await File(p.join(featureDir.path, 'tdd', 'test-list.md')).writeAsString('''
# Test List: $feature

## Outer loop: acceptance scenarios

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | $description | FR-001 | PENDING |
''');

    // 1. Materialize the REAL gen pair + certified red.
    final gen = await _runRealZfa(repoRoot, [
      'tdd',
      'gen',
      'A1',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(gen.exitCode, 0, reason: 'gen failed:\n${gen.stdout}${gen.stderr}');
    final verifyRed = await _runRealZfa(repoRoot, [
      'tdd',
      'verify-red',
      'A1',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(
      verifyRed.exitCode,
      0,
      reason: 'verify-red failed:\n${verifyRed.stdout}${verifyRed.stderr}',
    );

    // 2. The contract-row entity ALREADY exists (the sibling make's
    //    one-shot scaffold from the issue repro) and is HAND-TUNED.
    final entityCreate = await _runRealZfa(repoRoot, [
      'entity',
      'create',
      '-n',
      'DispatchService',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(
      entityCreate.exitCode,
      0,
      reason:
          'entity create failed:\n${entityCreate.stdout}${entityCreate.stderr}',
    );
    final entityFile = _dispatchEntityFile(fx);
    expect(entityFile.existsSync(), isTrue);
    final handTuned =
        '${entityFile.readAsStringSync()}\n// hand-tuned field marker\n';
    await entityFile.writeAsString(handTuned);

    // 3. The REAL make — deliberately NO --zfa-bin: the #826 pre-flight
    //    is active inside the make child (the driver-spawned shape).
    //    Pre-fix this aborted with `verdict: no-op`; post-fix it falls
    //    back to the wire subject edit and certifies green.
    final make = await _runRealZfa(repoRoot, [
      'tdd',
      'make',
      'A1',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    final makeOut = '${make.stdout}${make.stderr}';
    expect(
      make.exitCode,
      0,
      reason: 'the fallback make must certify green; out:\n$makeOut',
    );
    expect(
      makeOut,
      contains('make: behavior=A1 outcome=green'),
      reason: 'out:\n$makeOut',
    );
    expect(
      makeOut,
      contains('issue #1330'),
      reason: 'the fallback must be printed, never silent; out:\n$makeOut',
    );
    expect(
      makeOut,
      isNot(contains('verdict: no-op')),
      reason: 'out:\n$makeOut',
    );

    // 4. The hand-tuned entity survived byte-identical (FR-003).
    expect(
      entityFile.readAsStringSync(),
      handTuned,
      reason: 'the entity must be reused as-is — never regenerated',
    );

    // 5. The subject was implemented by the WIRE step (the same path
    //    that turned the earlier siblings green).
    final subjectFile = File(
      p.join(fx.root.path, 'lib', 'tdd', feature, 'a1_subject.dart'),
    );
    expect(subjectFile.existsSync(), isTrue);
    final subject = subjectFile.readAsStringSync();
    expect(subject, isNot(contains('UnimplementedError')));
    expect(subject, contains('DispatchService'));

    // 6. The green evidence records the wire step (the audit trail is
    //    honest — the subject edit ran as a pipeline step).
    final log = await File(
      p.join(featureDir.path, 'tdd', 'cycle-log.md'),
    ).readAsString();
    expect(log, contains('## Cycle: A1 (green)'));
    expect(log, contains('tdd wire'));
  }, timeout: const Timeout(Duration(minutes: 25)));

  test('SC-024b: two acceptance behaviors referencing the same contract row '
      'complete the run — no make deferral, no no-op, no stopped_at', () async {
    const feature = '002-dispatch-wedge';
    // The issue repro shape: multiple acceptance behaviors on ONE
    // contract row. A1 scaffolds the entity (normal path, entity
    // absent); A2 hits the gated one-shot make (entity present) and
    // must fall back to its subject edit instead of wedging the run.
    const a1 = 'the DispatchService repository records a delivery';
    const a2 = 'the DispatchService repository audits a delivery';
    final featureDir = Directory(p.join(fx.root.path, 'specs', feature));
    await featureDir.create(recursive: true);
    await Directory(p.join(featureDir.path, 'tdd')).create(recursive: true);
    await File(p.join(featureDir.path, 'tdd', 'test-list.md')).writeAsString('''
# Test List: $feature

## Outer loop: acceptance scenarios

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | $a1 | FR-001 | PENDING |
| A2 | $a2 | FR-001 | PENDING |
''');

    // The full loop over the list — REAL pipeline, the make children
    // spawned by the driver carry NO --zfa-bin (the pre-flight is
    // active inside them, exactly the issue's driver-spawned shape).
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      forwarderPath,
    ]);

    // A1 greens through the normal scaffold path (entity absent).
    expect(out, contains('[run] A1 gen -> ok'), reason: out);
    expect(out, contains('[run] A1 make -> green'), reason: out);
    // A2 greens through the fallback (entity present, one-shot make
    // resolved to nothing, the subject edit proceeded).
    expect(out, contains('[run] A2 gen -> ok'), reason: out);
    expect(out, contains('[run] A2 make -> green'), reason: out);
    // THE WEDGE IS GONE: no make deferral, no no-op verdict anywhere,
    // no honest stop.
    expect(out, isNot(contains('make -> deferred')), reason: out);
    expect(out, isNot(contains('no-op')), reason: out);
    expect(out, isNot(contains('stopped_at')), reason: out);
    // Both behaviors DONE, run complete, exit 0.
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 '
        'done=2',
      ),
      reason: out,
    );
    expect(exitCode, 0, reason: 'run must exit 0 when complete; out:\n$out');

    // Both subjects were wired (the subject-edit path ran for both).
    for (final id in const ['a1', 'a2']) {
      final subjectFile = File(
        p.join(fx.root.path, 'lib', 'tdd', feature, '${id}_subject.dart'),
      );
      expect(subjectFile.existsSync(), isTrue, reason: out);
      expect(
        subjectFile.readAsStringSync(),
        isNot(contains('UnimplementedError')),
        reason: out,
      );
    }
    // The entity was created exactly once — by A1's normal scaffold —
    // and A2's fallback never touched it (no regeneration over the
    // generated shape).
    expect(_dispatchEntityFile(fx).existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
