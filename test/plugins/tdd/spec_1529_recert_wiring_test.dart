// Spec 1529 (US3) — the make command WIRES the trimmed re-certification.
//
// With a run-cached full-suite baseline and a neighbor test that imports
// the written subject, the guard runs ONE scoped invocation covering
// {own test, neighbor} — never the full suite — and diffs its failures
// against the cached baseline through the existing #731 tolerance. The
// untouched-rest proof gates the trim: a generation that writes a shared
// file outside the declared set, or an unprovable fingerprint, falls
// back to the EXISTING full-suite guard (fail-closed).
//
// The runners are spy scripts (the run_baseline_cache_test pattern), so
// the tests stay in the fast tier.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-run-driver';

  /// A neighbor test importing the SAME subject the behavior's own test
  /// imports — the importer the trimmed re-certification set must cover —
  /// plus an unrelated test the write set cannot reach (so the scope is
  /// a proper subset of the tree and the whole-tree fail-closed rule
  /// does not swallow the trim).
  Future<void> seedNeighborImporter() async {
    await Directory(p.join(fx.root.path, 'test')).create(recursive: true);
    await File(
      p.join(fx.root.path, 'test', 'b_001_neighbor_test.dart'),
    ).writeAsString(
      TddFixture.subjectDrivenTest(
        'B-001',
        'neighbor watches the same subject',
        expected: 1,
      ),
    );
    await File(
      p.join(fx.root.path, 'test', 'unrelated_test.dart'),
    ).writeAsString(
      "import 'package:test/test.dart';\n\n"
      'void main() {\n  test(\'unrelated\', () {});\n}\n',
    );
  }

  Future<String> writeBaselineCache({required String suiteSpy}) async {
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    final fingerprint = await const CorpusBaselineCache().dependencyFingerprint(
      fx.root.path,
    );
    final cache = File(fx.runBaselinePath);
    await cache.writeAsString(
      jsonEncode({
        'command': suiteSpy,
        'exitCode': 1,
        'failedTests': ['test/other_test.dart: other behavior red'],
        'capturedAt': '2026-09-01T00:00:00.000Z',
        'parseable': true,
        'dependency_fingerprint': ?fingerprint,
      }),
    );
    return cache.path;
  }

  /// A single-test spy that emits a parseable RED before the marker
  /// exists and an unparseable exit-0 transcript after it — scripting
  /// the unusable-guard shape the fallbacks key on.
  Future<String> writeGarbageAfterGreenSingleSpy({
    required String marker,
  }) async {
    await Directory(fx.spyDir).create(recursive: true);
    final logPath = p.join(fx.spyDir, 'single.log');
    final scriptPath = p.join(fx.spyDir, 'single');
    await File(scriptPath).writeAsString(
      '#!/bin/sh\necho "\$@" >> "$logPath"\n'
      'if [ -f "$marker" ]; then\n'
      '  echo "nothing parseable here — the runner emitted noise"\n'
      '  exit 0\n'
      'else\n'
      '  printf \'00:00 +0 -1: %s: %s [E]\\n00:00 +0 -1: Some tests failed.\\n\' "\$1" "\$2"\n'
      '  exit 1\n'
      'fi\n',
    );
    Process.runSync('chmod', ['+x', scriptPath]);
    return scriptPath;
  }

  Future<String> seedBehavior({bool garbageAfterGreen = false}) async {
    final marker = p.join(fx.root.path, '.tdd-spy', 'marker');
    final String singleSpy;
    if (garbageAfterGreen) {
      // The post-generation single-test transcript is UNPARSEABLE (exit
      // 0, garbage): the cached path's scoped-transcript guard is then
      // unusable, so the guard reaches the trimmed/full-suite decision
      // instead of short-circuiting on the #741 transcript.
      singleSpy = await writeGarbageAfterGreenSingleSpy(marker: marker);
    } else {
      singleSpy = await fx.writeGatedSingleSpy(marker: marker);
    }
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
      testContent: TddFixture.subjectDrivenTest(
        'B-001',
        'create entity User with email',
      ),
    );
    return suiteSpy;
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'U12a: with importers present the guard runs ONE scoped invocation '
    'covering the own test and the neighbor — never the full suite',
    () async {
      final suiteSpy = await seedBehavior();
      await seedNeighborImporter();
      final cachePath = await writeBaselineCache(suiteSpy: suiteSpy);
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
      expect(
        out,
        contains('trimmed re-certification set'),
        reason: 'the guard names the trimmed scope (spec 1529)',
      );

      // Exactly ONE suite invocation, covering BOTH tests (sorted), and
      // NOT the bare full-suite template.
      final log = fx.spyLog('suite');
      expect(log.length, 1, reason: 'suite invocations: $log');
      expect(log.single, contains('test/b_001_test.dart'));
      expect(log.single, contains('test/b_001_neighbor_test.dart'));
    },
  );

  test('U12b: a shared write outside the declared set fails closed — the '
      'full-suite guard runs unchanged', () async {
    final suiteSpy = await seedBehavior(garbageAfterGreen: true);
    await seedNeighborImporter();
    final cachePath = await writeBaselineCache(suiteSpy: suiteSpy);
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'entity create': [
          // The marker flips the target test green (the make green
          // path) AND a shared lib file is written outside the
          // declared {subject, test} set — the mtime proof fails.
          'touch "${p.join(fx.spyDir, 'marker')}"',
          'mkdir -p "${p.join(fx.root.path, 'lib', 'src')}"',
          'printf "class Shared {}\\n" > '
              '"${p.join(fx.root.path, 'lib', 'src', 'shared.dart')}"',
        ],
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
    expect(
      out,
      isNot(contains('trimmed re-certification set')),
      reason: 'the proof failed — no trim',
    );

    // The full-suite guard: one invocation with the BARE template (no
    // scoped test paths appended).
    final log = fx.spyLog('suite');
    expect(log.length, 1, reason: 'suite invocations: $log');
    expect(
      log.single,
      isNot(contains('b_001_neighbor_test')),
      reason: 'the full suite must not carry scoped paths',
    );
  });

  test('U12c: an unprovable fingerprint fails closed — the full-suite guard '
      'runs unchanged', () async {
    final suiteSpy = await seedBehavior(garbageAfterGreen: true);
    await seedNeighborImporter();
    // A fingerprint that cannot match what make recomputes.
    final cachePath = await writeBaselineCache(suiteSpy: suiteSpy).then((
      _,
    ) async {
      final cache = File(fx.runBaselinePath);
      final json = jsonDecode(cache.readAsStringSync()) as Map<String, dynamic>;
      json['dependency_fingerprint'] = 'stale-fingerprint';
      await cache.writeAsString(jsonEncode(json));
      return cache.path;
    });
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
    expect(
      out,
      isNot(contains('trimmed re-certification set')),
      reason: 'the fingerprint is not provable — no trim',
    );
    final log = fx.spyLog('suite');
    expect(log.length, 1, reason: 'suite invocations: $log');
    expect(log.single, isNot(contains('b_001_neighbor_test')));
  });

  test(
    'U12d: with no importer the cached-baseline guard keeps certifying '
    'from the post-generation transcript — zero extra suite spawns',
    () async {
      final suiteSpy = await seedBehavior();
      final cachePath = await writeBaselineCache(suiteSpy: suiteSpy);
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
      // The #741 contract: the suite never runs; the scoped single-test
      // transcript is the guard.
      expect(fx.spyLog('suite'), isEmpty, reason: out);
      expect(out, contains('suite guard: scoped single-test result'));
    },
  );
}
