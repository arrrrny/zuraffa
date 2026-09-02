// Bug #837 — mutation verify pipeline: preflight semantics + runnable at
// corpus scale.
//
// Test tiers: the unit groups run in the FAST tier (no subprocesses); the
// CLI group carries `slow` + `integration` (it pub-gets a temp fixture and
// runs the real mutation tool).
//
// RED evidence: on a GREEN suite `zfa tdd verify` exits 64 with the gate
// refused (the issue's canonical run reports gate=preflight_red) and
// `mutation_was_run: false` — the mutation invocation is dead code for
// every feature project because MutationVerifier demands a hand-written
// repo-root `mutation-test.xml` that nothing creates for features.
//
// Contract pinned here (remediation, minimal):
//   1. The preflight gate asserts GREEN: a green suite proceeds to a real
//      mutation verdict instead of refusing exit-64.
//   2. Mutation executes scoped to the feature's registered subjects only
//      (namespaced per #827), under the bounded wall-clock from #742.
//   3. The mutation score threshold is read from `.zfa.json`
//      (tdd.mutation.scoreThreshold); without it the strict policy holds
//      (any survivor fails).
//   4. Survived mutants → exit 1 with a per-mutant report and `--> fix:`
//      lines.
//   5. The verify artifacts bind to spec-hash (artifacts.json) +
//      subject-hash (pre-audit sha256 per subject).
library;

