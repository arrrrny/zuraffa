// Spec 069-corpus-economics — T002: batched gen / verify-red.
//
// The TDD loop spawns one `dart test` per behavior (verify-red runs the
// single-test template per behavior; the run driver repeats that for
// every behavior of every feature — issue #916's per-behavior spawn
// cost, asks #792/#785). This file pins the batched lineage:
//
//   1. `zfa tdd gen --all` generates EVERY pending row of the feature's
//      test list in ONE invocation (one registry load, one process).
//   2. `zfa tdd verify-red --all` certifies every generated-but-not-red
//      behavior through ONE whole-file runner invocation (the profile's
//      `file` template with every target test path) — the per-behavior
//      spawn count collapses from N to 1.
//   3. Honest failures: a refusing row stops the gen batch; a
//      green/unexecuted behavior is named and uncertified; a missing
//      `file` template misfire-stops.
//
// Fast tier: runner templates point at spy scripts emitting
// package:test-shaped transcripts — no `dart test` kernel is compiled.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-batch-gen';

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<List<Map<String, dynamic>>> registryRecords() async {
    final file = File(fx.artifactsPath);
    if (!file.existsSync()) return [];
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return [];
    final records = decoded['records'];
    if (records is! List) return [];
    return records.whereType<Map<String, dynamic>>().toList();
  }

  group('zfa tdd gen --all (T002 batch generation)', () {
    Future<void> seedThreeRows() => fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior red',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-002',
        description: 'second behavior red',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'B-003',
        description: 'third behavior red',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);

    test('generates every pending row in ONE invocation and registers '
        'every pair', () async {
      await seedThreeRows();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--all',
        '--json',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 0, reason: out);

      // Every pair exists on disk (namespaced layout, bug #827).
      for (final id in ['B-001', 'B-002', 'B-003']) {
        final snake = id.toLowerCase().replaceAll('-', '_');
        expect(
          File(
            p.join(fx.root.path, 'test', 'tdd', feature, '${snake}_test.dart'),
          ).existsSync(),
          isTrue,
          reason: 'missing test for $id\n$out',
        );
        expect(
          File(
            p.join(
              fx.root.path,
              'lib',
              'tdd',
              feature,
              '${snake}_subject.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'missing subject for $id\n$out',
        );
      }

      // The registry carries every record.
      expect(await registryRecords(), hasLength(3), reason: out);

      // The batch verdict JSON is the final stdout line.
      final lastLine = out.trim().split('\n').last;
      final verdict = jsonDecode(lastLine) as Map<String, dynamic>;
      expect(verdict['command'], 'gen');
      expect(verdict['batch'], isTrue);
      expect(verdict['behaviors'], 3);
      expect(verdict['created'], 3);
      expect(verdict['verdict'], 'created');
    });

    test(
      'a repeat --all is idempotent: every pair reused, no duplicates',
      () async {
        await seedThreeRows();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'gen',
          '--all',
          '--json',
          '--project',
          fx.root.path,
          '--feature',
          feature,
        ]);

        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--all',
          '--json',
          '--project',
          fx.root.path,
          '--feature',
          feature,
        ]);

        expect(exitCode, 0, reason: out);
        expect(await registryRecords(), hasLength(3), reason: out);
        final lastLine = out.trim().split('\n').last;
        final verdict = jsonDecode(lastLine) as Map<String, dynamic>;
        expect(verdict['behaviors'], 3);
        expect(verdict['reused'], 3);
        expect(verdict['created'], 0);
        expect(verdict['verdict'], 'reused');
      },
    );

    test('a refusing row stops the batch honestly (exit 1, the behavior '
        'named in the verdict)', () async {
      // An unowned file sits at B-002's target test path: gen refuses
      // with an FR-008 ownership conflict BEFORE writing anything —
      // the batch must stop there, not skip silently.
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior red',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior red',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-003',
          description: 'never reached',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      final unowned = p.join(
        fx.root.path,
        'test',
        'tdd',
        feature,
        'b_002_test.dart',
      );
      await File(unowned).parent.create(recursive: true);
      await File(unowned).writeAsString('// unowned file\n');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--all',
        '--json',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 1, reason: out);
      // B-001 was generated and registered before the stop; B-002
      // refused (ownership conflict); B-003 never ran.
      expect(await registryRecords(), hasLength(1), reason: out);
      expect(
        File(
          p.join(fx.root.path, 'test', 'tdd', feature, 'b_003_test.dart'),
        ).existsSync(),
        isFalse,
        reason: out,
      );
      final lastLine = out.trim().split('\n').last;
      final verdict = jsonDecode(lastLine) as Map<String, dynamic>;
      expect(verdict['verdict'], 'stopped');
      expect(verdict['stopped_at'], 'B-002');
    });

    test('--all with an explicit behavior id is a usage error', () async {
      await seedThreeRows();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        'B-001',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(out.toLowerCase(), contains('usage'));
      // A usage error prints the message and no batch verdict line —
      // nothing was generated.
      expect(out, isNot(contains('"batch": true')));
      expect(await registryRecords(), isEmpty, reason: out);
    });

    test('a per-row usage error stops the batch honestly and the verdict '
        'JSON is still the FINAL stdout line (it never escapes to '
        'CliRunner\'s exit-64 usage handler)', () async {
      await seedThreeRows();
      // --golden on unit-kind rows is a usage error raised INSIDE the
      // per-row flow — the first row (B-001) is the honest stop point.
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'gen',
        '--all',
        '--golden',
        '--json',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 1, reason: out);
      // The batch verdict JSON is the final stdout line, naming the row
      // that stopped the batch.
      final lastLine = out.trim().split('\n').last;
      final verdict = jsonDecode(lastLine) as Map<String, dynamic>;
      expect(verdict['command'], 'gen');
      expect(verdict['batch'], isTrue);
      expect(verdict['verdict'], 'stopped');
      expect(verdict['stopped_at'], 'B-001');
      expect(verdict['behaviors'], 0, reason: out);
      // Nothing was generated for any row.
      expect(await registryRecords(), isEmpty, reason: out);
      expect(
        File(
          p.join(fx.root.path, 'test', 'tdd', feature, 'b_001_test.dart'),
        ).existsSync(),
        isFalse,
        reason: out,
      );
    });
  });

  group('zfa tdd verify-red --all (T002 batched red certification)', () {
    late String fileSpy;
    late String singleSpy;

    setUp(() async {
      fileSpy = await fx.writeSpyScript(
        'file',
        output:
            '00:00 +0: loading test file\n'
            '00:00 +0 -1: first behavior red [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +0 -2: second behavior red [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +0 -2: Some tests failed.',
        exit: '1',
      );
      singleSpy = await fx.writeSpyScript(
        'single',
        output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: p.join(fx.spyDir, 'suite'),
        fileTemplate: '$fileSpy {file}',
      );
    });

    Future<void> seedTwoGenArtifacts() async {
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior red',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'second behavior red',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: 'B-001',
        description: 'first behavior red',
        writeTestFile: false,
      );
      await fx.registerBehavior(
        id: 'B-002',
        description: 'second behavior red',
        writeTestFile: false,
      );
      // The generated test files on disk (gen --all's output shape).
      for (final id in ['B-001', 'B-002']) {
        final path = fx.testPathOf(id);
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString('// generated test $id\n');
      }
    }

    test('certifies every pending red through ONE whole-file invocation '
        '(N behaviors, 1 runner spawn)', () async {
      await seedTwoGenArtifacts();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 0, reason: out);

      // The batch summary line (machine contract).
      expect(
        out,
        contains(
          'verify-red: batch=true behaviors=2 certified=2 '
          'classification=batch feature=$feature',
        ),
        reason: out,
      );

      // EXACTLY ONE runner invocation, carrying BOTH test paths.
      final invocations = fx.spyLog('file');
      expect(invocations, hasLength(1), reason: out);
      expect(invocations.single, contains(fx.testPathOf('B-001')));
      expect(invocations.single, contains(fx.testPathOf('B-002')));

      // The per-behavior single-test runner was never spawned.
      expect(fx.spyLog('single'), isEmpty, reason: out);

      // Red evidence appended for BOTH behaviors.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: B-001 (red)'));
      expect(cycleLog, contains('## Cycle: B-002 (red)'));
    });

    test('a behavior whose test PASSES in the batch is named and '
        'uncertified (exit 1) — never a fabricated red', () async {
      await seedTwoGenArtifacts();
      // The batch transcript has B-002 GREEN.
      await fx.writeSpyScript(
        'file',
        output:
            '00:00 +0: loading test file\n'
            '00:00 +0 -1: first behavior red [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +1 -1: second behavior red\n'
            '00:00 +1 -1: Some tests failed.',
        exit: '1',
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 1, reason: out);
      // B-002 named with its honest classification.
      expect(out, contains('B-002'));
      expect(out, contains('unexpected-green'), reason: out);
      expect(
        out,
        contains(
          'verify-red: batch=true behaviors=2 certified=1 '
          'classification=mixed feature=$feature',
        ),
        reason: out,
      );
      // Evidence ONLY for the certified behavior.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: B-001 (red)'));
      expect(cycleLog, isNot(contains('## Cycle: B-002 (red)')));
    });

    test('a behavior whose name is CONTAINED in a failing behavior\'s '
        'name never inherits that failure (suffix-boundary matching — '
        'no fabricated red)', () async {
      // B-001 "adds item" PASSES; B-002 "adds item to cart" FAILS with
      // an assertion. Plain names are natural language, so a substring
      // matcher would hand B-001 the other's failure segment and
      // certify it red.
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'adds item',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'B-002',
          description: 'adds item to cart',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: 'B-001',
        description: 'adds item',
        writeTestFile: false,
      );
      await fx.registerBehavior(
        id: 'B-002',
        description: 'adds item to cart',
        writeTestFile: false,
      );
      for (final id in ['B-001', 'B-002']) {
        final path = fx.testPathOf(id);
        await File(path).parent.create(recursive: true);
        await File(path).writeAsString('// generated test $id\n');
      }
      await fx.writeSpyScript(
        'file',
        output:
            '00:00 +0: loading test file\n'
            '00:00 +1: ${fx.testPathOf('B-001')}: adds item\n'
            '00:00 +0 -1: ${fx.testPathOf('B-002')}: adds item to cart [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +1 -1: Some tests failed.',
        exit: '1',
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 1, reason: out);
      // The PASSING substring behavior is honestly unexpected-green —
      // never certified from the longer failing behavior's segment.
      expect(
        out,
        contains(
          'verify-red: behavior=B-001 classification=unexpected-green '
          'certified=false',
        ),
        reason: out,
      );
      // The FAILING longer-name behavior certifies from its OWN segment.
      expect(
        out,
        contains(
          'verify-red: behavior=B-002 classification=assertion '
          'certified=true',
        ),
        reason: out,
      );
      expect(
        out,
        contains(
          'verify-red: batch=true behaviors=2 certified=1 '
          'classification=mixed feature=$feature',
        ),
        reason: out,
      );
      // Evidence ONLY for the real failure.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: B-002 (red)'));
      expect(cycleLog, isNot(contains('## Cycle: B-001 (red)')));
    });

    test('a transcript with skipped tests still parses: the ~N skipped '
        'counter does not blind the batch into runner-error', () async {
      await seedTwoGenArtifacts();
      // Real `dart test` counter order: +passed ~skipped -failed. The
      // old parser regexes had no ~N segment, so EVERY line here parsed
      // as nothing and both behaviors degraded to runner-error.
      await fx.writeSpyScript(
        'file',
        output:
            '00:00 +0: loading test file\n'
            '00:00 +0 ~1 -1: first behavior red [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +0 ~1 -2: second behavior red [E]\n'
            '  Expected: <42>\n'
            '    Actual: <13>\n'
            '00:00 +0 ~1 -2: Some tests failed.',
        exit: '1',
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'verify-red: batch=true behaviors=2 certified=2 '
          'classification=batch feature=$feature',
        ),
        reason: out,
      );
      // Both behaviors classified assertion from their own segments —
      // not the runner-error the blinded parser used to produce.
      expect(out, contains('classification=assertion'), reason: out);
      expect(out, isNot(contains('classification=runner-error')), reason: out);
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: B-001 (red)'));
      expect(cycleLog, contains('## Cycle: B-002 (red)'));
    });

    test('a missing `file` template misfire-stops before any run '
        '(honest refusal, not a silent per-behavior fallback)', () async {
      await seedTwoGenArtifacts();
      // Profile without a `file` key or `Whole file` bullet.
      final dir = Directory(p.join(fx.root.path, '.specify', 'memory'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `$singleSpy {file} {name}`

## Keys (machine-readable)

```yaml
runner: dart
single: '$singleSpy {file} {name}'
suite: 'dart test'
```
''');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 1, reason: out);
      expect(out.toLowerCase(), contains('file'), reason: out);
      // No runner was spawned and no evidence was written.
      expect(fx.spyLog('file'), isEmpty, reason: out);
      expect(fx.spyLog('single'), isEmpty, reason: out);
      expect(File(fx.cycleLogPath).existsSync(), isFalse, reason: out);
    });

    test('no pending behaviors is an honest no-op: zero spawns, '
        'behaviors=0 certified=0, exit 0', () async {
      await seedTwoGenArtifacts();
      // Both behaviors already carry red evidence.
      await fx.seedRedEvidence('B-001');
      await fx.seedRedEvidence('B-002');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--all',
        '--project',
        fx.root.path,
        '--feature',
        feature,
      ]);

      expect(exitCode, 0, reason: out);
      expect(fx.spyLog('file'), isEmpty, reason: out);
      expect(
        out,
        contains('verify-red: batch=true behaviors=0 certified=0'),
        reason: out,
      );
    });
  });
}
