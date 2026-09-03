import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('Version-skew contract (issue #911)', () {
    test('A1: lib/zuraffa.dart exports PersistenceTestHarness and TestClock', () {
      final harness = PersistenceTestHarness(boxNames: ['test_box']);
      final clock = TestClock();
      expect(harness, isNotNull);
      expect(clock, isNotNull);
    });

    test('A2: zfa tdd doctor detects unexported package:zuraffa symbols and prescribes upgrade-runtime', () async {
      final fx = await TddFixture.create(featureName: '001-persistence-feature');
      
      // Write a test artifact importing an unexported symbol from package:zuraffa/zuraffa.dart
      final testFile = File(p.join(fx.root.path, 'test', 'tdd', '001_persistence_feature', 'u8_test.dart'));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('''
// GENERATED TEST — zfa tdd gen U8
// behavior_id: U8
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('U8', () {
    final x = NonExistentZuraffaSymbol();
  });
}
''');

      final subjectFile = File(p.join(fx.root.path, 'lib', 'u8_subject.dart'));
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// subject\n');

      await fx.registerBehavior(
        id: 'U8',
        description: 'unexported symbol test',
        testPath: testFile.path,
        writeTestFile: false,
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['tdd', 'doctor', '001-persistence-feature', '--project', fx.root.path]);
      
      expect(out, contains('unexported symbol "NonExistentZuraffaSymbol"'));
      expect(out, contains('--> fix: dart pub upgrade zuraffa'));
    });

    test('A3: zfa tdd doctor passes when all imported package:zuraffa symbols exist in barrel', () async {
      final fx = await TddFixture.create(featureName: '001-persistence-feature');
      
      final testFile = File(p.join(fx.root.path, 'test', 'tdd', '001_persistence_feature', 'u8_test.dart'));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('''
// GENERATED TEST — zfa tdd gen U8
// behavior_id: U8
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('U8', () {
    final harness = PersistenceTestHarness(boxNames: ['box']);
    final clock = TestClock();
  });
}
''');

      final subjectFile = File(p.join(fx.root.path, 'lib', 'u8_subject.dart'));
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString('// subject\n');

      await fx.registerBehavior(
        id: 'U8',
        description: 'valid symbol test',
        testPath: testFile.path,
        writeTestFile: false,
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(['tdd', 'doctor', '001-persistence-feature', '--project', fx.root.path]);
      
      expect(out, contains('"verdict":"healthy"'));
    });
  });
}
