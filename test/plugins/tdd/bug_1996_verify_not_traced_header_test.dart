// Regression test for issue #1996 — `zfa tdd verify` reported EVERY
// behavior of a non-widget feature as "not traced" even though the
// generated test carries the generator's own machine-readable header
// block (`// behavior_id:` / `// source_criterion:` / `// kind:`).
//
// The finder-kind taxonomy (`// scenario-assertions:`, issue #964) is
// emitted by the WIDGET test template only — a unit/contract/acceptance
// behavior can never carry it, so every such behavior landed in the
// not-traced bucket with the message "no scenario-assertions header in
// …". The finding was unfixable in the consumer repo (generated tests
// must not be hand-edited), so the referee must accept the header block
// the generator DOES emit.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_kind_trace.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

void main() {
  group('bug #1996: the generated header block is a trace source', () {
    late Directory tmpDir;
    late String featureDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug_1996_kind_trace_');
      featureDir = '${tmpDir.path}/specs/1996-not-traced-header';
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    ArtifactRecord record({
      required String behaviorId,
      required String testPath,
      String sourceCriterion = 'FR-001',
    }) => ArtifactRecord(
      behaviorId: behaviorId,
      feature: '1996-not-traced-header',
      sourceCriterion: sourceCriterion,
      testPath: testPath,
      subjectPath: 'lib/tdd/1996-not-traced-header/${behaviorId}_subject.dart',
      runnableTestName: '$testPath::$behaviorId::works',
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
      createdAt: '2026-10-22T00:00:00Z',
    );

    Future<File> writeTest(String rel, String content) async {
      final f = File(p.join(tmpDir.path, rel));
      await f.parent.create(recursive: true);
      await f.writeAsString(content);
      return f;
    }

    /// The header block `zfa tdd gen` emits on every generated test —
    /// the unit-lane shape (no `// scenario-assertions:` header, which
    /// the widget template alone emits).
    const unitTestHeader = '''
// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
// description: the unit returns the value.
library;
''';

    test(
      'a generated unit-lane behavior is traced, not reported "not traced"',
      () async {
        final registry = ArtifactRegistry(featureDir: featureDir);
        await registry.register(
          record(
            behaviorId: 'U1',
            testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
          ),
        );
        await writeTest(
          'test/tdd/1996-not-traced-header/u1_test.dart',
          '$unitTestHeader\nvoid main() {}\n',
        );

        final result = await BehaviorKindTrace.trace(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
        );

        expect(
          result.notTraced.containsKey('U1'),
          isFalse,
          reason:
              'the generated test carries the machine-readable header block '
              '(behavior_id / source_criterion / kind) — it is traced, and '
              'the not-traced message must not demand a '
              '`// scenario-assertions:` header the unit lane never emits '
              '(issue #1996)',
        );
      },
    );

    test('the report lists the behavior as traced, not "not traced"', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U1',
          testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u1_test.dart',
        '$unitTestHeader\nvoid main() {}\n',
      );
      final subject = File(
        p.join(
          tmpDir.path,
          'lib',
          'tdd',
          '1996-not-traced-header',
          'u1_subject.dart',
        ),
      );
      await subject.create(recursive: true);
      await subject.writeAsString('library;');

      final auditor = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'All tests passed!'),
        runMutation: () async => MutationResult(
          exitCode: 0,
          killedCount: 3,
          survivedCount: 0,
          timeoutCount: 0,
          elapsed: const Duration(seconds: 1),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 3',
          stderrText: '',
        ),
      );

      final md = (await auditor.run()).toMarkdown();

      expect(md, contains('`U1`'), reason: 'the behavior is listed');
      expect(
        md,
        isNot(contains('not traced')),
        reason:
            'a behavior whose generated test carries the header block is '
            'traced — reporting it "not traced" is the defect of '
            'issue #1996',
      );
    });

    test('a test with NO machine-readable header stays not-traced and the '
        'message names the header it wants', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U9',
          testPath: 'test/tdd/1996-not-traced-header/u9_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u9_test.dart',
        'void main() {}\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(result.notTraced.containsKey('U9'), isTrue);
      final reason = result.notTraced['U9'] ?? '';
      expect(reason, contains('scenario-assertions'));
      expect(
        reason,
        contains('behavior_id'),
        reason:
            'the message names the header block it wants (the generated '
            '`// behavior_id:` / `// source_criterion:` / `// kind:` '
            'block), so the reader is never asked for a header the '
            'generator cannot emit for this lane',
      );
    });

    test(
      'the declared kind is the trace source for the non-widget lanes',
      () async {
        final registry = ArtifactRegistry(featureDir: featureDir);
        await registry.register(
          record(
            behaviorId: 'U1',
            testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
          ),
        );
        await registry.register(
          record(
            behaviorId: 'contract:A1',
            testPath: 'test/tdd/1996-not-traced-header/contract_a1_test.dart',
            sourceCriterion: 'FR-002',
          ),
        );
        await writeTest(
          'test/tdd/1996-not-traced-header/u1_test.dart',
          '$unitTestHeader\nvoid main() {}\n',
        );
        await writeTest(
          'test/tdd/1996-not-traced-header/contract_a1_test.dart',
          '// GENERATED TEST — `zfa tdd gen contract:A1` (issue #1007).\n'
              '//\n'
              '// behavior_id: contract:A1\n'
              '// source_criterion: FR-002\n'
              '// kind: contract\n'
              'library;\n',
        );

        final result = await BehaviorKindTrace.trace(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
        );

        expect(result.notTraced, isEmpty);
        expect(result.declaredKindByBehavior['U1'], 'unit');
        expect(result.declaredKindByBehavior['contract:A1'], 'contract');
        expect(
          BehaviorKindTrace.declaredKindCounts(result.declaredKindByBehavior),
          {'contract': 1, 'unit': 1},
        );
      },
    );

    test(
      'the report names the declared kind and the envelope carries it',
      () async {
        final registry = ArtifactRegistry(featureDir: featureDir);
        await registry.register(
          record(
            behaviorId: 'U1',
            testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
          ),
        );
        await writeTest(
          'test/tdd/1996-not-traced-header/u1_test.dart',
          '$unitTestHeader\nvoid main() {}\n',
        );
        final subject = File(
          p.join(
            tmpDir.path,
            'lib',
            'tdd',
            '1996-not-traced-header',
            'u1_subject.dart',
          ),
        );
        await subject.create(recursive: true);
        await subject.writeAsString('library;');

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'All tests passed!'),
          runMutation: () async => MutationResult(
            exitCode: 0,
            killedCount: 3,
            survivedCount: 0,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 1),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 3',
            stderrText: '',
          ),
        );

        final report = await auditor.run();
        final md = report.toMarkdown();

        expect(md, contains('- `U1` — unit (behavior kind)'));
        expect(md, contains('- traced by behavior kind: unit=1'));

        final details = BehaviorKindTrace.detailsObject(
          kindsByBehavior: report.behaviorKindsByBehavior,
          notTraced: report.notTracedBehaviors,
          declaredKindByBehavior: report.declaredKindByBehavior,
        );
        expect(
          (details['declared_kind_by_behavior'] as Map<String, String>)['U1'],
          'unit',
        );
      },
    );

    test('a widget-lane test stays on the taxonomy path', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'W1',
          testPath: 'test/tdd/1996-not-traced-header/w1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/w1_test.dart',
        '// GENERATED TEST — `zfa tdd gen W1` (spec 044-test-tdd-generation).\n'
            '//\n'
            '// behavior_id: W1\n'
            '// source_criterion: FR-001\n'
            '// kind: widget\n'
            '// scenario-assertions: presence("t.auth.signIn")\n'
            '// description: the sign-in button is present.\n'
            'library;\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(
        result.kindsByBehavior['W1'],
        isNotEmpty,
        reason: 'the widget lane is traced by the taxonomy',
      );
      expect(
        result.declaredKindByBehavior,
        isEmpty,
        reason:
            'the widget template emits BOTH headers, and the taxonomy is '
            'the stricter channel — a widget behavior must never leak '
            'into the declared-kind bucket (reordering the branches '
            'would silently move it there)',
      );
      expect(result.notTraced, isEmpty);
    });

    test('an unknown `// kind:` token is not a trace', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U1',
          testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u1_test.dart',
        '// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).\n'
            '//\n'
            '// behavior_id: U1\n'
            '// source_criterion: FR-001\n'
            '// kind: unti\n'
            'library;\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(
        result.notTraced.containsKey('U1'),
        isTrue,
        reason:
            'a token that is not one of the kinds the generator can emit '
            'is not a kind — a typo must never make a behavior count as '
            'TRACED with a nonsense kind',
      );
      expect(
        result.notTraced['U1'],
        contains('unknown declared kind token'),
        reason: 'the raw token is preserved, like the taxonomy channel',
      );
      expect(result.notTraced['U1'], contains('unti'));
      expect(result.declaredKindByBehavior, isEmpty);
    });

    test('a truncated header block stays not-traced', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U1',
          testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u1_test.dart',
        '// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).\n'
            '//\n'
            '// source_criterion: FR-001\n'
            '// kind: unit\n'
            'library;\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(
        result.notTraced.containsKey('U1'),
        isTrue,
        reason:
            'the `// behavior_id:` line is the only place the '
            'behavior↔file binding can be verified — a block that lost it '
            'is incomplete, and an incomplete block is an honest absence',
      );
      final reason = result.notTraced['U1'] ?? '';
      expect(
        reason,
        contains('behavior_id'),
        reason:
            'the reason names the missing header line, so the report is '
            'actionable',
      );
      expect(
        reason,
        isNot(contains('null')),
        reason:
            'a missing `// behavior_id:` line is a truncated block, not a '
            'mismatch — the reason must never read "declares behavior_id '
            'null"',
      );
      expect(result.declaredKindByBehavior, isEmpty);
    });

    test('a test file that declares another behavior id is not this '
        "behavior's test", () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U1',
          testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u1_test.dart',
        '// GENERATED TEST — `zfa tdd gen U2` (spec 044-test-tdd-generation).\n'
            '//\n'
            '// behavior_id: U2\n'
            '// source_criterion: FR-001\n'
            '// kind: unit\n'
            'library;\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(
        result.notTraced.containsKey('U1'),
        isTrue,
        reason:
            'the header block is the only place the behavior↔file binding '
            'can be verified (an artifact record carries no kind field) — a '
            'swapped or stale artifact must not be attributed to this '
            'behavior',
      );
      expect(result.notTraced['U1'], contains('behavior_id U2'));
      expect(result.declaredKindByBehavior, isEmpty);
    });

    test('a `// kind:` comment in the test body is not the header', () async {
      final registry = ArtifactRegistry(featureDir: featureDir);
      await registry.register(
        record(
          behaviorId: 'U1',
          testPath: 'test/tdd/1996-not-traced-header/u1_test.dart',
        ),
      );
      await writeTest(
        'test/tdd/1996-not-traced-header/u1_test.dart',
        'void main() {}\n'
            '// kind: unit\n',
      );

      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );

      expect(
        result.notTraced.containsKey('U1'),
        isTrue,
        reason:
            'the header block is the LEADING comment block the generator '
            'stamps — a full-line `// kind:` comment in the test body is '
            'prose, never a header',
      );
      expect(result.declaredKindByBehavior, isEmpty);
    });
  });
}
