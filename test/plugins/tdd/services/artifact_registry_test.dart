// Tests for the ArtifactRegistry service (spec 044-test-tdd-generation,
// T014/T015–T017/T019).
//
// The registry persists behavior id → {test, subject, runnable test name,
// ownership, created_at} to `specs/<feature>/tdd/artifacts.json` and is
// consumed by `verify` to derive mutation scope. These tests cover the
// unit-level behaviors: append, idempotent reuse, ownership conflict stop,
// dry-run no-write, and read-back.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/artifact_registry.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late ArtifactRegistry registry;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('artifact_registry_test_');
    featureDir = '${tmpDir.path}/specs/044-test-tdd-generation';
    registry = ArtifactRegistry(featureDir: featureDir);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ArtifactRecord sampleRecord({
    String behaviorId = 'B-003',
    String sourceCriterion = 'FR-007',
    Ownership testOwnership = Ownership.created,
    Ownership subjectOwnership = Ownership.created,
  }) => ArtifactRecord(
    behaviorId: behaviorId,
    feature: '044-test-tdd-generation',
    sourceCriterion: sourceCriterion,
    testPath: '$featureDir/tdd/b003_test.dart',
    subjectPath: '$featureDir/tdd/b003_subject.dart',
    runnableTestName: '$featureDir/tdd/b003_test.dart::B-003::asserts behavior',
    testOwnership: testOwnership,
    subjectOwnership: subjectOwnership,
    createdAt: '2026-08-29T20:00:00Z',
  );

  group('ArtifactRegistry — append on first gen (FR-007)', () {
    test('appends a record on first gen for a behavior', () async {
      final record = sampleRecord();
      final result = await registry.register(record);
      expect(result.testOwnership, Ownership.created);
      expect(result.subjectOwnership, Ownership.created);

      final file = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(file.existsSync(), isTrue);
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final records = (raw['records'] as List).cast<Map<String, dynamic>>();
      expect(records, hasLength(1));
      expect(records.first['behavior_id'], 'B-003');
      expect(records.first['source_criterion'], 'FR-007');
    });
  });

  group('ArtifactRegistry — idempotent repeat (FR-006)', () {
    test(
      'returns reused on matching idempotent repeat; writes no new record',
      () async {
        final record = sampleRecord();
        // First write.
        await registry.register(record);
        await File(record.testPath).create(recursive: true);
        await File(record.subjectPath).create(recursive: true);
        // Repeat: same behavior, same paths — no new file write expected.
        final result = await registry.register(record);
        expect(result.testOwnership, Ownership.reused);
        expect(result.subjectOwnership, Ownership.reused);

        // Registry file still contains exactly one record.
        final file = File(p.join(featureDir, 'tdd', 'artifacts.json'));
        final raw =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final records = (raw['records'] as List).cast<Map<String, dynamic>>();
        expect(records, hasLength(1));
      },
    );

    test('idempotent repeat with files on disk returns reused', () async {
      // Simulate a prior `gen` run that wrote the files AND recorded
      // an entry in the registry. The repeat call must return reused
      // without modifying either the files or the registry.
      final record = sampleRecord();
      // Pre-create the files.
      final testFile = File(record.testPath);
      final subjectFile = File(record.subjectPath);
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('// prior test content');
      await subjectFile.writeAsString('// prior subject content');
      // Pre-populate the registry file directly (simulating a prior gen
      // that wrote both the files and the registry entry).
      final regFile = File(registry.registryPath);
      await regFile.parent.create(recursive: true);
      await regFile.writeAsString(
        jsonEncode({
          'feature': '044-test-tdd-generation',
          'records': [record.toJson()],
        }),
      );
      // Sanity: registry has the record.
      expect((await registry.loadAll()), hasLength(1));
      // Now repeat.
      final result = await registry.register(record);
      expect(result.testOwnership, Ownership.reused);
      expect(result.subjectOwnership, Ownership.reused);
      // Files unchanged.
      expect(await testFile.readAsString(), '// prior test content');
      expect(await subjectFile.readAsString(), '// prior subject content');
      // Registry still has exactly one record.
      expect((await registry.loadAll()), hasLength(1));
    });

    test('does not reuse an incomplete registered artifact pair', () async {
      final record = sampleRecord();
      await registry.register(record);
      await File(record.testPath).create(recursive: true);

      await expectLater(
        registry.preflight(record),
        throwsA(isA<OwnershipConflict>()),
      );
    });
  });

  group('ArtifactRegistry — generation transaction', () {
    test('preflight does not append the proposed record', () async {
      final record = sampleRecord();

      final result = await registry.preflight(record);

      expect(result.testOwnership, Ownership.created);
      expect(await registry.loadAll(), isEmpty);
      expect(File(registry.registryPath).existsSync(), isFalse);
    });

    test('append requires both artifacts to exist', () async {
      final record = sampleRecord();
      await registry.preflight(record);
      await File(record.testPath).create(recursive: true);

      await expectLater(registry.append(record), throwsA(isA<StateError>()));
      expect(await registry.loadAll(), isEmpty);
    });
  });

  group('ArtifactRegistry — ownership conflict (FR-008)', () {
    test(
      'refuses to overwrite a test file that exists on disk without a recorded ownership',
      () async {
        // A test file exists on disk, but the registry has no record.
        // `gen` must refuse to overwrite the file (ownership conflict).
        final record = sampleRecord();
        final testFile = File(record.testPath);
        await testFile.parent.create(recursive: true);
        await testFile.writeAsString('// hand-written user content');
        final shaBefore = _sha256(testFile);

        // Registering should fail with an ownership conflict.
        await expectLater(
          registry.register(record),
          throwsA(isA<OwnershipConflict>()),
        );

        // File is byte-for-byte unchanged.
        final shaAfter = _sha256(testFile);
        expect(shaAfter, shaBefore);

        // No registry file was written.
        final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
        expect(regFile.existsSync(), isFalse);
      },
    );

    test('refuses when only subject file is unowned (FR-008)', () async {
      final record = sampleRecord();
      final subjectFile = File(record.subjectPath);
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// hand-written subject content');
      final shaBefore = _sha256(subjectFile);

      await expectLater(
        registry.register(record),
        throwsA(isA<OwnershipConflict>()),
      );

      expect(_sha256(subjectFile), shaBefore);
    });
  });

  group('ArtifactRegistry — dry-run (FR-009)', () {
    test('dry-run writes no file and no registry entry', () async {
      final record = sampleRecord();
      final result = await registry.register(record, dryRun: true);
      expect(result.testOwnership, Ownership.planned);
      expect(result.subjectOwnership, Ownership.planned);

      final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      expect(regFile.existsSync(), isFalse);
    });
  });

  group('ArtifactRegistry — surgical record drop (issue #1495)', () {
    test(
      'dropRecords removes exactly the named records and keeps the rest',
      () async {
        await registry.register(
          sampleRecord(behaviorId: 'B-001', sourceCriterion: 'FR-001'),
        );
        await registry.register(
          sampleRecord(behaviorId: 'B-002', sourceCriterion: 'FR-005'),
        );
        await registry.register(
          sampleRecord(behaviorId: 'B-003', sourceCriterion: 'FR-007'),
        );

        final dropped = await registry.dropRecords({'B-002'});

        expect(dropped.map((r) => r.behaviorId), ['B-002']);
        final remaining = (await registry.loadAll())
            .map((r) => r.behaviorId)
            .toList();
        expect(remaining, ['B-001', 'B-003']);
        // The registry file stays parseable with the same feature label.
        final raw =
            jsonDecode(await File(registry.registryPath).readAsString())
                as Map<String, dynamic>;
        expect(raw['feature'], '044-test-tdd-generation');
        expect((raw['records'] as List), hasLength(2));
      },
    );

    test('dropRecords drops every named id in one write', () async {
      await registry.register(
        sampleRecord(behaviorId: 'B-001', sourceCriterion: 'FR-001'),
      );
      await registry.register(
        sampleRecord(behaviorId: 'B-002', sourceCriterion: 'FR-005'),
      );

      final dropped = await registry.dropRecords({'B-001', 'B-002'});

      expect(dropped.map((r) => r.behaviorId).toSet(), {'B-001', 'B-002'});
      expect(await registry.loadAll(), isEmpty);
    });

    test('dropRecords with an unknown id is a no-op (empty drop)', () async {
      await registry.register(
        sampleRecord(behaviorId: 'B-001', sourceCriterion: 'FR-001'),
      );

      final dropped = await registry.dropRecords({'B-UNKNOWN'});

      expect(dropped, isEmpty);
      expect(await registry.loadAll(), hasLength(1));
    });

    test('dropRecords never touches files on disk (registry-only)', () async {
      final record = sampleRecord();
      await registry.register(record);
      final testFile = File(record.testPath);
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('// owned test content');
      final shaBefore = _sha256(testFile);

      await registry.dropRecords({record.behaviorId});

      expect(_sha256(testFile), shaBefore);
      expect(await registry.loadAll(), isEmpty);
    });
  });

  group('ArtifactRegistry — read-back for verify (FR-012)', () {
    test('reads back all records for a feature', () async {
      await registry.register(
        sampleRecord(behaviorId: 'B-001', sourceCriterion: 'FR-001'),
      );
      await registry.register(
        sampleRecord(behaviorId: 'B-002', sourceCriterion: 'FR-005'),
      );
      await registry.register(
        sampleRecord(behaviorId: 'B-003', sourceCriterion: 'FR-007'),
      );

      final records = await registry.loadAll();
      expect(records, hasLength(3));
      expect(records.map((r) => r.behaviorId).toSet(), {
        'B-001',
        'B-002',
        'B-003',
      });
    });

    test('loadAll on empty registry returns empty list (FR-012)', () async {
      final records = await registry.loadAll();
      expect(records, isEmpty);
    });
  });

  group('ArtifactRegistry — path-form normalization (issue #1397)', () {
    final relTest = 'test/tdd/044-test-tdd-generation/b003_test.dart';
    final relSubject = 'lib/tdd/044-test-tdd-generation/b003_subject.dart';
    final portableTest = 'test/tdd/044-test-tdd-generation/b003_test.dart';

    /// Seed the registry file directly with one record whose paths carry
    /// [testPath]/[subjectPath] verbatim (the recorded form).
    Future<void> seedRegistry(String testPath, String subjectPath) async {
      final regFile = File(registry.registryPath);
      await regFile.parent.create(recursive: true);
      await regFile.writeAsString(
        jsonEncode({
          'feature': '044-test-tdd-generation',
          'records': [
            {
              'behavior_id': 'B-003',
              'feature': '044-test-tdd-generation',
              'source_criterion': 'FR-007',
              'test_path': testPath,
              'subject_path': subjectPath,
              'runnable_test_name': '$testPath::B-003::asserts behavior',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-08-29T20:00:00Z',
            },
          ],
        }),
      );
    }

    /// Create both prior artifacts on disk under the project layout.
    Future<void> seedArtifacts() async {
      for (final rel in [relTest, relSubject]) {
        final file = File(p.join(tmpDir.path, rel));
        await file.parent.create(recursive: true);
        await file.writeAsString('// prior artifact');
      }
    }

    ArtifactRecord offering(String testPath, String subjectPath) =>
        ArtifactRecord(
          behaviorId: 'B-003',
          feature: '044-test-tdd-generation',
          sourceCriterion: 'FR-007',
          testPath: testPath,
          subjectPath: subjectPath,
          runnableTestName: '$testPath::B-003::asserts behavior',
          testOwnership: Ownership.created,
          subjectOwnership: Ownership.created,
          createdAt: '2026-08-29T20:00:00Z',
        );

    test('preflight reuses when the prior record is project-relative and '
        'the caller offers the machine-absolute form (issue #1397)', () async {
      // The issue state: the registry's prior record (the fixture's a5
      // shape) is project-relative, while gen computes machine-absolute
      // paths for the SAME files. The gate must compare resolved paths,
      // not string forms.
      await seedArtifacts();
      await seedRegistry(relTest, relSubject);

      final result = await registry.preflight(
        offering(p.join(tmpDir.path, relTest), p.join(tmpDir.path, relSubject)),
      );

      expect(result.testOwnership, Ownership.reused);
      expect(result.subjectOwnership, Ownership.reused);
    });

    test('preflight reuses when the prior record is machine-absolute and '
        'the caller offers the project-relative form (issue #1397)', () async {
      // The inverse mix: the prior record is machine-absolute (the
      // fixture's a3/a4/a6/a7 shape) and the caller names the same files
      // project-relatively.
      await seedArtifacts();
      await seedRegistry(
        p.join(tmpDir.path, relTest),
        p.join(tmpDir.path, relSubject),
      );

      final result = await registry.preflight(offering(relTest, relSubject));

      expect(result.testOwnership, Ownership.reused);
      expect(result.subjectOwnership, Ownership.reused);
    });

    test('persists records in the portable project-relative POSIX form '
        '(issue #1397)', () async {
      // gen (pre-fix) wrote machine-absolute paths; the registry must
      // persist the portable form so committed registries survive other
      // machines.
      await seedArtifacts();
      final absolute = offering(
        p.join(tmpDir.path, relTest),
        p.join(tmpDir.path, relSubject),
      );

      await registry.append(absolute);

      final raw = await File(registry.registryPath).readAsString();
      expect(
        raw,
        isNot(contains(tmpDir.path)),
        reason: 'no machine-specific absolute path may survive persist',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final stored =
          (decoded['records'] as List).single as Map<String, dynamic>;
      expect(stored['test_path'], relTest);
      expect(stored['subject_path'], relSubject);
      // The runnable name's path segment is rebuilt with the persisted
      // form; the id and description segments are preserved verbatim.
      expect(
        stored['runnable_test_name'],
        '$portableTest::B-003::asserts behavior',
      );
    });

    test('still conflicts when the forms resolve to different files '
        '(no over-normalization)', () async {
      // Normalization must never merge distinct ownership boundaries: a
      // record pointing at another tree is a real conflict.
      await seedArtifacts();
      await seedRegistry(relTest, relSubject);

      await expectLater(
        registry.preflight(
          offering('test/other/b003_test.dart', 'lib/other/b003_subject.dart'),
        ),
        throwsA(isA<OwnershipConflict>()),
      );
    });
  });
}

String _sha256(File f) {
  // Lightweight hash — we don't need crypto-strength here, just a stable
  // byte-level comparison.
  final bytes = f.readAsBytesSync();
  var h = 0;
  for (final b in bytes) {
    h = (h * 31 + b) & 0xFFFFFFFF;
  }
  return 'hash-$h-${bytes.length}';
}
