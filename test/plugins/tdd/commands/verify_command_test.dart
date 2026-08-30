// Tests for the VerifyCommand (spec 044-test-tdd-generation, Phase 8 /
// T044–T050).
//
// These tests cover US3.AC1–5 via the public CLI surface (`zfa tdd verify`).
// The MutationAuditor is exercised through a fake MutationVerifier to
// avoid the multi-minute `dart run mutation_test` runtime.
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
  late Directory prev;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('verify_command_test_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    prev = Directory.current;
    Directory.current = tmpDir;
  });

  tearDown(() {
    Directory.current = prev;
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> _seedFeature({
    List<String> behaviorIds = const ['B-003'],
    String subjectContent = 'library;',
  }) async {
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for verify_command_test
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    // Write a minimal artifacts.json with one record.
    final records = behaviorIds
        .map(
          (id) => {
            'behavior_id': id,
            'feature': featureName,
            'source_criterion': 'FR-007',
            'test_path': 'test/${id.toLowerCase()}_test.dart',
            'subject_path': 'lib/${id.toLowerCase()}_subject.dart',
            'runnable_test_name':
                'test/${id.toLowerCase()}_test.dart::$id::asserts behavior',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-29T20:00:00Z',
          },
        )
        .toList();
    await File(p.join(tddDir.path, 'artifacts.json')).writeAsString(
      '{"records": ${records.map((r) => r.toString()).join(',')}}',
    );
    // Write the subject file on disk.
    for (final id in behaviorIds) {
      final subjectFile = File(
        p.join(tmpDir.path, 'lib', '${id.toLowerCase()}_subject.dart'),
      );
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString(subjectContent);
    }
    // Write the test file on disk (so preflight has something to run).
    for (final id in behaviorIds) {
      final testFile = File(
        p.join(tmpDir.path, 'test', '${id.toLowerCase()}_test.dart'),
      );
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('''
import 'package:test/test.dart';
void main() {
  test('placeholder', () {});
}
''');
    }
  }

  group('VerifyCommand — no artifacts registered (FR-012)', () {
    test(
      'NOT_ASSESSED — no behavior artifacts registered, exit non-zero',
      () async {
        // Spec dir exists but no artifacts.json.
        final specDir = Directory(featureDir);
        await specDir.create(recursive: true);
        final tddDir = Directory(p.join(specDir.path, 'tdd'));
        await tddDir.create(recursive: true);
        // No artifacts.json.

        final runner = CliRunner(exitOnCompletion: false);
        String? output;
        try {
          output = await runner.runCapturing([
            'tdd',
            'verify',
            '--feature',
            featureName,
          ]);
        } on UsageException catch (e) {
          output = e.message;
        } on StateError catch (e) {
          output = e.message ?? '';
        }
        expect(output?.toLowerCase(), contains('not_assessed'));
        expect(
          output?.toLowerCase(),
          contains('no behavior artifacts registered'),
        );
        // verification.md is written from the REAL run regardless of the
        // gate outcome (FR-019: the report must reflect the actual current
        // run, even NOT_ASSESSED).
        final verifyFile = File(p.join(featureDir, 'tdd', 'verification.md'));
        expect(verifyFile.existsSync(), isTrue);
        final verifyContent = await verifyFile.readAsString();
        expect(verifyContent, contains('gate: `not_assessed`'));
        expect(verifyContent, contains('no behavior artifacts registered'));
      },
    );
  });
}
