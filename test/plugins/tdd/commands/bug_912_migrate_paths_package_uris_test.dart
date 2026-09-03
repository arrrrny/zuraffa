// Bug #912 defect 4 — migrate-paths package-URI rewrite + honest
// self-check, and the doctor import-resolution drift check.
//
// Defect 4 (from #907): `zfa tdd migrate-paths` rewrites the moved test's
// RELATIVE subject import but not `package:` URI imports — the pair moves,
// the command reports `migrated=1` success, and the suite is unloadable.
// The command must:
//   1. rewrite the self-package URI form of the subject reference;
//   2. repair ALREADY-MIGRATED-BUT-BROKEN pairs (a stale flat reference
//      left behind by a pre-fix migration) instead of skipping them as
//      "already namespaced";
//   3. self-check the moved test's imports before declaring success — a
//      subject reference that cannot be made resolvable is a REFUSAL with
//      rollback and exit 1, never `migrated=N` success on red;
// and `zfa tdd doctor <feature>` must report dangling imports of recorded
// test files as drift prescribed to `zfa tdd migrate-paths`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String featureName = '100-feature-one';
const String packageName = 'fixture_app';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug912_migrate_');
    // The host package name the package-URI rewrites resolve against.
    await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: $packageName
environment:
  sdk: ^3.11.0
''');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedRegistry(String testPath, String subjectPath) async {
    File(p.join(tmpDir.path, 'specs', featureName, 'tdd', 'artifacts.json'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
{
  "feature": "$featureName",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "$featureName",
      "source_criterion": "FR-007",
      "test_path": "$testPath",
      "subject_path": "$subjectPath",
      "runnable_test_name": "$testPath::A1::returns 42",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-01T00:00:00.000Z"
    }
  ]
}
''');
  }

  File testAt(String relative) => File(p.join(tmpDir.path, relative));

  group('bug 912 defect 4: migrate-paths package-URI imports', () {
    test('a flat pair whose test imports the subject via a package URI is '
        'rewritten to the namespaced URI', () async {
      const flatTest = 'test/tdd/a1_test.dart';
      const flatSubject = 'lib/tdd/a1_subject.dart';
      await seedRegistry(flatTest, flatSubject);
      await testAt(flatTest).parent.create(recursive: true);
      await testAt(flatTest).writeAsString('''
import 'package:test/test.dart';
import 'package:$packageName/tdd/a1_subject.dart' as subject;

void main() {}
''');
      await testAt(flatSubject).parent.create(recursive: true);
      await testAt(flatSubject).writeAsString('int subjectUnderTest() => 42;');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        '--project',
        tmpDir.path,
      ]);

      expect(out, contains('migrated=1'));
      final moved = testAt('test/tdd/$featureName/a1_test.dart');
      expect(moved.existsSync(), isTrue);
      final content = moved.readAsStringSync();
      expect(
        content,
        contains('package:$packageName/tdd/$featureName/a1_subject.dart'),
        reason:
            'the package-URI subject import must be rewritten to the '
            'namespaced location (issue #912 defect 4) — a moved pair '
            'whose import still names the flat URI is an unloadable suite',
      );
      expect(
        content,
        isNot(contains('package:$packageName/tdd/a1_subject.dart')),
      );
      // The self-check promise: the rewritten import resolves on disk.
      expect(
        File(
          p.join(tmpDir.path, 'lib', 'tdd', featureName, 'a1_subject.dart'),
        ).existsSync(),
        isTrue,
      );
    });

    test('an already-migrated-but-broken pair is repaired on re-run', () async {
      const namespacedTest = 'test/tdd/$featureName/a1_test.dart';
      const namespacedSubject = 'lib/tdd/$featureName/a1_subject.dart';
      await seedRegistry(namespacedTest, namespacedSubject);
      // The subject was moved, but the test's import still names the FLAT
      // package URI (the pre-fix migrate-paths outcome).
      await testAt(namespacedTest).parent.create(recursive: true);
      await testAt(namespacedTest).writeAsString('''
import 'package:test/test.dart';
import 'package:$packageName/tdd/a1_subject.dart' as subject;

void main() {}
''');
      await testAt(namespacedSubject).parent.create(recursive: true);
      await testAt(
        namespacedSubject,
      ).writeAsString('int subjectUnderTest() => 42;');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        contains('migrated=1'),
        reason:
            'repairing an already-migrated-but-broken pair is a migration '
            '(issue #912 hard constraint: handle the broken state)',
      );
      expect(
        testAt(namespacedTest).readAsStringSync(),
        contains('package:$packageName/tdd/$featureName/a1_subject.dart'),
      );
    });

    test('a pair whose subject reference cannot be made resolvable is '
        'REFUSED and rolled back — never a false migrated=N success', () async {
      const flatTest = 'test/tdd/a1_test.dart';
      const flatSubject = 'lib/tdd/a1_subject.dart';
      await seedRegistry(flatTest, flatSubject);
      // The test references the subject ONLY through a package URI of a
      // DIFFERENT package (the pubspec name cannot own it) — the rewrite
      // cannot make it resolvable.
      await testAt(flatTest).parent.create(recursive: true);
      await testAt(flatTest).writeAsString('''
import 'package:test/test.dart';
import 'package:some_other_package/tdd/a1_subject.dart' as subject;

void main() {}
''');
      await testAt(flatSubject).parent.create(recursive: true);
      await testAt(flatSubject).writeAsString('int subjectUnderTest() => 42;');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        contains('refused=1'),
        reason:
            'the command must self-check the moved pair and refuse when '
            'the subject reference cannot resolve (issue #912 defect 4: '
            'success-on-red)',
      );
      expect(out, contains('migrated=0'));
      // Rolled back: the pair is exactly where it was.
      expect(testAt(flatTest).existsSync(), isTrue);
      expect(
        testAt('test/tdd/$featureName/a1_test.dart').existsSync(),
        isFalse,
      );
    });
  });

  group('bug 912 defect 4: doctor import-resolution drift check', () {
    test('a recorded test with a dangling import is drift prescribed to '
        'migrate-paths', () async {
      const namespacedTest = 'test/tdd/$featureName/a1_test.dart';
      const namespacedSubject = 'lib/tdd/$featureName/a1_subject.dart';
      await seedRegistry(namespacedTest, namespacedSubject);
      await testAt(namespacedTest).parent.create(recursive: true);
      // The relative import dangles: the subject lives one directory
      // deeper than the flat-era path assumed.
      await testAt(namespacedTest).writeAsString('''
import 'package:test/test.dart';
import '../../../lib/tdd/a1_subject.dart' as subject;

void main() {}
''');
      await testAt(namespacedSubject).parent.create(recursive: true);
      await testAt(
        namespacedSubject,
      ).writeAsString('int subjectUnderTest() => 42;');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'doctor',
        featureName,
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        contains('drift'),
        reason:
            'doctor must surface import-resolution drift (issue #912 '
            'remediation 3) instead of reporting the stores as healthy',
      );
      expect(out, contains('migrate-paths'));
    });
  });
}
