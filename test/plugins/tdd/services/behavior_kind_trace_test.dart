// Tests for the verify behavior-kind trace (spec 1376-verify-kind-trace,
// issue #1376, EPIC #1133 exit criterion 3).
//
// `zfa tdd verify` must report WHAT KINDS of behavior it watched — the
// `// scenario-assertions:` header the writer emits on every generated
// test is the machine-certified source (issue #964). These tests cover
// the parser, the per-behavior trace, the report section, the stdout/
// envelope payloads, and the NOT_ASSESSED compatibility guard.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_kind_trace.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

void main() {
  group('U-1376-1: header parser', () {
    test('parses kind("literal") cells into canonical-order labels', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: presence("t.auth.signIn")',
      );
      expect(unknown, isEmpty);
      expect(kinds, ['presence']);
    });

    test('parses route-outcome, absence, and enabled-state polarity cells', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: absence("t.auth.error")',
      );
      expect(unknown, isEmpty);
      expect(kinds, ['absence']);

      final enabled = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: enabled-state("t.auth.signIn")(enabled)',
      );
      expect(enabled.$1, ['enabled-state']);
      expect(enabled.$2, isEmpty);

      final disabled = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: enabled-state("t.auth.signIn")(disabled)',
      );
      expect(disabled.$1, ['enabled-state']);
      expect(disabled.$2, isEmpty);
    });

    test('parses the bare sequence token', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: sequence, presence("t.auth.working"), '
        'route-outcome("deal_list")',
      );
      expect(unknown, isEmpty);
      expect(
        kinds,
        ['presence', 'route-outcome', 'sequence'],
        reason:
            'deduped + canonical order: presence, absence, '
            'route-outcome, enabled-state, sequence',
      );
    });

    test('dedupes repeated kinds and returns canonical order', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: route-outcome("deal_list"), '
        'presence("a"), sequence, presence("b")',
      );
      expect(unknown, isEmpty);
      expect(kinds, ['presence', 'route-outcome', 'sequence']);
    });

    test('literals containing commas survive parsing', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: presence("Hello, world")',
      );
      expect(unknown, isEmpty);
      expect(kinds, ['presence']);
    });

    test('returns empty for content without a header', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        'void main() {} // no header here',
      );
      expect(kinds, isEmpty);
      expect(unknown, isEmpty);
    });
  });

  group('U-1376-2: unknown tokens degrade to not-traced', () {
    test('an unrecognized kind cell is preserved verbatim as unknown', () {
      final (kinds, unknown) = BehaviorKindTrace.parseHeader(
        '// scenario-assertions: golden("login_view"), presence("hi")',
      );
      expect(kinds, ['presence'], reason: 'known kinds still parse');
      expect(
        unknown,
        ['golden'],
        reason:
            'raw token preserved, never '
            'inferred, never a throw',
      );
    });
  });

  group('U-1376-3: trace() over the artifact registry', () {
    late Directory tmpDir;
    late String featureDir;
    late ArtifactRegistry registry;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('behavior_kind_trace_');
      featureDir = '${tmpDir.path}/specs/1376-verify-kind-trace';
      registry = ArtifactRegistry(featureDir: featureDir);
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    ArtifactRecord sampleRecord({
      String behaviorId = 'A4',
      String testPath = 'test/tdd/004-login-ui/a4_test.dart',
    }) => ArtifactRecord(
      behaviorId: behaviorId,
      feature: '1376-verify-kind-trace',
      sourceCriterion: 'AC-4',
      testPath: testPath,
      subjectPath: 'lib/tdd/004-login-ui/a4_subject.dart',
      runnableTestName: '$testPath::$behaviorId::navigates',
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
      createdAt: '2026-09-09T00:00:00Z',
    );

    Future<File> writeTest(String rel, String content) async {
      final f = File(p.join(tmpDir.path, rel));
      await f.parent.create(recursive: true);
      await f.writeAsString(content);
      return f;
    }

    test(
      'maps behavior ids to the kinds parsed from their test files',
      () async {
        final a3 = await writeTest(
          'test/tdd/004-login-ui/a3_test.dart',
          '// scenario-assertions: presence("t.auth.signIn")\nvoid main() {}',
        );
        final a4 = await writeTest(
          'test/tdd/004-login-ui/a4_test.dart',
          '// scenario-assertions: route-outcome("deal_list")\nvoid main() {}',
        );
        await registry.register(
          sampleRecord(
            behaviorId: 'A3',
            testPath: p.relative(a3.path, from: tmpDir.path),
          ),
        );
        await registry.register(
          sampleRecord(
            behaviorId: 'A4',
            testPath: p.relative(a4.path, from: tmpDir.path),
          ),
        );

        final result = await BehaviorKindTrace.trace(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
        );
        expect(result.kindsByBehavior['A3'], ['presence']);
        expect(result.kindsByBehavior['A4'], ['route-outcome']);
        expect(result.notTraced, isEmpty);
        expect(BehaviorKindTrace.kindCounts(result.kindsByBehavior), {
          'presence': 1,
          'absence': 0,
          'route-outcome': 1,
          'enabled-state': 0,
          'sequence': 0,
        });
      },
    );

    test('a missing test file lands the behavior in not-traced', () async {
      await registry.register(
        sampleRecord(
          behaviorId: 'A5',
          testPath: 'test/tdd/004-login-ui/a5_test.dart',
        ),
      );
      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );
      expect(result.kindsByBehavior['A5'], isEmpty);
      expect(result.notTraced.containsKey('A5'), isTrue);
      expect(result.notTraced['A5'], contains('test file'));
    });

    test('a header-less test file lands the behavior in not-traced', () async {
      final a6 = await writeTest(
        'test/tdd/004-login-ui/a6_test.dart',
        'void main() {}',
      );
      await registry.register(
        sampleRecord(
          behaviorId: 'A6',
          testPath: p.relative(a6.path, from: tmpDir.path),
        ),
      );
      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );
      expect(result.kindsByBehavior['A6'], isEmpty);
      expect(result.notTraced['A6'], contains('scenario-assertions'));
    });

    test('an unknown kind token lands the behavior in not-traced with the '
        'raw token preserved', () async {
      final a7 = await writeTest(
        'test/tdd/004-login-ui/a7_test.dart',
        '// scenario-assertions: golden("login_view"), presence("hi")\nvoid main() {}',
      );
      await registry.register(
        sampleRecord(
          behaviorId: 'A7',
          testPath: p.relative(a7.path, from: tmpDir.path),
        ),
      );
      final result = await BehaviorKindTrace.trace(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
      );
      expect(result.kindsByBehavior['A7'], ['presence']);
      expect(result.notTraced['A7'], contains('golden'));
    });
  });

  group('U-1376-4: report carries the trace + markdown section', () {
    test(
      'auditor populates the trace on a full-run report and renders it',
      () async {
        final tmpDir = Directory.systemTemp.createTempSync('kind_report_');
        addTearDown(() => tmpDir.deleteSync(recursive: true));
        final featureDir = '${tmpDir.path}/specs/1376-verify-kind-trace';
        final registry = ArtifactRegistry(featureDir: featureDir);
        final a3 = File(
          p.join(tmpDir.path, 'test', 'tdd', '004-login-ui', 'a3_test.dart'),
        );
        await a3.create(recursive: true);
        await a3.writeAsString(
          '// scenario-assertions: presence("t.auth.signIn")\nvoid main() {}',
        );
        final a4 = File(
          p.join(tmpDir.path, 'test', 'tdd', '004-login-ui', 'a4_test.dart'),
        );
        await a4.create(recursive: true);
        await a4.writeAsString(
          '// scenario-assertions: route-outcome("deal_list")\nvoid main() {}',
        );
        for (final subject in ['a3', 'a4', 'a5']) {
          final subjectFile = File(
            p.join(
              tmpDir.path,
              'lib',
              'tdd',
              '004-login-ui',
              '${subject}_subject.dart',
            ),
          );
          await subjectFile.create(recursive: true);
          await subjectFile.writeAsString('library;');
        }
        await registry.register(
          ArtifactRecord(
            behaviorId: 'A3',
            feature: '1376-verify-kind-trace',
            sourceCriterion: 'AC-3',
            testPath: p.relative(a3.path, from: tmpDir.path),
            subjectPath: p.join(
              'lib',
              'tdd',
              '004-login-ui',
              'a3_subject.dart',
            ),
            runnableTestName: 'a3',
            testOwnership: Ownership.created,
            subjectOwnership: Ownership.created,
            createdAt: '2026-09-09T00:00:00Z',
          ),
        );
        final missing = File(
          p.join(tmpDir.path, 'test', 'tdd', '004-login-ui', 'a5_test.dart'),
        );
        await registry.register(
          ArtifactRecord(
            behaviorId: 'A4',
            feature: '1376-verify-kind-trace',
            sourceCriterion: 'AC-4',
            testPath: p.relative(a4.path, from: tmpDir.path),
            subjectPath: p.join(
              'lib',
              'tdd',
              '004-login-ui',
              'a4_subject.dart',
            ),
            runnableTestName: 'a4',
            testOwnership: Ownership.created,
            subjectOwnership: Ownership.created,
            createdAt: '2026-09-09T00:00:00Z',
          ),
        );
        await registry.register(
          ArtifactRecord(
            behaviorId: 'A5',
            feature: '1376-verify-kind-trace',
            sourceCriterion: 'AC-5',
            testPath: p.relative(missing.path, from: tmpDir.path),
            subjectPath: p.join(
              'lib',
              'tdd',
              '004-login-ui',
              'a5_subject.dart',
            ),
            runnableTestName: 'a5',
            testOwnership: Ownership.created,
            subjectOwnership: Ownership.created,
            createdAt: '2026-09-09T00:00:00Z',
          ),
        );

        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'All tests passed!'),
          runMutation: () async => MutationResult(
            exitCode: 0,
            killedCount: 7,
            survivedCount: 0,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 1),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 7',
            stderrText: '',
          ),
        );

        final report = await auditor.run();
        final md = report.toMarkdown();
        expect(report.behaviorKindsByBehavior['A3'], ['presence']);
        expect(report.behaviorKindsByBehavior['A4'], ['route-outcome']);
        expect(md, contains('## Behavior kinds'));
        expect(md, contains('presence: 1'));
        expect(md, contains('route-outcome: 1'));
        expect(
          md,
          contains('absence: 0'),
          reason:
              'canonical order, zero '
              'counts visible — the referee shows the whole table',
        );
        expect(
          md,
          contains('`A5`'),
          reason:
              'not-traced bucket names the '
              'behavior whose test file is missing',
        );
      },
    );
  });

  group('U-1376-5: stdout summary + envelope details payload', () {
    test('kindCountsLine renders the canonical table order', () {
      final line = BehaviorKindTrace.kindCountsLine({
        'presence': 2,
        'absence': 1,
        'route-outcome': 1,
        'enabled-state': 1,
        'sequence': 1,
      }, notTracedCount: 0);
      expect(
        line,
        'kinds: presence=2 absence=1 route-outcome=1 enabled-state=1 '
        'sequence=1 not-traced=0',
      );
    });

    test(
      'detailsObject is JSON-ready with counts, per-behavior, not-traced',
      () {
        final details = BehaviorKindTrace.detailsObject(
          kindsByBehavior: const {
            'A3': ['presence'],
            'A7': ['presence', 'route-outcome', 'sequence'],
          },
          notTraced: const {'A5': 'test file missing'},
        );
        final counts = details['counts'] as Map<String, Object?>;
        expect(counts['presence'], 2);
        expect(counts['route-outcome'], 1);
        expect(counts['absence'], 0);
        expect(details['by_behavior'], isA<Map<String, Object?>>());
        expect(
          (details['not_traced'] as Map<String, Object?>)['A5'],
          contains('missing'),
        );
      },
    );
  });

  group('U-1376-REG1: NOT_ASSESSED reports stay byte-compatible', () {
    test(
      'empty-scope report carries no kind fields and no markdown section',
      () {
        final report = MutationAuditReport(
          feature: '1376-verify-kind-trace',
          gate: MutationGateDecision.notAssessed,
          killedCount: 0,
          survivedCount: 0,
          timedOutCount: 0,
          behaviorIds: const [],
          sourceCriteriaByBehavior: const {},
          mutationWasRun: false,
          restorationVerified: true,
          restorationScope: const [],
          notAssessedReason: 'no behavior artifacts registered',
        );
        expect(report.behaviorKindsByBehavior, isEmpty);
        expect(report.notTracedBehaviors, isEmpty);
        expect(report.toMarkdown(), isNot(contains('## Behavior kinds')));
      },
    );
  });
}