import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_verifier.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('unit — buildScopedMutationConfig: mutants scoped to feature subjects '
      '(bug #837, namespacing per #827)', () {
    test('emits only the feature subjects and a scope-only test command', () {
      final xml = buildScopedMutationConfig(
        subjectPaths: [
          'lib/tdd/b_001_subject.dart',
          'lib/tdd/b_002_subject.dart',
        ],
        testPaths: ['test/tdd/b_001_test.dart', 'test/tdd/b_002_test.dart'],
      );
      expect(xml, contains('<mutations version="1.0">'));
      expect(xml, contains('<file>lib/tdd/b_001_subject.dart</file>'));
      expect(xml, contains('<file>lib/tdd/b_002_subject.dart</file>'));
      // No subject outside the feature scope.
      expect(xml, isNot(contains('<file>lib/baseline.dart</file>')));
      // The mutant test command runs ONLY the scope tests.
      expect(
        xml,
        contains('dart test test/tdd/b_001_test.dart test/tdd/b_002_test.dart'),
      );
      expect(xml, contains('expected-return="0"'));
    });

    test('XML-escapes path metacharacters', () {
      final xml = buildScopedMutationConfig(
        subjectPaths: ['lib/tdd/a&b<c>.dart'],
        testPaths: ['test/tdd/a&b<c>_test.dart'],
      );
      expect(xml, contains('lib/tdd/a&amp;b&lt;c&gt;.dart'));
      expect(xml, isNot(contains('a&b<c>')));
    });
  });

  group('unit — parseMutationSurvivors: per-mutant report (bug #837)', () {
    test('parses file+line for every undetected mutant (v1.8 md format)', () {
      const report = '''
# Mutation report
| Undetected    | 3 |

## Undetected mutations in file : lib/tdd/b_001_subject.dart
Line 2:<br>
Line 7:<br>

## Undetected mutations in file : lib/tdd/b_002_subject.dart
Line 11:<br>
''';
      final survivors = parseMutationSurvivors(report);
      expect(
        survivors,
        equals([
          const MutationSurvivor(file: 'lib/tdd/b_001_subject.dart', line: 2),
          const MutationSurvivor(file: 'lib/tdd/b_001_subject.dart', line: 7),
          const MutationSurvivor(file: 'lib/tdd/b_002_subject.dart', line: 11),
        ]),
      );
    });

    test('empty undetected section → no survivors', () {
      const report = '''
| Undetected    | 0 |

## Undetected mutations in file : lib/tdd/b_001_subject.dart
''';
      expect(parseMutationSurvivors(report), isEmpty);
    });
  });

  group('unit — threshold gate from .zfa.json (bug #837)', () {
    late Directory tmpDir;
    late String featureDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug837_threshold_');
      featureDir = p.join(tmpDir.path, 'specs', '090-bug-837');
      Directory(featureDir).createSync(recursive: true);
      File(p.join(tmpDir.path, 'lib', 'tdd', 'b_001_subject.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('int add(int a, int b) => a + b;\n');
      File(p.join(featureDir, 'tdd', 'artifacts.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'feature': '090-bug-837',
            'records': [
              {
                'behavior_id': 'B-001',
                'feature': '090-bug-837',
                'source_criterion': 'FR-001',
                'test_path': 'test/tdd/b_001_test.dart',
                'subject_path': 'lib/tdd/b_001_subject.dart',
                'runnable_test_name': 'x::B-001::y',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-02T00:00:00.000Z',
              },
            ],
          }),
        );
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    MutationAuditor auditor({double? threshold}) => MutationAuditor(
      featureDir: featureDir,
      workingDirectory: tmpDir.path,
      scoreThreshold: threshold,
      runPreflight: (_) async => PreflightResult.green(exitCode: 0, output: ''),
      runMutation: () async => MutationResult(
        exitCode: 1,
        killedCount: 9,
        survivedCount: 1,
        timeoutCount: 0,
        elapsed: const Duration(seconds: 1),
        reportPath: '/tmp/fake-report.md',
        stdoutText: 'Killed 9, survived 1',
        stderrText: '',
        survivors: const [
          MutationSurvivor(file: 'lib/tdd/b_001_subject.dart', line: 1),
        ],
      ),
    );

    test(
      'no threshold → strict policy: any survivor fails (existing)',
      () async {
        final report = await auditor().run();
        expect(report.gate, MutationGateDecision.failSurvived);
      },
    );

    test('score >= threshold → pass even with survivors', () async {
      // 9/10 = 0.9 >= 0.8.
      final report = await auditor(threshold: 0.8).run();
      expect(report.gate, MutationGateDecision.pass);
      expect(report.mutationScore, closeTo(0.9, 1e-9));
    });

    test('score exactly at the threshold passes (boundary pinned)', () async {
      // 9/10 = 0.9 == 0.9 — the >= boundary itself, so a `>=` → `>` mutant
      // cannot survive (bug #837 audit finding F1).
      final report = await auditor(threshold: 0.9).run();
      expect(report.gate, MutationGateDecision.pass);
    });

    test('score < threshold → fail_survived', () async {
      // 9/10 = 0.9 < 0.95.
      final report = await auditor(threshold: 0.95).run();
      expect(report.gate, MutationGateDecision.failSurvived);
    });

    test('timed-out mutants fail regardless of the threshold', () async {
      final auditorWithTimeout = MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        scoreThreshold: 0.0,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: ''),
        runMutation: () async => MutationResult(
          exitCode: 1,
          killedCount: 9,
          survivedCount: 0,
          timeoutCount: 1,
          elapsed: const Duration(seconds: 1),
          reportPath: '/tmp/fake-report.md',
          stdoutText: 'Killed 9, timeout 1',
          stderrText: '',
        ),
      );
      final report = await auditorWithTimeout.run();
      expect(report.gate, MutationGateDecision.failTimeout);
    });
  });

  group('unit — evidence binding: spec-hash + subject-hash (bug #837)', () {
    late Directory tmpDir;
    late String featureDir;
    late String subjectAbs;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug837_binding_');
      featureDir = p.join(tmpDir.path, 'specs', '090-bug-837');
      subjectAbs = p.join(tmpDir.path, 'lib', 'tdd', 'b_001_subject.dart');
      Directory(p.dirname(subjectAbs)).createSync(recursive: true);
      File(subjectAbs).writeAsStringSync('int add(int a, int b) => a + b;\n');
      File(p.join(featureDir, 'tdd', 'artifacts.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'feature': '090-bug-837',
            'records': [
              {
                'behavior_id': 'B-001',
                'feature': '090-bug-837',
                'source_criterion': 'FR-001',
                'test_path': 'test/tdd/b_001_test.dart',
                'subject_path': 'lib/tdd/b_001_subject.dart',
                'runnable_test_name': 'x::B-001::y',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-02T00:00:00.000Z',
              },
            ],
          }),
        );
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test(
      'report binds spec_hash + per-subject sha256 and renders them',
      () async {
        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: ''),
          runMutation: () async => MutationResult(
            exitCode: 0,
            killedCount: 2,
            survivedCount: 0,
            timeoutCount: 0,
            elapsed: const Duration(seconds: 1),
            reportPath: '/tmp/fake-report.md',
            stdoutText: 'Killed 2',
            stderrText: '',
          ),
        );
        final report = await auditor.run();

        final specHash = sha256
            .convert(
              File(
                p.join(featureDir, 'tdd', 'artifacts.json'),
              ).readAsBytesSync(),
            )
            .toString();
        final subjectHash = sha256
            .convert(File(subjectAbs).readAsBytesSync())
            .toString();

        expect(report.specHash, specHash);
        expect(report.subjectHashes[subjectAbs], subjectHash);

        final md = report.toMarkdown();
        expect(md, contains('spec_hash: $specHash'));
        expect(md, contains('subject_hash:'));
        expect(md, contains(subjectHash));
      },
    );
  });

  group('CLI — zfa tdd verify on a GREEN suite (bug #837)', () {
    late TddFixture fx;
    late String subjectAbs;
    late String testAbs;

    Future<String> runCli(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        ...args,
        '--project',
        fx.root.path,
        '--timeout',
        '2',
      ]);
    }

    /// A real, pub-resolved fixture project: the registered scope pair
    /// (subject + test) plus the mutation_test dev dependency, exactly the
    /// state `zfa tdd init` leaves behind (bug #755 pins ^1.8.0).
    Future<void> seedResolvedGreenFixture({
      required String subjectContent,
      required String testContent,
    }) async {
      // The registry record (registerBehavior) points at lib/ + test/ —
      // write the scope pair exactly there so the audit mutates real,
      // existing subjects.
      subjectAbs = p.join(fx.root.path, 'lib', 'b_001_subject.dart');
      testAbs = p.join(fx.root.path, 'test', 'b_001_test.dart');
      File(subjectAbs)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(subjectContent);
      File(testAbs)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(testContent);
      await fx.registerBehavior(
        id: 'B-001',
        description: 'green scope pair for verify',
        sourceCriterion: 'FR-001',
        testContent: testContent,
        writeTestFile: false,
      );
      // Add the mutation tool the same way `zfa tdd init` does (bug #755).
      File(p.join(fx.root.path, 'pubspec.yaml')).writeAsStringSync('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
  mutation_test: ^1.8.0
''');
      final pubGet = await Process.run('dart', [
        'pub',
        'get',
      ], workingDirectory: fx.root.path);
      expect(
        pubGet.exitCode,
        0,
        reason: 'fixture pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
      );
    }

    setUp(() async {
      exitCode = 0;
      fx = await TddFixture.create(featureName: '090-bug-837');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('C1: green suite → gate=pass, mutation actually runs (was_run true), '
        'exit 0 — the verify step is usable (bug #837)', () async {
      await seedResolvedGreenFixture(
        subjectContent: 'int add(int a, int b) => a + b;\n',
        testContent: '''
import 'package:test/test.dart';
import 'package:tdd_fixture/b_001_subject.dart' as s;

void main() {
  test('B-001 — green scope pair for verify', () {
    expect(s.add(2, 3), 5);
  });
}
''',
      );

      final out = await runCli(['verify', '--feature', '090-bug-837']);

      expect(out, contains('mutation: gate=pass'));
      expect(out, contains('mutation_was_run=true'));
      expect(out, isNot(contains('gate=preflight_red')));
      expect(exitCode, 0, reason: 'a green suite must pass the gate');
      final md = File(
        p.join(fx.featureDir, 'tdd', 'verification.md'),
      ).readAsStringSync();
      expect(md, contains('gate: `pass`'));
      expect(md, contains('mutation_was_run: true'));
      expect(md, contains('spec_hash:'));
      expect(md, contains('subject_hash:'));
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('C2: survived mutants → exit 1 (not 64) with per-mutant report and '
        '--> fix: lines (bug #837)', () async {
      await seedResolvedGreenFixture(
        // Two mutants (+ → -, - → +) that the weak test does NOT kill.
        subjectContent: '''
int add(int a, int b) => a + b;

int sub(int a, int b) => a - b;
''',
        testContent: '''
import 'package:test/test.dart';
import 'package:tdd_fixture/b_001_subject.dart' as s;

void main() {
  test('B-001 — weak scope test', () {
    expect(s.add(0, 0), 0);
  });
}
''',
      );

      final out = await runCli(['verify', '--feature', '090-bug-837']);

      expect(out, contains('mutation: gate=fail_survived'));
      expect(out, contains('mutation_was_run=true'));
      expect(out, contains('--> fix:'));
      // Per-mutant lines cite file:line.
      expect(out, contains('b_001_subject.dart:'));
      // Exit 1 (quality failure), NOT the 64 usage class.
      expect(exitCode, 1, reason: 'survivors must exit 1');
      expect(out, isNot(contains('❌ mutation audit gate')));
      final md = File(
        p.join(fx.featureDir, 'tdd', 'verification.md'),
      ).readAsStringSync();
      expect(md, contains('gate: `fail_survived`'));
      expect(md, contains('## Survived mutants'));
      expect(md, contains('--> fix:'));
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('C3: an honest red suite is still refused (preflight_red, 64 class) '
        '— the fixed gate keeps the honest-red semantics (bug #837)', () async {
      // The registered scope test is red: preflight must refuse before
      // any mutation runs.
      await seedResolvedGreenFixture(
        subjectContent: 'int add(int a, int b) => a + b;\n',
        testContent: '''
import 'package:test/test.dart';

void main() {
  test('B-001 — red scope test', () {
    expect(1, equals(2));
  });
}
''',
      );

      final out = await runCli(['verify', '--feature', '090-bug-837']);

      expect(out, contains('❌ mutation audit gate: preflight_red'));
      expect(out, contains('mutation_was_run=false'));
      expect(
        exitCode,
        isNot(1),
        reason: 'preflight refusal stays in the 64 usage class',
      );
      final md = File(
        p.join(fx.featureDir, 'tdd', 'verification.md'),
      ).readAsStringSync();
      expect(md, contains('gate: `preflight_red`'));
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('C4: the score threshold from .zfa.json governs the gate '
        '(tdd.mutation.scoreThreshold) (bug #837)', () async {
      await seedResolvedGreenFixture(
        subjectContent: '''
int add(int a, int b) => a + b;

int sub(int a, int b) => a - b;
''',
        testContent: '''
import 'package:test/test.dart';
import 'package:tdd_fixture/b_001_subject.dart' as s;

void main() {
  test('B-001 — weak scope test', () {
    expect(s.add(0, 0), 0);
  });
}
''',
      );
      // threshold 0.0: score (0/2) >= 0.0 → survivors no longer fail.
      File(p.join(fx.root.path, '.zfa.json')).writeAsStringSync(
        jsonEncode({
          'tdd': {
            'mutation': {'scoreThreshold': 0.0},
          },
        }),
      );

      final out = await runCli(['verify', '--feature', '090-bug-837']);

      expect(out, contains('mutation: gate=pass'));
      expect(out, contains('mutation_was_run=true'));
      expect(exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 4)));
  }, tags: ['slow', 'integration']);
}
