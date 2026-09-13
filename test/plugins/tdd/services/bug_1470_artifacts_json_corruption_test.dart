// Bug #1470 — artifacts.json corruption is silently swallowed.
//
// Pre-fix, `ArtifactRegistry._loadRecords` caught `FormatException` and
// returned [] — treating a corrupt registry identically to a missing one
// (FR-012). `register()` then saw "no prior records" and re-registered the
// behavior with `Ownership.created`, and `_appendRecord` overwrote the
// registry with the single new record: prior ownership rows silently
// destroyed, duplicate artifact files possible.
//
// Post-fix the registry throws `ArtifactRegistryCorruptException` (the same
// contract as `RunStateCorruptException` for run-state.json): corruption is
// loud, names the file, and prescribes a recovery path. A MISSING file is
// still an empty registry (FR-012 unchanged).
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
  late File regFile;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1470_registry_');
    featureDir = '${tmpDir.path}/specs/044-test-tdd-generation';
    registry = ArtifactRegistry(featureDir: featureDir);
    regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  ArtifactRecord recordFor(String behaviorId) => ArtifactRecord(
    behaviorId: behaviorId,
    feature: '044-test-tdd-generation',
    sourceCriterion: 'FR-007',
    testPath:
        'test/tdd/044-test-tdd-generation/'
        '${behaviorId.toLowerCase()}_test.dart',
    subjectPath:
        'lib/tdd/044-test-tdd-generation/'
        '${behaviorId.toLowerCase()}_subject.dart',
    runnableTestName:
        'test/tdd/044-test-tdd-generation/'
        '${behaviorId.toLowerCase()}_test.dart::$behaviorId::asserts '
        'behavior',
    testOwnership: Ownership.created,
    subjectOwnership: Ownership.created,
    createdAt: '2026-08-29T20:00:00Z',
  );

  /// Seed a valid two-record registry, then corrupt the file on disk.
  Future<void> seedThenCorrupt(String corruptBody) async {
    await regFile.parent.create(recursive: true);
    await regFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'feature': '044-test-tdd-generation',
        'records': [recordFor('B-001').toJson(), recordFor('B-002').toJson()],
      }),
    );
    await regFile.writeAsString(corruptBody, mode: FileMode.write);
  }

  group('bug #1470 — corrupt artifacts.json must be loud, never empty', () {
    test('loadAll throws ArtifactRegistryCorruptException on invalid JSON '
        '(pre-fix: silently returned [])', () async {
      await seedThenCorrupt('{"records": [ {"behavior_id": "B-001" ');

      await expectLater(
        registry.loadAll(),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );
    });

    test('register refuses to re-register through a corrupt registry — '
        'prior records survive on disk untouched (pre-fix: B-003 got '
        'Ownership.created and the rewrite destroyed B-001/B-002)', () async {
      await seedThenCorrupt('not json at all');

      await expectLater(
        registry.register(recordFor('B-003')),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );

      // The corrupt bytes were NOT overwritten by a fresh one-record
      // registry: a repair can still recover B-001/B-002 ownership.
      expect(await regFile.readAsString(), 'not json at all');
    });

    test('findRecord (reader path) also refuses a corrupt registry', () async {
      await seedThenCorrupt('{]]}');

      await expectLater(
        registry.findRecord('B-001'),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );
    });

    test('the exception names the file and prescribes recovery', () async {
      await seedThenCorrupt('{"records": [');

      try {
        await registry.loadAll();
        fail('expected ArtifactRegistryCorruptException');
      } on ArtifactRegistryCorruptException catch (e) {
        final message = e.toString();
        expect(message, contains('artifacts.json'));
        expect(message, contains(registry.registryPath));
        expect(
          message.toLowerCase(),
          contains('recovery'),
          reason: 'the message must name a recovery path',
        );
      }
    });

    test('a MISSING registry is still an empty one (FR-012 unchanged — '
        'corrupt ≠ missing)', () async {
      expect(await registry.loadAll(), isEmpty);
      expect(await registry.findRecord('B-001'), isNull);
    });
  });
}
