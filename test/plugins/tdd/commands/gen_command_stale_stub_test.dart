// Tests for bug #683 — `zfa tdd gen` skips regenerating a stub when the
// zfa binary has been rebuilt with a fix (ownership "reused/reused").
//
// The ownership contract (spec 044) ties stub content to the generating
// binary, but the registry never recorded WHICH binary wrote the artifacts.
// After a binary rebuild that changes generated output, a resumed `gen`
// returned reused/reused, left the stale stub in place, and `make`
// regressed against it.
//
// Fix contract (Option B — lenient, guarded by binary freshness):
//   - reused/reused + binary changed since the record was written + on-disk
//     content differs from what the CURRENT binary renders → regenerate and
//     print a "binary updated ... stub regenerated" note;
//   - reused/reused + binary changed + content identical → skip silently
//     (no spurious regeneration);
//   - reused/reused + binary unchanged → never touch the files (protects a
//     subject that `make` already implemented);
//   - `--force` regenerates regardless of binary state.
//
// The fixtures simulate a binary rebuild by rewriting the persisted
// `binary_mtime` in artifacts.json (what a real rebuild changes) and by
// editing the generated files (what an older binary's different template
// leaves on disk).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String subjectPath;
  late String testPath;
  late String registryPath;
  const featureName = '044-test-tdd-generation';

  List<String> genArgs(String id, [List<String> extra = const <String>[]]) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    id,
    ...extra,
  ];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_stale_stub_test_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    subjectPath = p.join(tmpDir.path, 'lib', 'tdd', 'b_003_subject.dart');
    testPath = p.join(tmpDir.path, 'test', 'tdd', 'b_003_test.dart');
    registryPath = p.join(featureDir, 'tdd', 'artifacts.json');
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
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for gen_stale_stub_test

## Functional Requirements

- **$sourceCriterion**: $description
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for gen_stale_stub_test

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | $description | $sourceCriterion | $classification | PENDING | $target |
''');
  }

  /// Rewrite the persisted `binary_mtime` — simulates the disk state after
  /// the zfa binary was rebuilt since the artifacts were generated.
  Future<void> setRecordBinaryMtime(String mtime) async {
    final file = File(registryPath);
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final records = (raw['records'] as List).toList();
    records[0] = {
      ...(records.first as Map<String, dynamic>),
      'binary_mtime': mtime,
    };
    await file.writeAsString(jsonEncode({...raw, 'records': records}));
  }

  Future<String?> recordBinaryMtime() async {
    final file = File(registryPath);
    if (!file.existsSync()) return null;
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final records = (raw['records'] as List?) ?? const [];
    if (records.isEmpty) return null;
    return (records.first as Map<String, dynamic>)['binary_mtime'] as String?;
  }

  Future<void> markStale() async {
    // Append a marker the current binary would never render — the on-disk
    // content a STALE (older-binary) stub leaves behind.
    final subject = File(subjectPath);
    await subject.writeAsString(
      '${await subject.readAsString()}\n'
      '// STALE-STUB-MARKER v1\n',
    );
    final test = File(testPath);
    await test.writeAsString(
      '${await test.readAsString()}\n'
      '// STALE-TEST-MARKER v1\n',
    );
  }

  group('GenCommand — binary-change detection (bug #683)', () {
    test('U1: regenerates a stale stub with a note when the binary changed '
        'since gen (reused/reused ownership)', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));
      expect(File(subjectPath).existsSync(), isTrue);

      // Simulate: binary rebuilt with a fix that changes stub output.
      await setRecordBinaryMtime('2000-01-01T00:00:00.000Z');
      await markStale();

      final out = await runner.runCapturing(genArgs('B-003'));
      expect(out, contains('stub regenerated'));
      expect(out, contains('ownership: created'));

      // The stale markers are gone — files were regenerated.
      expect(
        File(subjectPath).readAsStringSync(),
        isNot(contains('STALE-STUB-MARKER')),
      );
      expect(
        File(testPath).readAsStringSync(),
        isNot(contains('STALE-TEST-MARKER')),
      );

      // The registry now records the NEW binary generation, so the next
      // gen is a silent reuse again (idempotency survives regeneration).
      final mtime = await recordBinaryMtime();
      expect(mtime, isNot('2000-01-01T00:00:00.000Z'));
    });

    test('U2: repeat gen with an unchanged binary stays a silent reuse '
        '(no spurious regeneration)', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));
      final out2 = await runner.runCapturing(genArgs('B-003'));
      expect(out2, contains('ownership: reused'));
      expect(out2, isNot(contains('regenerated')));
    });

    test('U3: binary changed but content is already current → skip silently '
        '(Option B: identical content never regenerates)', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));

      final subjectBefore = await File(subjectPath).readAsString();
      await setRecordBinaryMtime('2000-01-01T00:00:00.000Z');

      final out = await runner.runCapturing(genArgs('B-003'));
      expect(out, contains('ownership: reused'));
      expect(out, isNot(contains('regenerated')));
      expect(await File(subjectPath).readAsString(), subjectBefore);
    });

    test('U4: binary unchanged → never touches a subject the user already '
        'implemented (no implementation wipe)', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));

      // The user (via make / by hand) implemented the subject.
      const implemented =
          'int sampleSubject() => 42;\n'
          '// USER IMPLEMENTATION\n';
      await File(subjectPath).writeAsString(implemented);

      final out = await runner.runCapturing(genArgs('B-003'));
      expect(out, contains('ownership: reused'));
      expect(out, isNot(contains('regenerated')));
      expect(await File(subjectPath).readAsString(), implemented);
    });

    test('U5: --force regenerates even when the binary is unchanged', () async {
      await seedSpecAndTestList();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('B-003'));
      await markStale();

      final out = await runner.runCapturing(genArgs('B-003', ['--force']));
      expect(out, contains('stub regenerated'));
      expect(
        File(subjectPath).readAsStringSync(),
        isNot(contains('STALE-STUB-MARKER')),
      );
      expect(
        File(testPath).readAsStringSync(),
        isNot(contains('STALE-TEST-MARKER')),
      );
    });

    test(
      'U6: the gen after a regeneration is a silent reuse (idempotent)',
      () async {
        await seedSpecAndTestList();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(genArgs('B-003'));
        await setRecordBinaryMtime('2000-01-01T00:00:00.000Z');
        await markStale();
        await runner.runCapturing(genArgs('B-003')); // regeneration

        final out3 = await runner.runCapturing(genArgs('B-003'));
        expect(out3, contains('ownership: reused'));
        expect(out3, isNot(contains('regenerated')));
      },
    );
  });
}
