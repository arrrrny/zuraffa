@Tags(['slow', 'integration'])
// SC-018 — bug #617 (tdd-plan-gen-test-list-format-mismatch): the slow-tier
// loop e2e that is exactly the run-c demo from the assessment —
//
//   plan → run  on a real temp project with the REAL pipeline.
//
// Bug #617: `zfa tdd plan` writes 4-column test-list rows, but gen's private
// 6-column parser silently skipped them, so `zfa tdd run` stopped at its
// first step (`A1:gen`, unknown behavior id) and the full loop was dead on
// arrival. After the unification (gen consumes the shared TestListReader;
// plan's 4-column shape is the single contract), the driver must walk a
// plan-written list all the way to DONE through the real gen → verify-red →
// make → refactor steps (no fake zfa semantics — the --zfa-bin override is
// a pure exec forwarder to the real bin/zfa.dart, as in SC-017).
//
// This test is the loop's front door for format drift: any parser that
// stops understanding plan's canonical shape fails here, in CI.
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
  const feature = '001-demo';

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    repoRoot = _findZuraffaRoot();

    // Enrich the fixture into a real buildable project (same provisioning
    // as SC-017: the real pipeline needs zorphy + json codegen).
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

    // The spec the run-c demo starts from: one Given/When/Then scenario
    // and one FR-NNN requirement, both expressible by the real pipeline
    // (entity-bearing behaviors — the only surface make can implement).
    await File(p.join(fx.root.path, 'specs', feature, 'spec.md')).writeAsString(
      '''
# Spec: $feature

## Functional Requirements

- **FR-001**: create entity Account with status

## Acceptance Scenarios

1. **Given** a signup request **When** a user registers **Then** create entity User with email
''',
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

  test('SC-018: plan → run drives a plan-written list to all-DONE with the '
      'real pipeline (bug #617 loop e2e)', () async {
    // ---------------------------------------------------------------
    // 1. plan — writes the canonical 4-column test list.
    // ---------------------------------------------------------------
    final plan = await _runRealZfa(repoRoot, [
      'tdd',
      'plan',
      feature,
      '--project',
      fx.root.path,
    ], workingDirectory: fx.root.path);
    expect(
      plan.exitCode,
      0,
      reason: 'plan failed:\n${plan.stdout}${plan.stderr}',
    );

    final testList = File(
      p.join(fx.featureDir, 'tdd', 'test-list.md'),
    ).readAsStringSync();
    expect(testList, contains('| id | behavior | traces | state |'));
    expect(testList, isNot(contains('kind')));
    // 1 acceptance + 1 unit behavior, as in the demo.
    expect(
      RegExp(r'^\| A1 \|', multiLine: true).hasMatch(testList),
      isTrue,
      reason: testList,
    );
    expect(
      RegExp(r'^\| U1 \|', multiLine: true).hasMatch(testList),
      isTrue,
      reason: testList,
    );

    // ---------------------------------------------------------------
    // 2. run — the full loop over the plan-written list. Pre-#617 this
    //    stopped at A1:gen with `unknown behavior id "A1"`.
    // ---------------------------------------------------------------
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

    // The bug's failure signature must be gone.
    expect(out, isNot(contains('unknown behavior id')), reason: out);
    expect(out, isNot(contains('stopped_at=A1:gen')), reason: out);
    expect(out, isNot(contains('result=stopped')), reason: out);

    // The loop reaches the front door of every behavior: gen resolved
    // the 4-column rows for both behaviors.
    expect(out, contains('[run] A1 gen -> '), reason: out);
    expect(out, contains('[run] U1 gen -> '), reason: out);

    // All DONE with complete evidence, exit 0.
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 '
        'done=2',
      ),
      reason: out,
    );
    expect(exitCode, 0, reason: 'run must exit 0 when complete; out:\n$out');

    // Evidence: one red + one green entry per behavior (FR-003).
    final log = await File(fx.cycleLogPath).readAsString();
    for (final id in ['A1', 'U1']) {
      expect(
        RegExp('## Cycle: $id \\(red\\)').allMatches(log).length,
        1,
        reason: 'exactly one red entry for $id:\n$log',
      );
      expect(
        RegExp('## Cycle: $id \\(green\\)').allMatches(log).length,
        1,
        reason: 'exactly one green entry for $id:\n$log',
      );
    }

    // The real pipeline wired both subjects (green is real, not faked).
    for (final snake in ['a1', 'u1']) {
      final subject = File(
        p.join(fx.root.path, 'lib', 'tdd', feature, '${snake}_subject.dart'),
      ).readAsStringSync();
      // Bug #718: unit behaviors route to the `tdd func` surface, whose
      // documented contract replaces ONLY the stub declaration — the
      // gen stub's prose doc comment ("Throws [UnimplementedError]
      // until the real implementation lands") legitimately remains. The
      // functional stub marker is the throw itself: an unimplemented
      // subject always carries `throw UnimplementedError`, a scaffolded
      // one never does.
      expect(
        subject,
        isNot(contains('throw UnimplementedError')),
        reason: 'the pipeline must replace the $snake stub',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}
