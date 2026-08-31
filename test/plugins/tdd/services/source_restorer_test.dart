// Tests for the SourceRestorer service (spec 044-test-tdd-generation,
// T031/T032–T033).
//
// `SourceRestorer` captures the sha256 of every in-scope subject BEFORE the
// mutation audit, and restores every temporarily mutated subject AFTER the
// audit (success, failure, timeout, or interrupt). Restoration is verified
// by sha256 comparison before the command returns (FR-021).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/source_restorer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('source_restorer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<File> writeFile(String rel, String content) async {
    final f = File('${tmpDir.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
    return f;
  }

  group('SourceRestorer', () {
    test(
      'captures sha256 of every in-scope subject pre-audit (FR-021)',
      () async {
        final f1 = await writeFile('lib/subject1.dart', 'content one');
        final f2 = await writeFile('lib/subject2.dart', 'content two');
        final restorer = SourceRestorer(paths: [f1.path, f2.path]);
        await restorer.capture();
        expect(restorer.capturedPaths, hasLength(2));
        expect(restorer.capturedPaths, contains(f1.path));
        expect(restorer.capturedPaths, contains(f2.path));
        // The captured hash is stored for later verification.
        expect(restorer.hashOf(f1.path), isNotNull);
        expect(restorer.hashOf(f2.path), isNotNull);
      },
    );

    test(
      'restores every subject post-audit and verifies sha256 match (FR-021)',
      () async {
        final f1 = await writeFile('lib/subject1.dart', 'original content one');
        final f2 = await writeFile('lib/subject2.dart', 'original content two');
        final restorer = SourceRestorer(paths: [f1.path, f2.path]);
        await restorer.capture();

        // Simulate a mutation audit: temporarily mutate the files.
        await f1.writeAsString('mutated content one');
        await f2.writeAsString('mutated content two');
        // Sanity: hashes no longer match.
        expect(restorer.hashMatches(f1.path), isFalse);
        expect(restorer.hashMatches(f2.path), isFalse);

        // Restore.
        await restorer.restoreAndVerify();
        // Files are back to their originals.
        expect(await f1.readAsString(), 'original content one');
        expect(await f2.readAsString(), 'original content two');
        // Hashes match.
        expect(restorer.hashMatches(f1.path), isTrue);
        expect(restorer.hashMatches(f2.path), isTrue);
      },
    );

    test(
      'restoration runs even on simulated interrupt (try/finally) (FR-021)',
      () async {
        final f1 = await writeFile('lib/subject1.dart', 'original content');
        final restorer = SourceRestorer(paths: [f1.path]);
        await restorer.capture();
        // Mutate.
        await f1.writeAsString('mutated content');

        // Simulate an audit that throws — restoration must still run.
        await expectLater(() async {
          try {
            await Future<void>.error(StateError('audit interrupted'));
          } finally {
            await restorer.restoreAndVerify();
          }
        }(), throwsA(isA<StateError>()));
        // The file is restored even though the audit threw.
        expect(await f1.readAsString(), 'original content');
        expect(restorer.hashMatches(f1.path), isTrue);
      },
    );

    test('restoreAndVerify returns failed=false on success', () async {
      final f1 = await writeFile('lib/subject1.dart', 'content');
      final restorer = SourceRestorer(paths: [f1.path]);
      await restorer.capture();
      // No mutation: hashes still match.
      final result = await restorer.restoreAndVerify();
      expect(result.restorationVerified, isTrue);
      expect(result.restorationFailed, isFalse);
    });

    test(
      'restoreAndVerify restores a deleted file from captured bytes',
      () async {
        final f1 = await writeFile('lib/subject1.dart', 'content');
        final restorer = SourceRestorer(paths: [f1.path]);
        await restorer.capture();
        // Delete the file (simulating a destructive mutation or audit bug).
        await f1.delete();
        // Restoration must recreate the file with the captured bytes.
        final result = await restorer.restoreAndVerify();
        expect(result.restorationVerified, isTrue);
        expect(result.restorationFailed, isFalse);
        // File is back with the original content.
        expect(await f1.readAsString(), 'content');
      },
    );
  });
}
