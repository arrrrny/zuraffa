@Tags(['slow'])
// Issue #1550 — `zfa tdd reset 001-todo-app` left the corpus-wide
// baseline cache (`.zfa/corpus/run-baseline.json`, spec 069 T004)
// untouched. The cache is a THIRD store with the same restart contract
// as the registry + run-state reset already cleans, and its dependency
// fingerprint still matched the post-reset tree, so the very next
// `tdd run` hit the `corpus-wide reuse` path, materialized the
// feature-local run-baseline.json from a PRE-RESET snapshot, believed
// the 41 dropped behaviors (including U1) were green, and composed A1
// against artifacts the reset had deleted:
//
//   compose: behavior=A1 outcome=runner-error
//   make: behavior=A1 outcome=generation-error
//   run: result=stopped
//
// Second-order defect: reset's tombstone invalidates green evidence in
// the JOURNAL, but compose's anchor discovery reads the raw cycle-log
// green evidence and only fails the missing registry record as
// `missing-anchor-subject` → `runner-error` — a refusal the operator
// cannot act on, when the honest diagnosis is that the green PREMISE is
// stale (invalidated by the reset): `stale-evidence`.
//
// Fix under test:
//   B1 — reset invalidates the corpus-wide baseline cache alongside the
//        registry + run-state (and the feature-local run-baseline.json),
//        announced before acting.
//   B2 — after a reset, the next run does NOT reuse the corpus-wide
//        baseline: the live suite re-captures (the stale snapshot is
//        gone, not re-affirmed).
//   B3 — compose refuses a green unit whose registry record is absent
//        with outcome=stale-evidence (actionable), never runner-error.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '1550-stale-corpus-baseline';

  /// The corpus-wide cache path for the fixture root.
  String corpusCachePath() =>
      CorpusBaselineCache.pathFor(projectRoot: fx.root.path);

  /// Seed a corpus-wide baseline cache that the next run's driver would
  /// reuse on a fingerprint match — the pre-reset snapshot the issue's
  /// run logged as `corpus-wide reuse (fingerprint match; spec 069 T004)`
  /// with `1 pre-existing failure(s) captured 2026-09-11T13:24:43Z`.
  Future<void> seedCorpusCache() async {
    final cache = const CorpusBaselineCache();
    final fingerprint = await cache.dependencyFingerprint(fx.root.path);
    expect(fingerprint, isNotNull, reason: 'fixture must fingerprint');
    await cache.write(
      projectRoot: fx.root.path,
      snapshot: SuiteSnapshot(
        command: TddFixture.defaultSuiteTemplate,
        exitCode: 0,
        failedTests: const {},
        // The pre-reset capture stamp the issue's run reused.
        capturedAt: '2026-09-11T13:24:43.000Z',
        parseable: true,
      ),
      fingerprint: fingerprint!,
    );
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    // The fingerprint inputs: the lock beside the fixture's pubspec.
    await File(
      p.join(fx.root.path, 'pubspec.lock'),
    ).writeAsString('# lock v1 (pre-reset)\n');
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  group(
    'B1 — tdd reset invalidates the baseline caches (restart contract)',
    () {
      test('reset deletes the corpus-wide cache and the feature-local '
          'run-baseline.json, and announces the invalidation', () async {
        await fx.registerBehavior(id: 'A1', description: 'acceptance behavior');
        await seedCorpusCache();
        final featureBaseline = File(
          p.join(fx.featureDir, 'tdd', 'run-baseline.json'),
        );
        await featureBaseline.parent.create(recursive: true);
        await featureBaseline.writeAsString(
          jsonEncode({
            'command': 'dart test',
            'exitCode': 0,
            'failedTests': <String>[],
            'capturedAt': '2026-09-11T13:24:43.000Z',
            'parseable': true,
          }),
        );
        expect(File(corpusCachePath()).existsSync(), isTrue);
        expect(featureBaseline.existsSync(), isTrue);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'reset',
          feature,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: out);
        expect(out, contains('verdict=reset'), reason: out);

        // THE contract: no pre-reset baseline snapshot survives the reset.
        expect(
          File(corpusCachePath()).existsSync(),
          isFalse,
          reason:
              'the corpus-wide baseline cache is a third store with the '
              'same restart contract — reset must invalidate it: $out',
        );
        expect(
          featureBaseline.existsSync(),
          isFalse,
          reason: 'the feature-local baseline must not outlive its reset: $out',
        );
        // The invalidation is announced BEFORE acting, like every other
        // reset effect.
        expect(out, contains('corpus baseline'), reason: out);
      });

      test('reset with no baseline caches on disk still resets cleanly '
          '(the invalidation is idempotent)', () async {
        await fx.registerBehavior(id: 'A1', description: 'acceptance behavior');
        expect(File(corpusCachePath()).existsSync(), isFalse);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'reset',
          feature,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: out);
        expect(out, contains('verdict=reset'), reason: out);
      });
    },
  );

  group('B2 — the run after reset re-captures the baseline live', () {
    test(
      'the post-reset run does NOT reuse the corpus-wide baseline',
      () async {
        // Run 1: captures the baseline LIVE (1 suite spy run) and writes
        // the corpus-wide cache — the pre-reset state the issue's
        // dogfood run left behind.
        final testList = p.join(fx.featureDir, 'tdd', 'test-list.md');
        await Directory(fx.featureDir).create(recursive: true);
        await File(testList).writeAsString('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B-001 | the reset behavior | FR-001 | PENDING |
''');
        await fx.registerBehavior(
          id: 'B-001',
          description: 'the reset behavior',
        );
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

        final runner = CliRunner(exitOnCompletion: false);
        Future<String> drive() => runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);

        final out1 = await drive();
        expect(exitCode, 0, reason: out1);
        expect(fx.spyLog('suite'), hasLength(1), reason: out1);
        expect(File(corpusCachePath()).existsSync(), isTrue, reason: out1);

        // The reset: drops B-001's record + artifacts, tombstones its
        // green evidence — and (post-fix) invalidates the corpus cache.
        final resetOut = await runner.runCapturing([
          'tdd',
          'reset',
          feature,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: resetOut);

        // Run 2: the driver must NOT resume from the pre-reset snapshot.
        final out2 = await drive();
        expect(exitCode, 0, reason: out2);
        expect(
          out2,
          isNot(contains('corpus-wide reuse')),
          reason:
              'a reset must invalidate the corpus-wide baseline cache so '
              'the next run re-captures the suite live (the stale snapshot '
              'believes dropped behaviors are green): $out2',
        );
        expect(
          fx.spyLog('suite'),
          hasLength(2),
          reason: 'the post-reset baseline is a LIVE re-capture: $out2',
        );
        expect(
          File(corpusCachePath()).existsSync(),
          isTrue,
          reason:
              'the post-reset run re-populates the corpus-wide cache — the '
              'reset forces exactly ONE live re-capture, not a permanent '
              'opt-out of reuse: $out2',
        );
      },
    );
  });

  group('B3 — compose refuses a stale green-unit premise', () {
    test('a green unit whose registry record is absent is stale-evidence, '
        'not runner-error', () async {
      // The post-reset shape the issue repro created: A1 was re-generated
      // by the run (its record + subject exist), U1's record + artifacts
      // were dropped by the reset — but U1's green cycle-log evidence
      // SURVIVES (append-only; the tombstone lives in the journal).
      await fx.seedTestList([
        (
          id: 'A-001',
          description: 'the acceptance scenario',
          traces: 'FR-007',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U-001',
          description: 'the dropped unit behavior',
          traces: 'FR-007',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(id: 'A-001', description: 'the acceptance');
      await fx.registerBehavior(id: 'U-001', description: 'the dropped unit');
      await fx.seedRedEvidence('A-001'); // compose's certified-red premise
      await fx.seedGreenEvidence('U-001'); // the SURVIVING green claim
      // A1's artifacts exist on disk (the run re-generated them).
      await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
      await File(fx.subjectPathOf('A-001')).writeAsString('''
int subject_a_001() => throw UnimplementedError();
''');
      // U-001's artifacts were deleted by the reset: registry record
      // gone, subject file gone.
      final registryFile = File(fx.artifactsPath);
      final doc =
          jsonDecode(await registryFile.readAsString()) as Map<String, dynamic>;
      final records =
          (doc['records'] as List).cast<Map<String, dynamic>>().toList()
            ..removeWhere((r) => r['behavior_id'] == 'U-001');
      doc['records'] = records;
      await registryFile.writeAsString(jsonEncode(doc));
      final staleSubject = File(fx.subjectPathOf('U-001'));
      if (staleSubject.existsSync()) staleSubject.deleteSync();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'compose',
        'A-001',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 1, reason: out);
      // THE contract: the stale premise is named, not a runner error.
      expect(
        out,
        contains('outcome=stale-evidence'),
        reason:
            'a green unit whose registry record is absent is a '
            'stale-evidence refusal (the evidence was invalidated, '
            're-derive the artifacts), never a runner-error: $out',
      );
      expect(out, isNot(contains('outcome=runner-error')), reason: out);
      expect(out, contains('U-001'), reason: out);
    });
  });
}
