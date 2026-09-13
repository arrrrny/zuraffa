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

  /// Seed a valid two-record registry and return the bytes written.
  Future<String> seedValidRegistry() async {
    await regFile.parent.create(recursive: true);
    final valid = const JsonEncoder.withIndent('  ').convert({
      'feature': '044-test-tdd-generation',
      'records': [recordFor('B-001').toJson(), recordFor('B-002').toJson()],
    });
    await regFile.writeAsString(valid);
    return valid;
  }

  /// Seed a valid two-record registry, then corrupt the file on disk.
  Future<void> seedThenCorrupt(String corruptBody) async {
    await seedValidRegistry();
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
      // Corrupt the file the way a crash mid-write would: a truncated
      // copy of the REAL B-001/B-002 bytes, not an unrelated literal, so
      // the survival check below is honest about what it proves.
      final valid = await seedValidRegistry();
      final corrupt = valid.substring(0, valid.length ~/ 2);
      await regFile.writeAsString(corrupt);

      await expectLater(
        registry.register(recordFor('B-003')),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );

      // The corrupt bytes were NOT overwritten by a fresh one-record
      // registry: a repair can still recover B-001/B-002 ownership.
      expect(await regFile.readAsString(), corrupt);
    });

    test('a valid-JSON registry with no "records" list is corrupt, not a '
        'fresh feature', () async {
      // jsonDecode accepts these files, so the FormatException clause
      // never fires; without the shape gate they read as "no prior
      // records" and the next append rewrites the file (the same #1470
      // P1 chain as unparseable JSON).
      await seedThenCorrupt('{"feature": "044-test-tdd-generation"}');
      await expectLater(
        registry.register(recordFor('B-003')),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );

      await seedThenCorrupt('{}');
      await expectLater(
        registry.loadAll(),
        throwsA(isA<ArtifactRegistryCorruptException>()),
      );
    });

    test('wrong-shape JSON maps to the recovery exception, not a raw '
        'TypeError', () async {
      // These used to throw TypeError from the casts, so the caller got a
      // Dart stack trace instead of the actionable recovery message.
      const wrongShapes = [
        '["B-001"]', // non-object top level
        '{"records": {"behavior_id": "B-001"}}', // "records" is not a list
        '{"records": [42]}', // record entry is not an object
      ];
      for (final content in wrongShapes) {
        await seedThenCorrupt(content);
        await expectLater(
          registry.loadAll(),
          throwsA(isA<ArtifactRegistryCorruptException>()),
          reason: 'registry content: $content',
        );
      }
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
