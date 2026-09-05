@Tags(['slow'])
// Tests for the SubjectWriter service (spec 044-test-tdd-generation,
// T010/T011–T013).
//
// The writer emits a minimal compilable Dart subject file for a behavior.
//   - For `unit` classification: a function-level subject.
//   - For `acceptance` classification: a behavior-level subject (a fake
//     "scenario runner") that does NOT require a pre-existing
//     entity/use case/repository.
//   - The subject compiles cleanly (FR-011).
//   - The subject does not satisfy the behavior's expected observable
//     behavior (so the paired test fails for the right reason — honest red).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('subject_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('SubjectWriter', () {
    test(
      'emits a compilable Dart file for unit classification (FR-001, FR-011)',
      () async {
        final writer = SubjectWriter();
        final behavior = Behavior(
          id: 'B-003',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.unit,
          description: 'returns 42 when invoked with no args',
          sourceCriterion: 'FR-007',
          target: 'sampleSubject',
        );
        final subjectPath = p.join(tmpDir.path, 'b003_subject.dart');
        await writer.write(behavior: behavior, subjectPath: subjectPath);

        final file = File(subjectPath);
        expect(file.existsSync(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('sampleSubject'));
        expect(content, contains('library;'));

        // Compiles cleanly: `dart analyze` returns 0 errors.
        final result = await Process.run('dart', [
          'analyze',
          subjectPath,
        ], workingDirectory: tmpDir.path);
        expect(
          result.exitCode,
          0,
          reason:
              'subject must pass dart analyze with 0 errors\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'emits a compilable Dart file for acceptance classification (FR-003, FR-004)',
      () async {
        final writer = SubjectWriter();
        final behavior = Behavior(
          id: 'B-007',
          feature: '044-test-tdd-generation',
          kind: BehaviorKind.acceptance,
          description: 'the scenario runner reports the observable behavior',
          sourceCriterion: 'AC-1',
          target: 'scenarioRunner',
        );
        final subjectPath = p.join(tmpDir.path, 'b007_subject.dart');
        await writer.write(behavior: behavior, subjectPath: subjectPath);

        final file = File(subjectPath);
        expect(file.existsSync(), isTrue);
        final content = await file.readAsString();
        expect(content, contains('scenarioRunner'));
        // The acceptance subject must NOT reference any entity/use case/
        // repository — it stands alone (FR-004). Check for actual
        // entity references in non-comment code (the comment block
        // explains the constraint, so it's allowed to mention the words).
        final codeOnly = content.replaceAll(RegExp(r'//.*'), '');
        expect(codeOnly, isNot(contains('Entity ')));
        expect(codeOnly, isNot(contains('UseCase')));
        expect(codeOnly, isNot(contains('Repository')));

        // Compiles cleanly.
        final result = await Process.run('dart', [
          'analyze',
          subjectPath,
        ], workingDirectory: tmpDir.path);
        expect(
          result.exitCode,
          0,
          reason:
              'acceptance subject must pass dart analyze\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test('subject passes dart analyze with zero errors (FR-011)', () async {
      final writer = SubjectWriter();
      final behavior = Behavior(
        id: 'B-008',
        feature: '044-test-tdd-generation',
        kind: BehaviorKind.unit,
        description: 'returns 42 when invoked with no args',
        sourceCriterion: 'FR-007',
        target: 'sampleSubject',
      );
      final subjectPath = p.join(tmpDir.path, 'b008_subject.dart');
      await writer.write(behavior: behavior, subjectPath: subjectPath);

      final result = await Process.run('dart', [
        'analyze',
        subjectPath,
      ], workingDirectory: tmpDir.path);
      expect(
        result.exitCode,
        0,
        reason: 'subject must pass dart analyze cleanly',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('issue #1035 — stubs suppress the lint their id-derived snake_case '
        'name provably trips, and never emit a named library', () {
      const writer = SubjectWriter();
      for (final kind in [
        BehaviorKind.unit,
        BehaviorKind.acceptance,
        BehaviorKind.widget,
      ]) {
        final behavior = Behavior(
          id: 'A1',
          feature: '1035-lint-repro',
          kind: kind,
          description: 'the session starts.',
          sourceCriterion: 'AC-1',
          target: 'subject_a1',
        );
        final content = writer.render(behavior);
        expect(
          content,
          contains('// ignore_for_file: non_constant_identifier_names'),
          reason:
              'kind=$kind emits `subject_a1` — the provable trip is '
              'suppressed in the generated file, not renamed',
        );
        // Anonymous `library;` only — a named directive would trip
        // unnecessary_library_name.
        expect(content, contains('library;'));
        expect(
          RegExp(r'^library \S', multiLine: true).hasMatch(content),
          isFalse,
          reason: 'kind=$kind must not carry a named library directive',
        );
      }

      // The FFI harness emits camelCase contract symbols only
      // (kNativeLibrary, symbolResolved, …) — no provable trip, no
      // suppression.
      final ffi = writer.render(
        Behavior(
          id: 'A9',
          feature: '1035-lint-repro',
          kind: BehaviorKind.ffi,
          description: 'binds the native library.',
          sourceCriterion: 'AC-9',
          target: 'subject_a9',
        ),
      );
      expect(ffi, isNot(contains('ignore_for_file')));
    });
  });
}
