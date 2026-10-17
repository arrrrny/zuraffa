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

  // Bug #1738 — the run path's DECISION reads must degrade a corrupt registry
  // to "no records" instead of aborting the drive, while the #1470 "loud on
  // write / loud on the throwing readers" contract stays exactly as it is.
  // `loadAllTolerant` / `findRecordTolerant` encode that property; these
  // assertions pin it so a future edit that narrows or drops the catch turns
  // red instead of silently regressing #1738.
  group('bug #1738 — tolerant readers degrade corruption to empty, the '
      'throwing contract is unchanged', () {
    test('loadAllTolerant returns [] / findRecordTolerant returns null on a '
        'truncated registry', () async {
      await seedThenCorrupt('{"feature":"x","reco');

      expect(await registry.loadAllTolerant(), isEmpty);
      expect(await registry.findRecordTolerant('B-001'), isNull);
    });

    test(
      'every corrupt shape the throwing readers reject is swallowed by '
      'the tolerant readers — and still thrown by the throwing ones',
      () async {
        const corruptShapes = [
          '{]]}', // unparseable JSON (reader path)
          '{"feature": "044-test-tdd-generation"}', // no "records" list
          '{}', // empty object, no "records"
          '["B-001"]', // non-object top level
          '{"records": {"behavior_id": "B-001"}}', // "records" is not a list
          '{"records": [42]}', // record entry is not an object
        ];
        for (final content in corruptShapes) {
          await seedThenCorrupt(content);

          expect(
            await registry.loadAllTolerant(),
            isEmpty,
            reason: 'loadAllTolerant for registry content: $content',
          );
          expect(
            await registry.findRecordTolerant('B-001'),
            isNull,
            reason: 'findRecordTolerant for registry content: $content',
          );

          // The #1470 contract is deliberately unchanged: the throwing readers
          // still surface the corruption.
          await expectLater(
            registry.loadAll(),
            throwsA(isA<ArtifactRegistryCorruptException>()),
            reason: 'loadAll for registry content: $content',
          );
          await expectLater(
            registry.findRecord('B-001'),
            throwsA(isA<ArtifactRegistryCorruptException>()),
            reason: 'findRecord for registry content: $content',
          );
        }
      },
    );

    test(
      'a valid registry reads unchanged through the tolerant readers',
      () async {
        await seedValidRegistry();

        final all = await registry.loadAllTolerant();
        expect(all.map((r) => r.behaviorId), ['B-001', 'B-002']);
        expect(
          (await registry.findRecordTolerant('B-001'))?.behaviorId,
          'B-001',
        );
        expect(await registry.findRecordTolerant('B-404'), isNull);
      },
    );

    test('a MISSING registry is still empty through the tolerant readers '
        '(no throw)', () async {
      expect(await registry.loadAllTolerant(), isEmpty);
      expect(await registry.findRecordTolerant('B-001'), isNull);
    });
  });
}
