@Tags(['slow'])
// Bug #840 — first-class TDD recovery commands: `zfa tdd gen <id> --adopt`,
// `zfa tdd reset <feature>`, and `zfa tdd doctor <feature>`.
//
// RED evidence: after a crash/interrupt/merge, files exist on disk that
// artifacts.json does not own, and no command exists to adopt them, reset
// the feature, or diagnose the state — the operator had to hand-edit
// run-state.json (the trust violation VISION forbids). All three commands
// must emit a JSON verdict (the final stdout line) and respect the exit
// protocol (0 healthy/success, 1 drift/refusal).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-bug-840';
  const behaviorId = 'B-001';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The last non-empty stdout line — every recovery command's JSON
  /// verdict contract.
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  /// Write the REAL generated-shape pair for [behaviorId] at the gen
  /// default layout (test/tdd/, lib/tdd/) WITHOUT a registry record —
  /// the post-crash unowned state.
  Future<void> seedUnownedPair() async {
    final behavior = Behavior(
      id: behaviorId,
      feature: feature,
      kind: BehaviorKind.unit,
      description: 'returns 42 when invoked with no args',
      sourceCriterion: 'FR-001',
      target: 'subjectUnderTest',
    );
    final behavior_ = behavior;
    await const BehaviorTestWriter().write(
      behavior: behavior_,
      testPath: p.join(fx.root.path, 'test', 'tdd', 'b_001_test.dart'),
      subjectPath: p.join(fx.root.path, 'lib', 'tdd', 'b_001_subject.dart'),
    );
    await const SubjectWriter().write(
      behavior: behavior_,
      subjectPath: p.join(fx.root.path, 'lib', 'tdd', 'b_001_subject.dart'),
    );
  }

  String registryPath() =>
      p.join(fx.root.path, 'specs', feature, 'tdd', 'artifacts.json');

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
    await fx.seedTestList([
      (
        id: behaviorId,
        description: 'returns 42 when invoked with no args',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('zfa tdd gen <id> --adopt', () {
    test('bug 840 RED: --adopt verifies the generated shape, registers '
        'ownership, audit-logs, and emits a JSON verdict', () async {
      await seedUnownedPair();
      expect(File(registryPath()).existsSync(), isFalse);

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 0, reason: out);
      // Ownership registered.
      expect(File(registryPath()).existsSync(), isTrue, reason: out);
      final registry =
          jsonDecode(await File(registryPath()).readAsString())
              as Map<String, dynamic>;
      final records = (registry['records'] as List).cast<Map>();
      expect(
        records.any((r) => r['behavior_id'] == behaviorId),
        isTrue,
        reason: out,
      );
      // Adopted files were NOT rewritten (ownership only).
      final testContent = await File(
        p.join(fx.root.path, 'test', 'tdd', 'b_001_test.dart'),
      ).readAsString();
      expect(testContent, contains('// behavior_id: $behaviorId'));
      // Audit trail.
      final audit = File(
        p.join(fx.root.path, 'specs', feature, 'tdd', 'audit.log'),
      );
      expect(audit.existsSync(), isTrue, reason: out);
      expect(audit.readAsStringSync(), contains('"action":"adopt"'));
      // JSON verdict (final line).
      final v = verdict(out);
      expect(v['command'], 'gen');
      expect(v['verdict'], 'adopted');
    });

    test('bug 840 RED: --adopt refuses files that do not match the generated '
        'shape (never blindly registers)', () async {
      // An unowned file WITHOUT the provenance header: not provably a
      // generated artifact.
      final testFile = File(
        p.join(fx.root.path, 'test', 'tdd', 'b_001_test.dart'),
      );
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('void main() {}\n');

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 1, reason: out);
      expect(File(registryPath()).existsSync(), isFalse, reason: out);
      final v = verdict(out);
      expect(v['command'], 'gen');
      expect(v['verdict'], 'refused');
    });

    test('bug 840 RED: --adopt adopts the shaped half and generates the '
        'missing half (crash between the two writes)', () async {
      // Only the test file exists (shaped); the subject never landed.
      final behavior = Behavior(
        id: behaviorId,
        feature: feature,
        kind: BehaviorKind.unit,
        description: 'returns 42 when invoked with no args',
        sourceCriterion: 'FR-001',
        target: 'subjectUnderTest',
      );
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: p.join(fx.root.path, 'test', 'tdd', 'b_001_test.dart'),
        subjectPath: p.join(fx.root.path, 'lib', 'tdd', 'b_001_subject.dart'),
      );

      final out = await runCli([
        'gen',
        behaviorId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 0, reason: out);
      expect(
        File(
          p.join(fx.root.path, 'lib', 'tdd', 'b_001_subject.dart'),
        ).existsSync(),
        isTrue,
        reason: 'the missing half must be generated: $out',
      );
      final v = verdict(out);
      expect(v['verdict'], 'adopted');
      expect((v['adopted'] as List).join(' '), contains('b_001_test.dart'));
      expect((v['created'] as List).join(' '), contains('b_001_subject.dart'));
    });
  });

  group('zfa tdd reset <feature>', () {
    test(
      'bug 840 RED: reset drops owned files and registry, resets run-state, '
      'keeps foreign files, prints the diff, and emits a JSON verdict',
      () async {
        // Owned pair: registered via the fixture, then materialize the
        // subject at the RECORDED path so BOTH owned paths exist on disk.
        await fx.registerBehavior(id: behaviorId, description: 'first');
        final subject = File(p.join(fx.root.path, 'lib', 'b_001_subject.dart'));
        await subject.parent.create(recursive: true);
        await subject.writeAsString('// owned stub\n');
        // Foreign file: on disk, NOT in the registry — reset must never
        // touch it.
        final foreign = File(
          p.join(fx.root.path, 'test', 'tdd', 'zzz_foreign_test.dart'),
        );
        await foreign.parent.create(recursive: true);
        await foreign.writeAsString('// foreign\n');
        await fx.seedRunState(states: {behaviorId: 'green'});

        final out = await runCli(['reset', feature]);

        expect(exitCode, 0, reason: out);
        // Owned files dropped.
        expect(
          File(
            p.join(fx.root.path, 'test', 'tdd', 'b_001_test.dart'),
          ).existsSync(),
          isFalse,
          reason: out,
        );
        expect(subject.existsSync(), isFalse, reason: out);
        // Registry + run-state reset.
        expect(File(registryPath()).existsSync(), isFalse, reason: out);
        expect(
          File(
            p.join(fx.root.path, 'specs', feature, 'tdd', 'run-state.json'),
          ).existsSync(),
          isFalse,
          reason: out,
        );
        // Foreign file untouched.
        expect(foreign.existsSync(), isTrue, reason: out);
        // Diff summary printed before acting.
        expect(out, contains('b_001_test.dart'), reason: out);
        // JSON verdict.
        final v = verdict(out);
        expect(v['command'], 'reset');
        expect(v['verdict'], 'reset');
        expect((v['dropped_files'] as List).length, 2, reason: out);
        expect(v['foreign_files_kept'], greaterThanOrEqualTo(1));
      },
    );

    test(
      'bug 840 RED: reset on an unknown feature refuses with exit 1',
      () async {
        final out = await runCli(['reset', 'nope-not-here']);

        expect(exitCode, 1, reason: out);
        final v = verdict(out);
        expect(v['command'], 'reset');
        expect(v['verdict'], 'refused');
      },
    );
  });

  group('zfa tdd doctor <feature>', () {
    test(
      'bug 840 RED: doctor prescribes adopt for unowned generated files',
      () async {
        await seedUnownedPair();

        final out = await runCli(['doctor', feature]);

        expect(exitCode, 1, reason: out);
        expect(out, contains('--> fix:'), reason: out);
        expect(out, contains('--adopt'), reason: out);
        final v = verdict(out);
        expect(v['command'], 'doctor');
        expect(v['prescription'], 'adopt');
      },
    );

    test(
      'bug 840 RED: doctor prescribes resume for state-vs-evidence drift',
      () async {
        // Registry + files consistent, but run-state claims green without
        // green evidence in the cycle-log (the interrupted-run drift).
        await fx.registerBehavior(id: behaviorId, description: 'first');
        final subject = File(p.join(fx.root.path, 'lib', 'b_001_subject.dart'));
        await subject.parent.create(recursive: true);
        await subject.writeAsString('// owned stub\n');
        await fx.seedRunState(states: {behaviorId: 'green'});

        final out = await runCli(['doctor', feature]);

        expect(exitCode, 1, reason: out);
        expect(out, contains('--> fix:'), reason: out);
        expect(out, contains('zfa tdd run'), reason: out);
        final v = verdict(out);
        expect(v['prescription'], 'resume');
      },
    );

    test('bug 840 RED: doctor prescribes reset when the registry records '
        'files missing from disk and nothing is resumable', () async {
      // Registry record for B-001, but BOTH files are gone; run-state
      // absent (nothing to resume).
      await fx.registerBehavior(
        id: behaviorId,
        description: 'first',
        writeTestFile: false,
      );

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('zfa tdd reset'), reason: out);
      final v = verdict(out);
      expect(v['prescription'], 'reset');
    });

    test(
      'bug 840 RED: doctor exits 0 with a deterministic healthy verdict',
      () async {
        // Consistent stores: registered pair on disk, matching state.
        await fx.registerBehavior(id: behaviorId, description: 'first');
        final subject = File(p.join(fx.root.path, 'lib', 'b_001_subject.dart'));
        await subject.parent.create(recursive: true);
        await subject.writeAsString('// owned stub\n');
        await fx.seedRedEvidence(behaviorId);
        await fx.seedGreenEvidence(behaviorId);
        await fx.seedRunState(states: {behaviorId: 'done'});

        final out1 = await runCli(['doctor', feature]);
        final out2 = await runCli(['doctor', feature]);

        expect(exitCode, 0, reason: out1);
        final v1 = verdict(out1);
        final v2 = verdict(out2);
        expect(v1['verdict'], 'healthy');
        expect(v1['prescription'], 'none');
        // Deterministic: same state, same verdict.
        expect(jsonEncode(v1), jsonEncode(v2));
      },
    );
  });
}
