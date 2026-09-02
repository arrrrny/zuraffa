@Tags(['slow', 'integration'])
// Anchor test for bug #610 (tdd-make-never-wires-subject) — and the FIRST
// slow-tier test that drives the REAL generation pipeline end to end with
// NO fake zfa for the generation steps (spec 045 precondition 5 / FR-003:
// the harness is driven exclusively by real zfa commands).
//
// Bug #610: the entity plan was `entity create` + `build` only — no step
// ever implemented the gen'd subject stub (`lib/tdd/<id>_subject.dart`,
// an UnimplementedError stub), so `zfa tdd make` could NEVER certify
// green for an entity-bearing behavior: the pipeline succeeded, the
// target test stayed red, and make honestly stopped with
// `generation-error`. Fake-zfa mocks hid this because THEY wired the
// subject themselves via sideEffectByArgv.
//
// This test drives the full REAL loop — `zfa tdd gen` (real), `zfa tdd
// verify-red` (real), `zfa tdd make` (real pipeline: real entity create,
// real build, and after the fix the real subject-wiring step) — inside a
// temp fixture with real dependencies (zorphy + json codegen via
// build_runner). The `--zfa-bin` override points at a pure exec
// forwarder to the REAL `bin/zfa.dart` (transport only; it adds no
// generation semantics — without the fix green stays unreachable, with
// it the run certifies green).
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

void main() {
  late TddFixture fx;
  late String repoRoot;
  late String forwarderPath;

  setUp(() async {
    fx = await TddFixture.create();
    repoRoot = _findZuraffaRoot();

    // Enrich the fixture into a real buildable project: zorphy + json
    // codegen dependencies (the provisioning gap the assessment notes is
    // a separate issue; here we provision explicitly so the REAL
    // pipeline can run end to end).
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
    await Process.run('dart', ['pub', 'get'], workingDirectory: fx.root.path);

    // The behavior under test: an entity-bearing unit behavior, as a
    // real `zfa tdd plan`-style test-list row (6-cell format).
    final featureDir = Directory(p.join(fx.root.path, 'specs', fx.featureName));
    await File(p.join(featureDir.path, 'tdd', 'test-list.md')).writeAsString('''
---
feature: ${fx.featureName}
---

# Test List

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| B-001 | create entity User with email | FR-001 | unit | PENDING | |
''');

    // Materialize the REAL gen pair + certified red:
    //   gen (test + UnimplementedError subject stub + registry record)
    //   verify-red (certifies the honest red)
    final gen = await _runRealZfa(repoRoot, [
      'tdd',
      'gen',
      'B-001',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(gen.exitCode, 0, reason: 'gen failed:\n${gen.stdout}${gen.stderr}');
    final verifyRed = await _runRealZfa(repoRoot, [
      'tdd',
      'verify-red',
      'B-001',
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(
      verifyRed.exitCode,
      0,
      reason: 'verify-red failed:\n${verifyRed.stdout}${verifyRed.stderr}',
    );

    // Pure exec forwarder to the REAL zfa CLI (transport only — it must
    // add NO generation semantics, or this test would not prove the
    // pipeline itself wires the subject).
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

  test('SC-017: the REAL pipeline certifies green for an entity behavior — '
      'the subject is wired by a pipeline step, not a wrapper', () async {
    // Real gen + verify-red + make: entity create, build_runner codegen
    // and multiple dart test invocations — minutes, not milliseconds.
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--zfa-bin',
      forwarderPath,
      'B-001',
    ]);

    // The bug's failure signature (pre-#610) was:
    //   `target test still fails after generation` + outcome=generation-error
    // Post-fix the REAL pipeline must certify green.
    expect(
      out,
      contains('make: behavior=B-001 outcome=green feature=${fx.featureName}'),
      reason: 'real-pipeline run output:\n$out',
    );
    expect(exitCode, 0, reason: 'green certified must exit 0; out:\n$out');

    // The gen'd subject is no longer an UnimplementedError stub: it is
    // wired to the generated entity by the pipeline.
    final subjectFile = File(
      p.join(fx.root.path, 'lib', 'tdd', fx.featureName, 'b_001_subject.dart'),
    );
    expect(subjectFile.existsSync(), isTrue);
    final subject = subjectFile.readAsStringSync();
    expect(
      subject,
      isNot(contains('UnimplementedError')),
      reason: 'the pipeline must replace the stub with an implementation',
    );
    expect(
      subject,
      contains('user.dart'),
      reason: 'the wired subject must reference the generated entity',
    );

    // The green evidence records the full real pipeline including the
    // subject-wiring step.
    final log = await File(fx.cycleLogPath).readAsString();
    expect(log, contains('## Cycle: B-001 (green)'));
    expect(log, contains('zfa entity create'));
    expect(
      log,
      contains('tdd wire'),
      reason: 'the subject-wiring step must appear in the green evidence',
    );
    expect(log, contains('zfa build'));

    // The generated entity is real (zorphy codegen ran via the real
    // build step).
    expect(
      File(
        p.join(
          fx.root.path,
          'lib',
          'src',
          'domain',
          'entities',
          'user',
          'user.zorphy.dart',
        ),
      ).existsSync(),
      isTrue,
      reason: 'the real build step must have generated the entity parts',
    );
  }, timeout: Timeout(Duration(minutes: 10)));
}
