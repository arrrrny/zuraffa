// Issue #741 — the TDD run driver and make command run the FULL suite
// (`dart test` of the whole project) once per behavior (baseline +
// guard = 2 suite runs per behavior; 39 U* behaviors → 78 full-suite
// runs at 1-3 min each). This file pins the performance fix:
//
//   1. the #694 skip transition (already-green behavior) runs NO suite
//      at all — the scoped single-test run is the only evidence run;
//   2. `make` consumes a cached suite baseline (`--suite-baseline`,
//      written once per `tdd run` by the driver) instead of running
//      the suite per behavior, and certifies the post-generation guard
//      from the scoped single-test result (falling back to the live
//      suite when the cache is missing/corrupt/unparseable);
//   3. the driver caches the baseline ONCE per run and passes it to
//      every make step;
//   4. standalone `make` (no flag) keeps the live baseline + guard
//      contract unchanged.
//
// The runners here are spy scripts emitting real package:test-shaped
// transcripts (parseable by the SuiteGuard grammar), so the tests stay
// in the FAST tier — no `dart test` subprocess is ever compiled.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-driver';

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('skip transition (issue #694) — no suite runs at all (issue #741)', () {
    test('an already-green behavior is certified skipped with zero suite '
        'invocations; only the scoped single test runs', () async {
      final marker = p.join(fx.root.path, '.tdd-spy', 'marker');
      final singleSpy = await fx.writeGatedSingleSpy(marker: marker);
      await File(marker).parent.create(recursive: true);
      await File(marker).writeAsString('green');
      final suiteSpy = await fx.writeSpyScript(
        'suite',
        output: TddFixture.greenSuiteTranscript,
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: suiteSpy,
      );
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: 'create entity User with email',
        testContent: TddFixture.greenTest('create entity User with email'),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'B-001',
        '--project',
        fx.root.path,
      ]);

      expect(
        out,
        contains('make: behavior=B-001 outcome=skipped feature=$feature'),
        reason: out,
      );
      expect(exitCode, 0, reason: out);

      // Issue #741: the skip transition must not run the full suite —
      // the drift re-run (scoped single) is the only evidence run.
      expect(fx.spyLog('suite'), isEmpty, reason: 'suite must not run');

      // Green evidence still appended; the suite line renders with the
      // honest zeros (no suite ran, nothing was generated).
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: B-001 (green)'));
      expect(cycleLog, contains('- suite: baseline=0 guard=0 new=(none)'));
    });
  });

  group('cached baseline (--suite-baseline)', () {
    Future<String> seedRedBehaviorWithGatedSpy() async {
      final marker = p.join(fx.root.path, '.tdd-spy', 'marker');
      final singleSpy = await fx.writeGatedSingleSpy(marker: marker);
      final suiteSpy = await fx.writeSpyScript(
        'suite',
        output: TddFixture.oneRedSuiteTranscript,
        exit: '1',
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: suiteSpy,
      );
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: 'create entity User with email',
        testContent: TddFixture.subjectDrivenTest(
          'B-001',
          'create entity User with email',
        ),
      );
      // The fake pipeline "generates" by creating the marker the single
      // spy gates on — the target test flips green post-generation.
      return marker;
    }

    Future<String> writeBaselineCache() async {
      final suiteSpy = p.join(fx.spyDir, 'suite');
      await Directory(fx.runBaselinePath).parent.create(recursive: true);
      final cache = File(fx.runBaselinePath);
      await cache.writeAsString(
        jsonEncode({
          'command': suiteSpy,
          'exitCode': 1,
          'failedTests': ['test/other_test.dart: other behavior red'],
          'capturedAt': '2026-09-01T00:00:00.000Z',
          'parseable': true,
        }),
      );
      return cache.path;
    }

    test('make reuses the cached baseline and guards from the scoped '
        'single-test result — zero live suite runs', () async {
      final marker = await seedRedBehaviorWithGatedSpy();
      final cachePath = await writeBaselineCache();
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': ['touch "$marker"'],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'B-001',
        '--project',
        fx.root.path,
        '--suite-baseline',
        cachePath,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(
        out,
        contains('make: behavior=B-001 outcome=green feature=$feature'),
        reason: out,
      );
      expect(exitCode, 0, reason: out);

      // Issue #741: baseline from the cache, guard from the scoped
      // single-test result — the suite itself never runs.
      expect(
        fx.spyLog('suite'),
        isEmpty,
        reason: 'a usable cached baseline must suppress live suite runs',
      );

      // Evidence contract: baseline numbers from the cache (1 pre-
      // existing failure), guard from the scoped run (0), no new
      // failures. Rendering unchanged.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('- suite: baseline=1 guard=0 new=(none)'));
    });

    test('standalone make without the flag keeps the live baseline + '
        'guard contract', () async {
      await seedRedBehaviorWithGatedSpy();
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': ['touch "${p.join(fx.spyDir, 'marker')}"'],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'B-001',
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(
        out,
        contains('make: behavior=B-001 outcome=green feature=$feature'),
        reason: out,
      );
      expect(exitCode, 0, reason: out);

      // No flag → no cache involvement: the live suite runs for the
      // baseline AND the guard (2 invocations), unchanged.
      expect(fx.spyLog('suite').length, 2);
    });

    test('a corrupt cache file is a safe failure: make falls back to the '
        'live suite', () async {
      await seedRedBehaviorWithGatedSpy();
      await Directory(fx.runBaselinePath).parent.create(recursive: true);
      await File(fx.runBaselinePath).writeAsString('{not json');
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': ['touch "${p.join(fx.spyDir, 'marker')}"'],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'B-001',
        '--project',
        fx.root.path,
        '--suite-baseline',
        fx.runBaselinePath,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(
        out,
        contains('make: behavior=B-001 outcome=green feature=$feature'),
        reason: out,
      );
      expect(exitCode, 0, reason: out);
      // Fallback: live baseline + live guard.
      expect(fx.spyLog('suite').length, 2);
    });
  });

  group('run driver — baseline cached once per run (issue #741)', () {
    Future<String> drive() async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
    }

    test('the driver runs the suite once, writes the cache, and passes '
        '--suite-baseline to every make step', () async {
      final suiteSpy = await fx.writeSpyScript(
        'suite',
        output: TddFixture.greenSuiteTranscript,
      );
      final singleSpy = await fx.writeSpyScript(
        'single',
        output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: suiteSpy,
      );
      await fx.writeFakeZfa();
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
        (
          id: 'B-003',
          description: 'third behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await drive();

      expect(exitCode, 0, reason: out);

      // The suite ran exactly ONCE for the whole run (the cached
      // baseline) — not once per behavior.
      expect(fx.spyLog('suite').length, 1, reason: out);

      // The cache file exists with the snapshot contract.
      final cache = File(fx.runBaselinePath);
      expect(cache.existsSync(), isTrue, reason: out);
      final decoded =
          jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
      expect(decoded['command'], suiteSpy);
      expect(decoded['parseable'], isTrue);

      // Every make step received the cached baseline.
      final makeArgv = fx
          .stepArgvLog()
          .where((line) => line.contains(' make '))
          .toList();
      expect(makeArgv, hasLength(3));
      for (final line in makeArgv) {
        expect(line, contains('--suite-baseline'));
        expect(line, contains(fx.runBaselinePath));
      }
    });

    test('an unusable suite disables caching (no flag, no cache file) and '
        'the run still completes', () async {
      final singleSpy = await fx.writeSpyScript(
        'single',
        output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
      );
      // Unparseable suite transcript (no progress markers, exit 1).
      await fx.writeSpyScript('suite', output: 'boom', exit: '1');
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: p.join(fx.spyDir, 'suite'),
      );
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

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(File(fx.runBaselinePath).existsSync(), isFalse);
      for (final line in fx.stepArgvLog().where((l) => l.contains(' make '))) {
        expect(line, isNot(contains('--suite-baseline')));
      }
    });

    test('an interrupted run resumes with a fresh cached baseline (suite '
        'runs once on the resume, make steps get the flag)', () async {
      final suiteSpy = await fx.writeSpyScript(
        'suite',
        output: TddFixture.greenSuiteTranscript,
      );
      final singleSpy = await fx.writeSpyScript(
        'single',
        output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: suiteSpy,
      );
      await fx.writeFakeZfa();
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
      // Interrupted-run residue: B-001 was certified red (gen artifacts
      // present, red evidence in the cycle log) before the crash. The
      // resume must re-establish the baseline fresh — never reuse a
      // stale snapshot written before the interruption.
      await fx.registerBehavior(id: 'B-001', description: 'first behavior');
      await fx.seedRedEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'red'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      expect(out, contains('result=complete'), reason: out);

      // The resume ran the suite exactly once (its own fresh baseline).
      expect(fx.spyLog('suite').length, 1, reason: out);
      expect(File(fx.runBaselinePath).existsSync(), isTrue, reason: out);
      final makeArgv = fx
          .stepArgvLog()
          .where((line) => line.contains(' make '))
          .toList();
      expect(makeArgv, hasLength(2));
      for (final line in makeArgv) {
        expect(line, contains('--suite-baseline'));
      }
    });
  });
}
