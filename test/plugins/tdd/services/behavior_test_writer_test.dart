@Tags(['slow'])
// Tests for the BehaviorTestWriter service (spec 044-test-tdd-generation,
// T006/T007–T009).
//
// The writer emits a Dart test file that:
//   - imports the paired subject file (FR-001, FR-010),
//   - asserts the behavior's `description`, not a placeholder (FR-010),
//   - carries the behavior id + source criterion in the group name + doc
//     comment, so the later `verify` report can trace outcomes (FR-018),
//   - fails with an assertion-level failure class on first execution
//     (FR-010: honest red, not skipped/pending/placeholder/compile error).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('behavior_test_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('BehaviorTestWriter', () {
    test(
      'emits a Dart test file that imports the subject (FR-001, FR-010)',
      () async {
        final writer = BehaviorTestWriter();
        final behavior = Behavior(
          id: 'B-003',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-007',
          target: 'sampleSubject',
        );
        final testPath = p.join(tmpDir.path, 'b003_test.dart');
        final subjectPath = p.join(tmpDir.path, 'b003_subject.dart');
        await writer.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        final testFile = File(testPath);
        expect(testFile.existsSync(), isTrue);
        final content = await testFile.readAsString();
        // Imports the paired subject file (relative or absolute — both ok).
        expect(content, contains("import '"));
        expect(content, contains('b003_subject.dart'));
        // Defines a test.
        expect(content, contains('void main()'));
        expect(content, contains("test("));
      },
    );

    test(
      'asserts the behavior description, not a placeholder (FR-010)',
      () async {
        final writer = BehaviorTestWriter();
        final behavior = Behavior(
          id: 'B-004',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-007',
          target: 'sampleSubject',
        );
        final testPath = p.join(tmpDir.path, 'b004_test.dart');
        final subjectPath = p.join(tmpDir.path, 'b004_subject.dart');
        await writer.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        final content = await File(testPath).readAsString();
        // The test must NOT be a no-op placeholder like
        // `expect(true, isFalse)` or `expect(true, isTrue)` or `// TODO`.
        expect(content, isNot(contains('expect(true, isFalse)')));
        expect(content, isNot(contains('expect(true, isTrue)')));
        expect(content, isNot(contains('// TODO')));
        // The behavior's observable behavior must drive the assertion.
        // The stub subject returns `null` (or throws) so the generated
        // assertion `expect(result, 42)` will fail with an assertion
        // failure on first execution (honest red).
        expect(content, contains('42'));
        expect(content, contains('on UnimplementedError catch'));
      },
    );

    test('test name is the PURE description — the behavior id is not echoed '
        '(bug #871)', () async {
      final writer = BehaviorTestWriter();
      final behavior = Behavior(
        id: 'A1',
        feature: '001-crud-e2e',
        kind: BehaviorKind.acceptance,
        description: 'the Todo repository service persists a todo item.',
        sourceCriterion: 'AC-1',
        target: 'subjectUnderTest',
      );
      final testPath = p.join(tmpDir.path, 'a1_test.dart');
      final subjectPath = p.join(tmpDir.path, 'a1_subject.dart');
      await writer.write(
        behavior: behavior,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      final content = await File(testPath).readAsString();
      // The registry's composite third segment is matched with
      // `--plain-name` against the generated test's name. gen composes
      // that segment from the description ONLY (bug #871 — the old
      // `'$id — $description'` echo double-embedded the id and made the
      // tdd planner capture the id as the entity name). The generated
      // test name must equal the pure description; the id stays in the
      // GROUP name (FR-018 traceability) and the doc comment.
      expect(
        content,
        contains("test('the Todo repository service persists a todo item."),
      );
      expect(content, isNot(contains("test('A1 — ")));
      // Traceability still holds outside the test name.
      expect(content, contains("group('A1 (AC-1)'"));
    });

    test(
      'group name carries behavior id + source criterion (FR-018)',
      () async {
        final writer = BehaviorTestWriter();
        final behavior = Behavior(
          id: 'B-005',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.unit,
          description: 'some observable behavior',
          sourceCriterion: 'FR-010',
          target: 'sampleSubject',
        );
        final testPath = p.join(tmpDir.path, 'b005_test.dart');
        final subjectPath = p.join(tmpDir.path, 'b005_subject.dart');
        await writer.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        final content = await File(testPath).readAsString();
        expect(content, contains('B-005'));
        expect(content, contains('FR-010'));
      },
    );

    test(
      'honest red on first run: failure is an assertion, not skip/compile',
      () async {
        // End-to-end: write the test file + a stub subject, then run
        // `dart test <test-path>` and confirm the runner exits non-zero
        // and the failure is classified as an assertion failure (not a
        // compile/load/skip class).
        final writer = BehaviorTestWriter();
        final behavior = Behavior(
          id: 'B-006',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-007',
          target: 'sampleSubject',
        );
        final testPath = p.join(tmpDir.path, 'b006_test.dart');
        final subjectPath = p.join(tmpDir.path, 'b006_subject.dart');
        await writer.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );

        // Write the stub subject whose error is captured as the assertion's
        // actual value.
        await File(subjectPath).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-006` (spec 044-test-tdd-generation).
// Returns null so the paired test fails with an assertion failure on
// first execution (honest red). Replace with real implementation.
library;

int sampleSubject() => throw UnimplementedError();
''');

        // Write a minimal pubspec.yaml so `dart test` recognizes the
        // tmpDir as a Dart project.
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: behavior_test_writer_test_b006
environment:
  sdk: ^3.11.0
dependencies:
  test: ^1.25.0
''');

        // Run `dart test` on the generated test.
        final result = await Process.run('dart', [
          'test',
          testPath,
        ], workingDirectory: tmpDir.path);
        // Test must fail (exit code != 0).
        expect(
          result.exitCode,
          isNot(0),
          reason: 'generated test must fail on first run',
        );
        final stdoutText = result.stdout.toString();
        final stderrText = result.stderr.toString();
        final combined = '$stdoutText\n$stderrText';

        // The failure must NOT be a compile/load error.
        expect(combined.toLowerCase(), isNot(contains('error: target of uri')));
        expect(combined.toLowerCase(), isNot(contains('undefined name')));
        expect(combined.toLowerCase(), isNot(contains("isn't defined")));
        // The failure must be an assertion failure.
        // Dart test reports assertion failures as "Expected: X  Actual: Y".
        expect(combined, allOf(contains('Expected:'), contains('Actual:')));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    for (final testCase in <({String name, String description})>[
      (
        name: 'generic acceptance behavior',
        description: 'reports the observable scenario outcome',
      ),
      (
        name: 'numeric acceptance behavior',
        description: 'returns 42 for the observable scenario',
      ),
    ]) {
      test('${testCase.name} fails through an assertion', () async {
        final behavior = Behavior(
          id: 'A-001',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.acceptance,
          description: testCase.description,
          sourceCriterion: 'FR-010',
          target: 'scenarioRunner',
        );
        final testPath = p.join(tmpDir.path, 'a001_test.dart');
        final subjectPath = p.join(tmpDir.path, 'a001_subject.dart');
        await const BehaviorTestWriter().write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        await const SubjectWriter().write(
          behavior: behavior,
          subjectPath: subjectPath,
        );
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: behavior_test_writer_acceptance_test
environment:
  sdk: ^3.11.0
dependencies:
  test: ^1.25.0
''');

        final result = await Process.run('dart', [
          'test',
          testPath,
        ], workingDirectory: tmpDir.path);
        final combined = '${result.stdout}\n${result.stderr}';

        expect(result.exitCode, isNot(0));
        expect(combined.toLowerCase(), isNot(contains('compile-time error')));
        expect(combined.toLowerCase(), isNot(contains('undefined name')));
        expect(combined, allOf(contains('Expected:'), contains('Actual:')));
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  });
}
