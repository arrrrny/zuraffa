@Tags(['slow', 'integration'])
// SC-021 — acceptance composition e2e (spec 052-acceptance-make-composition,
// issue #642): the REAL-pipeline counterpart of the driver tests' scripted
// phase-2 flip.
//
//   plan → run  on a real temp project with the REAL pipeline (a pure exec
//   forwarder to bin/zfa.dart — no fake generation semantics, SC-017/018
//   provisioning).
//
// Before this feature the phase-2 re-attempt of a deferred acceptance make
// deterministically reported `unexpressible` again (the planner is pure and
// description-keyed), so the run honest-stopped at A1:make with the units
// green. With the composition surface, the phase-2 make falls back to
// compose → build, the acceptance subject is wired against the feature's
// green unit subjects, and the run completes all-DONE — no fake-zfa
// scripting of the phase-2 outcome.
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
  const feature = '001-compose-demo';

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    repoRoot = _findZuraffaRoot();

    // Enrich the fixture into a real buildable project (same provisioning
    // as SC-017/SC-018: the real pipeline needs zorphy + json codegen).
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

    // The spec: one PURE-PROSE acceptance scenario (no entity/CRUD
    // keywords — unexpressible to the planner by design) and one
    // entity-bearing FR the real pipeline can implement. A1 defers at its
    // phase-1 make; U1 goes green in phase 1; phase 2 composes A1 against
    // U1's green subject.
    await File(p.join(fx.root.path, 'specs', feature, 'spec.md')).writeAsString(
      '''
# Spec: $feature

## Functional Requirements

- **FR-001**: create entity Account with status

## Acceptance Scenarios

1. **Given** a signup request **When** a user registers **Then** the signup flow completes and the account is usable
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

  test('A1: phase-2 composition flips the deferred acceptance make green '
      'through the real pipeline', () async {
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

    // ---------------------------------------------------------------
    // 2. run — the full loop over the plan-written list, REAL pipeline.
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

    // The phase-1 deferral happened (the planner refuses the prose).
    expect(out, contains('[run] A1 gen -> ok'), reason: out);
    expect(out, contains('[run] A1 make -> deferred (phase 2)'), reason: out);
    // THE FLIP: phase 2 re-attempts the make and composition turns it
    // green — with no scripted fake step.
    expect(out, contains('[run] A1 make -> green (phase 2)'), reason: out);
    // The refactor pass completes on the fully-green suite (bug #635).
    expect(out, contains('[run] U1 refactor -> '), reason: out);
    expect(out, contains('[run] A1 refactor -> '), reason: out);

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

    // The acceptance subject was COMPOSED: the stub is gone and the
    // green unit subject is the implementation anchor.
    final a1Subject = File(
      p.join(fx.root.path, 'lib', 'tdd', feature, 'a1_subject.dart'),
    ).readAsStringSync();
    expect(a1Subject, isNot(contains('UnimplementedError')));
    expect(a1Subject, contains('GENERATED IMPLEMENTATION'));
    expect(a1Subject, contains('zfa tdd compose A1'));
    expect(
      a1Subject,
      contains('package:tdd_fixture/tdd/001-compose-demo/u1_subject.dart'),
    );
    expect(a1Subject, contains('subject_u1'));
  }, timeout: const Timeout(Duration(minutes: 25)));

  test(
    'A2: the composed behavior\'s green evidence names the compose step',
    () async {
      await _runRealZfa(repoRoot, [
        'tdd',
        'plan',
        feature,
        '--project',
        fx.root.path,
      ], workingDirectory: fx.root.path);

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
      expect(exitCode, 0, reason: out);

      final log = await File(fx.cycleLogPath).readAsString();
      // Exactly one green entry for A1, and its captured generation steps
      // include the compose invocation (the audit trail is honest — every
      // actual invocation captured, never the planner's decision).
      expect(RegExp('## Cycle: A1 \\(green\\)').allMatches(log).length, 1);
      final greenSection = log.substring(log.indexOf('## Cycle: A1 (green)'));
      expect(greenSection, contains('tdd compose A1'));
      expect(greenSection, contains('build'));
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}
