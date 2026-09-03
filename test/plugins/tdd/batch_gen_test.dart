/// Spec 069-corpus-economics, T002 — batched gen/verify-red (RED first).
///
/// `zfa tdd gen --all` materializes every planned-but-unregistered
/// behavior of a feature in ONE invocation; `zfa tdd verify-red --all`
/// certifies the honest red of every gen'd-but-uncertified behavior
/// through ONE `dart test` spawn (the suite template + the batch's
/// test paths) instead of one spawn per behavior (spec 069 FR-008,
/// issues #792/#785 — the per-PR corpus lane's spawn economics).
@Tags(['slow'])
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import 'helpers/tdd_fixture.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late TddFixture fx;
  const feature = '069-corpus-economics';

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'B 001 returns 42',
        traces: 'FR-008',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'C-002',
        description: 'C 002 returns 42',
        traces: 'FR-008',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'D-003',
        description: 'D 003 returns 42',
        traces: 'FR-008',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// The bug #827 namespaced artifact paths gen writes for [id].
  String namespacedTestPath(String id) => p.join(
    fx.root.path,
    'test',
    'tdd',
    feature,
    '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
  );

  String namespacedSubjectPath(String id) => p.join(
    fx.root.path,
    'lib',
    'tdd',
    feature,
    '${id.toLowerCase().replaceAll('-', '_')}_subject.dart',
  );

  Future<String> genAll() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'gen',
      '--all',
      '--feature',
      feature,
      '--project',
      fx.root.path,
    ]);
  }

  group('T002.1 zfa tdd gen --all (batch generation)', () {
    test('generates every planned behavior in ONE invocation', () async {
      final out = await genAll();
      expect(exitCode, 0, reason: out);
      expect(out, contains('gen: batch behaviors=3 generated=3'), reason: out);

      // All 3 pairs materialized on disk (bug #827 namespaced layout).
      for (final id in ['B-001', 'C-002', 'D-003']) {
        expect(
          File(namespacedTestPath(id)).existsSync(),
          isTrue,
          reason: 'missing test for $id',
        );
        expect(
          File(namespacedSubjectPath(id)).existsSync(),
          isTrue,
          reason: 'missing subject for $id',
        );
      }

      // The registry carries all 3 records.
      final registry = File(fx.artifactsPath).readAsStringSync();
      for (final id in ['B-001', 'C-002', 'D-003']) {
        expect(registry, contains(id), reason: registry);
        expect(
          registry,
          contains(
            p.posix.join(
              'test',
              'tdd',
              feature,
              '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
            ),
          ),
          reason: registry,
        );
      }
    });

    test(
      'is idempotent: already-registered behaviors are skipped, not re-written',
      () async {
        await genAll();
        // Mutate one generated subject to prove batch re-runs never
        // clobber progressed artifacts.
        final progressed = File(namespacedSubjectPath('C-002'));
        await progressed.writeAsString('// progressed by make\n');

        final out = await genAll();
        expect(exitCode, 0, reason: out);
        expect(
          out,
          contains('gen: batch behaviors=3 generated=0'),
          reason: out,
        );
        expect(out, contains('registered=3'), reason: out);

        // The progressed subject was NOT clobbered.
        expect(
          await progressed.readAsString(),
          contains('// progressed by make'),
        );
      },
    );

    test(
      'with no positional id and no --all stays a usage error (contract unchanged)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--project',
          fx.root.path,
        ]);
        expect(out, contains('Behavior id is required'), reason: out);
        expect(out, contains('Usage:'), reason: out);
      },
    );
  });

  group('T002.2 zfa tdd verify-red --all (batched red verification)', () {
    setUp(() async {
      await genAll();
    });

    test(
      'certifies every honest red through ONE suite spawn (fewer spawns)',
      () async {
        // The suite spy emits a multi-file failing transcript whose
        // paths match the batch's relative test paths (the
        // namespaced layout written by gen --all).
        String rel(String id) => p.posix.join(
          'test',
          'tdd',
          feature,
          '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
        );
        String descOf(String id) => switch (id) {
          'B-001' => 'B 001 returns 42',
          'C-002' => 'C 002 returns 42',
          _ => 'D 003 returns 42',
        };
        final transcript = [
          for (final id in ['B-001', 'C-002', 'D-003']) ...[
            '00:00 +0: ${rel(id)}: ${descOf(id)}',
            '00:00 +0 -1: ${rel(id)}: ${descOf(id)} [E]',
            '  Expected: <2>',
            '    Actual: <1>',
          ],
          '00:00 +0 -3: Some tests failed.',
        ].join('\n');
        final suiteSpy = await fx.writeSpyScript(
          'suite',
          output: transcript,
          exit: '1',
        );
        final singleSpy = await fx.writeSpyScript(
          'single',
          output:
              '00:00 +0 -1: x [E]\n  Expected: <2>\n    Actual: <1>\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        );
        await fx.rewriteProfile(
          singleTemplate: singleSpy,
          suiteTemplate: suiteSpy,
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--all',
          '--feature',
          feature,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: out);

        // ONE suite spawn for the whole batch — the per-behavior spawn
        // economics spec 069 requires (issues #792/#785).
        final log = fx.spyLog('suite');
        expect(log.length, 1, reason: log.toString());
        expect(log.single, contains(rel('B-001')), reason: log.single);
        expect(log.single, contains(rel('C-002')), reason: log.single);
        expect(log.single, contains(rel('D-003')), reason: log.single);

        // The batch machine line is the final stdout line.
        expect(
          out.trim().split('\n').last,
          'verify-red: batch behaviors=3 certified=3 spawns=1 '
          'feature=$feature',
          reason: out,
        );

        // Red evidence appended for every behavior.
        final cycle = await File(fx.cycleLogPath).readAsString();
        for (final id in ['B-001', 'C-002', 'D-003']) {
          expect(cycle, contains('- behavior: $id'), reason: cycle);
        }
      },
    );

    test(
      'the per-behavior path spawns once per behavior — the batch cuts the spawn count',
      () async {
        final singleSpy = await fx.writeSpyScript(
          'single',
          output:
              '00:00 +0 -1: x [E]\n  Expected: <2>\n    Actual: <1>\n'
              '00:00 +0 -1: Some tests failed.',
          exit: '1',
        );
        await fx.rewriteProfile(
          singleTemplate: singleSpy,
          suiteTemplate: 'dart test',
        );
        final runner = CliRunner(exitOnCompletion: false);
        for (final id in ['B-001', 'C-002', 'D-003']) {
          await runner.runCapturing([
            'tdd',
            'verify-red',
            id,
            '--feature',
            feature,
            '--project',
            fx.root.path,
          ]);
        }
        // Three separate invocations = three single-test spawns.
        expect(fx.spyLog('single').length, 3);
      },
    );

    test(
      'honest batch: a passing behavior is NOT certified and fails the batch',
      () async {
        String rel(String id) => p.posix.join(
          'test',
          'tdd',
          feature,
          '${id.toLowerCase().replaceAll('-', '_')}_test.dart',
        );
        // B and C fail with assertions; D PASSES (unexpected green).
        final transcript = [
          '00:00 +0: ${rel('B-001')}: B 001 returns 42',
          '00:00 +0 -1: ${rel('B-001')}: B 001 returns 42 [E]',
          '  Expected: <2>',
          '    Actual: <1>',
          '00:00 +0: ${rel('C-002')}: C 002 returns 42',
          '00:00 +0 -1: ${rel('C-002')}: C 002 returns 42 [E]',
          '  Expected: <2>',
          '    Actual: <1>',
          '00:00 +1: ${rel('D-003')}: D 003 returns 42',
          '00:00 +2 -2: Some tests failed.',
        ].join('\n');
        final suiteSpy = await fx.writeSpyScript(
          'suite',
          output: transcript,
          exit: '1',
        );
        await fx.rewriteProfile(
          singleTemplate: 'dart test {file} --plain-name "{name}"',
          suiteTemplate: suiteSpy,
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--all',
          '--feature',
          feature,
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 1, reason: out);
        expect(
          out,
          contains('verify-red: batch behaviors=3 certified=2 spawns=1'),
          reason: out,
        );
        // D's rejection is named.
        expect(out, contains('unexpected-green'), reason: out);
        expect(out, contains('D-003'), reason: out);

        // Evidence for B and C only — D is never silently certified.
        final cycle = await File(fx.cycleLogPath).readAsString();
        expect(cycle, contains('- behavior: B-001'), reason: cycle);
        expect(cycle, contains('- behavior: C-002'), reason: cycle);
        expect(cycle, isNot(contains('- behavior: D-003')), reason: cycle);
      },
    );
  });
}
