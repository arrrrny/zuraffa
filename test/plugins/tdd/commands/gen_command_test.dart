@Tags(['slow'])
// Tests for the GenCommand (spec 044-test-tdd-generation, Phase 5 / T018–T027).
//
// The GenCommand materializes a planned behavior into exactly one test +
// one compilable subject and persists an artifact record. These tests cover
// US1.AC1–5 and US2.AC1–3 via the public CLI surface (`zfa tdd gen`).
//
// The temp fixture root is passed via `--project`; this suite never mutates
// the process-global Directory.current.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String featureName = '044-test-tdd-generation';

  /// Build `zfa tdd gen` args with an explicit project root so the command
  /// never depends on Directory.current.
  List<String> genArgs(String id, [List<String> extra = const <String>[]]) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    id,
    ...extra,
  ];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_command_test_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpecAndTestList({
    String behaviorId = 'B-003',
    String classification = 'unit',
    String description = 'returns 42 when invoked with no args',
    String sourceCriterion = 'FR-007',
    String target = 'sampleSubject',
  }) async {
    // Write spec.md (so the registry can confirm the feature exists).
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    final specFile = File(p.join(specDir.path, 'spec.md'));
    await specFile.writeAsString('''
# Spec for gen_command_test

## Functional Requirements

- **$sourceCriterion**: $description
''');
    // Write test-list.md with the planned behavior.
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    final testListFile = File(p.join(tddDir.path, 'test-list.md'));
    await testListFile.writeAsString('''
# Test List for gen_command_test

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | $description | $sourceCriterion | $classification | PENDING | $target |
''');
  }

  group('GenCommand — happy path (US1.AC1 / FR-001, FR-005)', () {
    test(
      'happy path writes one test + one subject and exits 0 with the six required result fields',
      () async {
        await seedSpecAndTestList();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(genArgs('B-003'));
        // The command must print a structured result with all six fields.
        expect(out.toLowerCase(), contains('behavior_id: b-003'));
        expect(out, contains('source_criterion: FR-007'));
        expect(out, contains('test_path:'));
        expect(out, contains('subject_path:'));
        expect(out, contains('runnable_test_name:'));
        expect(out, contains('ownership:'));

        // Exactly one test file + one subject file was written.
        final testFiles = await _findGeneratedFiles(
          '${tmpDir.path}/test',
          '_test.dart',
        );
        final subjectFiles = await _findGeneratedFiles(
          '${tmpDir.path}/lib',
          '_subject.dart',
        );
        expect(testFiles, hasLength(1));
        expect(subjectFiles, hasLength(1));

        // Artifact registry persisted.
        final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
        expect(regFile.existsSync(), isTrue);
      },
    );
  });

  group('GenCommand — honest red (US1.AC2 / FR-010)', () {
    test(
      'the generated test fails with an assertion failure on first execution',
      () async {
        await seedSpecAndTestList();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(genArgs('B-003'));

        // Locate the generated test file.
        final testFiles = await _findGeneratedFiles(
          '${tmpDir.path}/test',
          '_test.dart',
        );
        expect(testFiles, hasLength(1));
        final testPath = testFiles.first;

        // Write a minimal pubspec.yaml so `dart test` recognizes
        // the tmpDir as a Dart project.
        await File('${tmpDir.path}/pubspec.yaml').writeAsString('''
name: gen_command_test_b003
environment:
  sdk: ^3.11.0
dependencies:
  test: ^1.25.0
''');

        // Run dart test on it.
        final result = await Process.run('dart', [
          'test',
          testPath,
        ], workingDirectory: tmpDir.path);
        expect(
          result.exitCode,
          isNot(0),
          reason: 'generated test must fail on first run',
        );
        final combined = '${result.stdout}\n${result.stderr}';
        // Failure must be an assertion failure, not a compile/load/skip.
        expect(combined.toLowerCase(), isNot(contains('error: target of uri')));
        expect(combined.toLowerCase(), isNot(contains('undefined name')));
        expect(combined.toLowerCase(), isNot(contains("isn't defined")));
        // Assertion failure or unimplemented (the stub throws
        // UnimplementedError — that's the honest red).
        expect(
          combined,
          anyOf(
            contains('Expected'),
            contains('Actual'),
            contains('UnimplementedError'),
            contains('Failed assertion'),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('GenCommand — unknown id (US1.AC3 / FR-002)', () {
    test('unknown id exits non-zero before writing any file', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      // The CliRunner throws UsageException on non-zero exits; we catch
      // the printed output.
      String output;
      try {
        output = await runner.runCapturing(genArgs('B-UNKNOWN'));
      } on UsageException catch (e) {
        output = e.message;
      }
      expect(output.toLowerCase(), contains('unknown behavior id'));
      // No files written.
      final testFiles = await _findGeneratedFiles(
        '${tmpDir.path}/test',
        '_test.dart',
      );
      expect(testFiles, isEmpty);
      final subjectFiles = await _findGeneratedFiles(
        '${tmpDir.path}/lib',
        '_subject.dart',
      );
      expect(subjectFiles, isEmpty);
      // No registry entry written.
      final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(regFile.existsSync(), isFalse);
    });
  });

  group('GenCommand — missing required fields (US1.AC4 / FR-002)', () {
    test('malformed behavior row exits non-zero pre-write', () async {
      // Write a test-list with a row missing the description column.
      final specDir = Directory(featureDir);
      await specDir.create(recursive: true);
      final tddDir = Directory(p.join(specDir.path, 'tdd'));
      await tddDir.create(recursive: true);
      await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-009 |  | FR-009 | unit | PENDING | sampleSubject |
''');
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(genArgs('B-009'));
      expect(
        output.toLowerCase(),
        anyOf(
          contains('missing'),
          contains('required field'),
          contains('description'),
        ),
      );
      // No files written.
      final testFiles = await _findGeneratedFiles(
        '${tmpDir.path}/test',
        '_test.dart',
      );
      expect(testFiles, isEmpty);
    });
  });

  group('GenCommand — acceptance classification (US1.AC5 / FR-003, FR-004)', () {
    test(
      'acceptance classification works without pre-existing entity/use case/repository',
      () async {
        await seedSpecAndTestList(
          behaviorId: 'B-010',
          classification: 'acceptance',
          description: 'the scenario runner reports the observable behavior',
          sourceCriterion: 'AC-1',
          target: 'scenarioRunner',
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(genArgs('B-010'));
        expect(out, contains('behavior_id: B-010'));

        final subjectFiles = await _findGeneratedFiles(
          '${tmpDir.path}/lib',
          '_subject.dart',
        );
        expect(subjectFiles, hasLength(1));
        final subjectContent = await File(subjectFiles.first).readAsString();
        // Subject must NOT reference any entity/use case/repository — it
        // stands alone (FR-004). Check for actual entity references in
        // non-comment code (the comment block says "does not reference
        // any entity...", which is allowed to mention the words).
        final codeOnly = subjectContent.replaceAll(RegExp(r'//.*'), '');
        expect(codeOnly, isNot(contains('Entity ')));
        expect(codeOnly, isNot(contains('UseCase')));
        expect(codeOnly, isNot(contains('Repository')));
        // Subject must compile cleanly — verify via dart analyze.
        final result = await Process.run('dart', [
          'analyze',
          subjectFiles.first,
        ], workingDirectory: tmpDir.path);
        expect(
          result.exitCode,
          0,
          reason:
              'acceptance subject must pass dart analyze\n'
              'stdout: ${result.stdout}\nstderr: ${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  group('GenCommand — idempotent repeat (US2.AC1 / FR-006)', () {
    test('repeat creates zero duplicate artifacts; ownership=reused', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));
      // Repeat.
      final out2 = await runner.runCapturing(genArgs('B-003'));
      expect(out2.toLowerCase(), contains('ownership: reused'));

      // Still exactly one test + one subject.
      final testFiles = await _findGeneratedFiles(
        '${tmpDir.path}/test',
        '_test.dart',
      );
      final subjectFiles = await _findGeneratedFiles(
        '${tmpDir.path}/lib',
        '_subject.dart',
      );
      expect(testFiles, hasLength(1));
      expect(subjectFiles, hasLength(1));
    });
  });

  group('GenCommand — stale stub after binary change (bug #683)', () {
    test(
      'reused/reused with a stub from an OLDER binary regenerates the stub',
      () async {
        await seedSpecAndTestList();
        final runner = CliRunner(exitOnCompletion: false);
        // Run 1: current binary writes stub v1 (registry + files created).
        await runner.runCapturing(genArgs('B-003'));

        final subjectPath = p.join(
          tmpDir.path,
          'lib',
          'tdd',
          'b_003_subject.dart',
        );
        final v1 = await File(subjectPath).readAsString();

        // Simulate an OLDER binary: the stub on disk was written by a
        // previous binary whose stub template differed (still an honest
        // UnimplementedError stub, but not what the CURRENT binary would
        // render). This is the post-rebuild state from the issue: the
        // binary was rebuilt with a fix, the stub predates it.
        final staleStub = v1.replaceFirst(
          '// GENERATED STUB — `zfa tdd gen B-003`',
          '// GENERATED STUB — `zfa tdd gen B-003` (older binary)',
        );
        expect(staleStub, isNot(v1), reason: 'fixture must alter the stub');
        await File(subjectPath).writeAsString(staleStub);

        // Run 2: gen must NOT return a silent reused/reused that leaves
        // the stale stub in place — it must regenerate the stub with the
        // current binary's content and print a note.
        final out2 = await runner.runCapturing(genArgs('B-003'));
        expect(out2, contains('binary updated, stub regenerated'));

        final after = await File(subjectPath).readAsString();
        expect(
          after,
          v1,
          reason: 'stub must be regenerated to the current binary content',
        );
        // The regenerated stub is still an honest stub (no implementation).
        expect(after, contains('UnimplementedError'));
      },
    );

    test('reused/reused with content identical to the current render skips '
        'silently (no note, no rewrite)', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));

      final subjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        'b_003_subject.dart',
      );
      final before = await File(subjectPath).readAsString();

      final out2 = await runner.runCapturing(genArgs('B-003'));
      expect(out2.toLowerCase(), contains('ownership: reused'));
      // No spurious regeneration when the binary has not changed.
      expect(out2, isNot(contains('binary updated, stub regenerated')));
      final after = await File(subjectPath).readAsString();
      expect(after, before);
    });

    test('a PROGRESSED subject (func-scaffolded implementation) is never '
        'clobbered by the staleness check', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));

      final subjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        'b_003_subject.dart',
      );
      // Simulate `zfa tdd func` scaffolding: UnimplementedError replaced
      // by a minimal implementation derived from the description
      // ("returns 42 when invoked with no args").
      const implemented = '''
// Scaffolded implementation.

library;

/// Subject for behavior B-003.
int sampleSubject() {
  return 42;
}
''';
      await File(subjectPath).writeAsString(implemented);

      final out2 = await runner.runCapturing(genArgs('B-003'));
      expect(out2.toLowerCase(), contains('ownership: reused'));
      expect(out2, isNot(contains('binary updated, stub regenerated')));
      // The implementation survives — regenerating it would regress
      // the behavior back to red (the exact failure mode of #683).
      expect(await File(subjectPath).readAsString(), implemented);
    });
  }, timeout: const Timeout(Duration(minutes: 3)));

  group('GenCommand — ownership conflict (US2.AC2 / FR-008)', () {
    test(
      'file exists with no registry entry → exit non-zero, file unchanged',
      () async {
        await seedSpecAndTestList();
        // Hand-write the test file before `gen` runs.
        // Determine what path gen would write to (based on convention:
        // test/tdd/<snake-id>_test.dart).
        final expectedTestPath = p.join(
          tmpDir.path,
          'test',
          'tdd',
          'b_003_test.dart',
        );
        await File(expectedTestPath).parent.create(recursive: true);
        await File(expectedTestPath).writeAsString('// user-authored');
        // Compute a content hash before.
        final bytesBefore = await File(expectedTestPath).readAsBytes();

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing(genArgs('B-003'));
        expect(
          output.toLowerCase(),
          anyOf(
            contains('ownership conflict'),
            contains('non-owned'),
            contains('refuses'),
          ),
        );
        // File is byte-for-byte unchanged.
        final bytesAfter = await File(expectedTestPath).readAsBytes();
        expect(bytesAfter, bytesBefore);
        // No registry file was created.
        final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
        expect(regFile.existsSync(), isFalse);
      },
    );

    test(
      'writer failure removes partial artifacts and records nothing',
      () async {
        await seedSpecAndTestList();
        final subjectPath = p.join(
          tmpDir.path,
          'lib',
          'tdd',
          'b_003_subject.dart',
        );
        await Directory(subjectPath).create(recursive: true);

        final runner = CliRunner(exitOnCompletion: false);
        final output = await runner.runCapturing(genArgs('B-003'));

        expect(output, contains('Error:'));
        expect(
          File(
            p.join(tmpDir.path, 'test', 'tdd', 'b_003_test.dart'),
          ).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(featureDir, 'tdd', 'artifacts.json')).existsSync(),
          isFalse,
        );
      },
    );
  });

  group('GenCommand — dry-run (US2.AC3 / FR-009)', () {
    test('--dry-run plans without writing', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('B-003', ['--dry-run']));
      expect(out.toLowerCase(), contains('ownership: planned'));
      // No files written.
      final testFiles = await _findGeneratedFiles(
        '${tmpDir.path}/test',
        '_test.dart',
      );
      expect(testFiles, isEmpty);
      final subjectFiles = await _findGeneratedFiles(
        '${tmpDir.path}/lib',
        '_subject.dart',
      );
      expect(subjectFiles, isEmpty);
      // No registry entry.
      final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(regFile.existsSync(), isFalse);
    });
  });
}

Future<List<String>> _findGeneratedFiles(String root, String suffix) async {
  final dir = Directory(root);
  if (!dir.existsSync()) return [];
  final results = <String>[];
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith(suffix)) {
      results.add(entity.path);
    }
  }
  return results;
}
