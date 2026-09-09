@Tags(['slow'])
// Issue #1324 — run resume re-drives green-but-not-done behaviors from
// gen: a fresh guard-only test over the certified pair dies at
// verify-red `unexpected-green` → make `subject-drift`; the feature is
// wedged (re-driving clobbers, making refuses) and `zfa tdd doctor`
// calls exactly this state healthy.
//
// Contract under test (issue #1324, SC-1..SC-4, spec
// 1324-resume-stale-artifacts-wedge):
//   B1 — resume skips the green-but-not-done re-drive: a behavior whose
//        cycle-log carries green evidence for the current artifact
//        generation (tombstone-filtered, certified test file backed on
//        disk) is NEVER re-driven from gen; it resumes at the phase-2
//        steps and the run completes.
//   B2 — a make `subject-drift` on a behavior carrying green evidence
//        stops `result=stale-artifacts` with the `zfa tdd reset`
//        prescription (not the generic "fix the failing step"), and the
//        failed step's diagnostics are still recorded (#1329).
//   B3 — the same-drive sequence (verify-red unexpected-green → skipped;
//        make subject-drift) names stale-artifacts too.
//   B4 — doctor detects the stale-artifacts contradiction (green
//        evidence certified BEFORE the registry's `created_at` for the
//        same behavior id): verdict=stale-artifacts, prescription=reset,
//        exit 1 — never healthy.
//   B5 — doctor guards: created_at BEFORE the certification stays
//        healthy; a legacy green entry without `- at:` fails open; the
//        evidence-without-artifact check keeps its priority (resume).
//   B6 — backward compatibility: a truly red (never green) behavior
//        still resumes from gen, full cycle, complete.
//   B7 — the summary line keeps its shape for an unaffected feature.
//
// Fast tier within the slow tag: the driver runs over the scripted fake
// zfa binary (no real `dart test` children) — the issue_1308 driver-test
// convention.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  Future<String> drive(String feature) =>
      runCli(['run', feature, '--zfa-bin', fx.fakeZfaBin]);

  /// Seed the certified pair of a green-but-not-done behavior: the
  /// certified test file on disk (make went GREEN, refactor pending) and
  /// the red+green evidence entries in the cycle log (the driver's
  /// reconcile maps the behavior to `green`, evidence beats state).
  Future<void> seedGreenButNotDone(String id) async {
    final testFile = File(fx.testPathOf(id));
    await testFile.parent.create(recursive: true);
    await testFile.writeAsString(TddFixture.greenTest('the $id behavior'));
    await fx.seedRedEvidence(id);
    await fx.seedGreenEvidence(id);
  }

  /// Seed a registry record for [id] whose pair exists on disk with an
  /// explicit [createdAt] (the fixture default is the green evidence's
  /// certification timestamp; the doctor scenarios need full control).
  ///
  /// Recorded paths use the portable project-relative POSIX form (issue
  /// #1397) — the canonical form post-fix gen writes. A machine-absolute
  /// record is the separate form-drift class doctor's 2e check
  /// prescribes `migrate-paths` for, which would shadow the
  /// certification-vs-generation contradiction under test here.
  Future<void> seedRegistryRecord(
    String feature,
    String id,
    String createdAt,
  ) async {
    final subjectPath = p.join(fx.root.path, 'lib', 'a1_subject.dart');
    final subjectFile = File(subjectPath);
    await subjectFile.parent.create(recursive: true);
    await subjectFile.writeAsString('int a1Value() => 42;\n');
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    String recorded(String absolute) =>
        p.relative(absolute, from: fx.root.path).replaceAll(r'\', '/');
    final recordedTestPath = recorded(fx.testPathOf(id));
    await File(fx.artifactsPath).writeAsString(
      jsonEncode({
        'feature': feature,
        'records': [
          {
            'behavior_id': id,
            'feature': feature,
            'source_criterion': 'FR-001',
            'test_path': recordedTestPath,
            'subject_path': recorded(subjectPath),
            'runnable_test_name': '$recordedTestPath::$id::the $id behavior',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': createdAt,
          },
        ],
      }),
    );
  }

  tearDown(() {
    exitCode = 0;
  });

  test(
    'B1: resume skips the green-but-not-done re-drive — no gen over certified green (SC-1)',
    () async {
      const feature = '1324-resume-skip';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      // The issue's repro shape: A1 green-but-not-done, U6 fresh-pending
      // (the #1323 dead-end behavior).
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the A1 behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U6',
          description: 'the U6 behavior',
          traces: 'FR-006',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedRunState(states: {'A1': 'green', 'U6': 'pending'});
      await seedGreenButNotDone('A1');
      // The registry is CORRUPT (the kill-mid-write shape: gen's
      // non-atomic append truncated) — findRecord is null for every
      // behavior, which is what sent green behaviors back through gen.
      await File(fx.artifactsPath).writeAsString(
        '{"feature": "$feature", "records": [{"behavior_id": "A1"',
      );
      // The scripted contradiction the wedge produced: the fresh
      // guard-only test unexpected-greens and make refuses the drift.
      await fx.setStepOutcome('verify-red', 'A1', 'unexpected-green');
      await fx.setStepOutcome('make', 'A1', 'subject-drift');

      final out = await drive(feature);
      final invocations = fx.stepInvocations();

      expect(out, contains('result=complete'), reason: out);
      expect(
        invocations,
        isNot(contains('gen A1')),
        reason:
            'resume must not gen over a pair whose cycle-log carries '
            'green evidence for the current artifact generation: '
            '$invocations',
      );
      expect(
        invocations,
        isNot(contains('make A1')),
        reason:
            'the green behavior resumes at phase 2, not at make: '
            '$invocations',
      );
      expect(
        invocations,
        contains('refactor A1'),
        reason:
            'the green-but-not-done behavior completes its ladder at '
            'refactor: $invocations',
      );
      expect(
        invocations,
        contains('gen U6'),
        reason: 'the fresh behavior is driven normally: $invocations',
      );
      expect(invocations, contains('make U6'), reason: out);
    },
  );

  test(
    'B2: a make subject-drift on a green-evidenced behavior stops stale-artifacts with the reset prescription (SC-2)',
    () async {
      const feature = '1324-stale-stop';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      await fx.setStepOutcome('make', 'A1', 'subject-drift');
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the A1 behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // A red claim keeps its make-starting window (the red state maps
      // to make) while the cycle-log already carries green evidence —
      // the contradiction class, reached without a gen re-drive.
      await fx.seedRunState(states: {'A1': 'red'});
      await fx.registerBehavior(id: 'A1', description: 'the A1 behavior');
      await fx.seedRedEvidence('A1');
      await fx.seedGreenEvidence('A1');

      final out = await drive(feature);

      expect(exitCode, 1, reason: out);
      expect(out, contains('result=stale-artifacts'), reason: out);
      expect(out, contains('stopped_at=A1:make'), reason: out);
      expect(
        out,
        contains('--> fix: zfa tdd reset $feature'),
        reason: 'the prescription names the recovery that works: $out',
      );
      expect(out, contains('issue #1324'), reason: out);
      expect(
        out,
        isNot(contains('resume: fix the failing step')),
        reason:
            'the generic hint must not stand for the contradiction: '
            '$out',
      );
      // The #1329 diagnostic discipline survives: the failed step's
      // evidence lands in the cycle log.
      final cycleLog = File(fx.cycleLogPath).readAsStringSync();
      final errorSection = cycleLog
          .split('\n## ')
          .firstWhere((section) => section.contains('- kind: error'));
      expect(errorSection, contains('- outcome: subject-drift'));
    },
  );

  test(
    'B3: unexpected-green then subject-drift in one drive names stale-artifacts (SC-2)',
    () async {
      const feature = '1324-same-drive';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      // The issue's exact step sequence within ONE drive: verify-red
      // unexpected-green (the skip arm) followed by make subject-drift.
      await fx.setStepOutcome('verify-red', 'A1', 'unexpected-green');
      await fx.setStepOutcome('make', 'A1', 'subject-drift');
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'the A1 behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedRunState(states: {'A1': 'blocked'});
      await fx.registerBehavior(id: 'A1', description: 'the A1 behavior');
      await fx.seedGreenEvidence('A1');

      final out = await drive(feature);

      expect(
        out,
        contains('verify-red -> skipped (already green)'),
        reason: out,
      );
      expect(out, contains('result=stale-artifacts'), reason: out);
      expect(out, contains('stopped_at=A1:make'), reason: out);
      expect(out, contains('--> fix: zfa tdd reset $feature'), reason: out);
      expect(out, isNot(contains('resume: fix the failing step')), reason: out);
    },
  );

  test(
    'B4: doctor reports stale-artifacts — never healthy — with the same reset prescription (SC-3)',
    () async {
      const feature = '1324-doctor-stale';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await seedGreenButNotDone('A1'); // green certified at 00:00Z
      // The registry's artifact generation is NEWER than the
      // certification — gen re-ran over the certified pair without a
      // re-certification (the #1324 re-drive class). Files exist, the
      // state claims are evidence-backed: every store reads
      // self-consistent, which is exactly why doctor called it healthy.
      await seedRegistryRecord(feature, 'A1', '2026-08-30T12:00:00.000Z');
      await fx.seedRunState(states: {'A1': 'green'});

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('"verdict":"stale-artifacts"'), reason: out);
      expect(out, contains('"prescription":"reset"'), reason: out);
      expect(
        out,
        contains('--> fix: zfa tdd reset $feature'),
        reason: 'the prescription must match the run driver stop: $out',
      );
      expect(out, contains('A1'), reason: out);
      expect(out, isNot(contains('"verdict":"healthy"')), reason: out);
    },
  );

  test(
    'B5a: a registry record created BEFORE the certification stays healthy (SC-3 guard)',
    () async {
      const feature = '1324-doctor-healthy';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await seedGreenButNotDone('A1');
      // The record predates the green evidence (the normal gen → red →
      // green order) — no contradiction, no drift.
      await seedRegistryRecord(feature, 'A1', '2026-08-29T00:00:00.000Z');
      await fx.seedRunState(states: {'A1': 'green'});

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 0, reason: out);
      expect(out, contains('"verdict":"healthy"'), reason: out);
    },
  );

  test(
    'B5b: a legacy green entry without a parseable - at: fails open (SC-3 guard)',
    () async {
      const feature = '1324-doctor-legacy';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      // The certified test file exists; the green entry is legacy
      // schema-0 (no `- at:` line) — never failed by the doctor.
      final testFile = File(fx.testPathOf('A1'));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(TddFixture.greenTest('the A1 behavior'));
      final cycleFile = File(fx.cycleLogPath);
      await cycleFile.parent.create(recursive: true);
      await cycleFile.writeAsString(
        '# Cycle Log\n\n'
        '## Cycle: A1 (green)\n\n'
        '- behavior: A1\n'
        '- kind: green\n'
        '- criterion: FR-003\n'
        '- test: ${fx.testPathOf('A1')}\n'
        '- exit: 0\n\n',
      );
      await seedRegistryRecord(feature, 'A1', '2026-08-30T12:00:00.000Z');
      await fx.seedRunState(states: {'A1': 'green'});

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 0, reason: out);
      expect(out, contains('"verdict":"healthy"'), reason: out);
    },
  );

  test(
    'B5c: evidence-without-artifact keeps its priority — resume, not reset (SC-4 guard)',
    () async {
      const feature = '1324-doctor-orphan';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      // The post-reset phantom: green evidence survives (append-only)
      // but its certified test file is GONE and the registry was
      // dropped — the #1264 check fires before the stale-artifacts
      // check and still prescribes resume.
      await fx.seedGreenEvidence('A1');
      await fx.seedRunState(states: {'A1': 'green'});

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('evidence-without-artifact'), reason: out);
      expect(out, contains('"prescription":"resume"'), reason: out);
      expect(
        out,
        isNot(contains('"prescription":"reset"')),
        reason: 'the orphaned-evidence recovery is unchanged: $out',
      );
    },
  );

  test(
    'B6: a truly red (never green) behavior still resumes from gen (SC-4)',
    () async {
      const feature = '1324-compat-gen';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U6',
          description: 'the U6 behavior',
          traces: 'FR-006',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedRunState(states: {'U6': 'pending'});

      final out = await drive(feature);
      final invocations = fx.stepInvocations();

      expect(out, contains('result=complete'), reason: out);
      expect(
        invocations,
        contains('gen U6'),
        reason:
            'no green evidence — the full cycle from gen stands: '
            '$invocations',
      );
      expect(invocations, contains('verify-red U6'), reason: out);
      expect(invocations, contains('make U6'), reason: out);
      expect(invocations, contains('refactor U6'), reason: out);
    },
  );

  test(
    'B7: the summary line keeps its shape for an unaffected feature (SC-4)',
    () async {
      const feature = '1324-summary-shape';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U6',
          description: 'the U6 behavior',
          traces: 'FR-006',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedRunState(states: {'U6': 'pending'});

      final out = await drive(feature);

      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 '
          'green=0 done=1',
        ),
        reason: out,
      );
    },
  );
}
