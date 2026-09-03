import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('Template self-hosting defects (issue #912)', () {
    test('A1: BehaviorTestWriter escapes apostrophes in persistence test descriptions', () async {
      final tempDir = Directory.systemTemp.createTempSync('escape_test_');
      final testPath = p.join(tempDir.path, 'test', 'persistence_test.dart');
      final subjectPath = p.join(tempDir.path, 'lib', 'persistence_subject.dart');

      final behavior = Behavior(
        id: 'U1',
        feature: '001-theme-feature',
        sourceCriterion: 'FR-001',
        kind: BehaviorKind.unit,
        description: "persist the user's theme preference",
        target: 'persistTheme',
        persistence: true,
      );

      const writer = BehaviorTestWriter();
      await writer.write(
        behavior: behavior,
        testPath: testPath,
        subjectPath: subjectPath,
      );

      final content = await File(testPath).readAsString();
      expect(content, contains("test('U1 - persist the user\\'s theme preference'"));
      tempDir.deleteSync(recursive: true);
    });

    test('A2: migrate-paths rewrites package-URI imports in moved tests', () async {
      final fx = await TddFixture.create(featureName: '001-composed-feature');

      final flatTest = File(p.join(fx.root.path, 'test', 'tdd', 'b1_test.dart'));
      await flatTest.parent.create(recursive: true);
      await flatTest.writeAsString('''
import 'package:tdd_fixture/tdd/b1_subject.dart' as subject;
import '../../lib/tdd/b1_subject.dart' as rel_subject;
''');

      final flatSubject = File(p.join(fx.root.path, 'lib', 'tdd', 'b1_subject.dart'));
      await flatSubject.parent.create(recursive: true);
      await flatSubject.writeAsString('// subject\n');

      final artifactsFile = File(p.join(fx.root.path, 'specs', '001-composed-feature', 'tdd', 'artifacts.json'));
      await artifactsFile.parent.create(recursive: true);
      await artifactsFile.writeAsString(jsonEncode({
        'feature': '001-composed-feature',
        'records': [
          {
            'behavior_id': 'B1',
            'feature': '001-composed-feature',
            'source_criterion': 'FR-001',
            'test_path': 'test/tdd/b1_test.dart',
            'subject_path': 'lib/tdd/b1_subject.dart',
            'runnable_test_name': 'test/tdd/b1_test.dart::B1::test',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          }
        ]
      }));

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(['tdd', 'migrate-paths', '--feature', '001-composed-feature', '--project', fx.root.path]);

      final migratedTest = File(p.join(fx.root.path, 'test', 'tdd', '001-composed-feature', 'b1_test.dart'));
      expect(migratedTest.existsSync(), isTrue);
      final migratedContent = await migratedTest.readAsString();
      expect(migratedContent, contains('package:tdd_fixture/tdd/001-composed-feature/b1_subject.dart'));
    });
  });
}
