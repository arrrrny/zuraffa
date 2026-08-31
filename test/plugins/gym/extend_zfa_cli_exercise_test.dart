@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final repoRoot = _findRepoRoot();
  final exerciseFile = File(
    p.join(repoRoot, '.gym', 'exercise-extend-zfa-cli.dart'),
  );
  final gymFile = File(p.join(repoRoot, '.gym', 'gym.yaml'));

  group('extend-zfa-cli exercise (B06, B07, B08, B13, B14)', () {
    test('exercise file exists (B06)', () {
      expect(
        exerciseFile.existsSync(),
        isTrue,
        reason: '.gym/exercise-extend-zfa-cli.dart must exist',
      );
    });

    test(
      'exercise is a genuine dev task, not a re-skinned unit test (B06)',
      () {
        final src = exerciseFile.readAsStringSync();
        // The exercise must spawn a subprocess (real dev task: invoke
        // `dart run` against a submission).
        expect(src, contains('Process.run'));
        // The exercise must spawn `dart` (the operator's toolchain).
        expect(src, contains("'dart'"));
        // The exercise must assert stdout content.
        expect(src, contains('hello from hello'));
        // The exercise must NOT be a simple `expect()` call on a known
        // value (that would be a re-skinned unit test).
        expect(src.contains("expect(equals("), isFalse);
      },
    );

    test('exercise writes sandbox under .gym/.sandbox/ (B13, FR-005)', () {
      final src = exerciseFile.readAsStringSync();
      expect(src, contains('.gym/.sandbox/extend-zfa-cli'));
    });

    test('exercise uses exit-code-based grading (B14, FR-007)', () {
      final src = exerciseFile.readAsStringSync();
      expect(src, contains('exit(0)'));
      expect(src, contains('exit(1)'));
    });

    test('exercise emits DROP CARD on mis-fire (B08)', () {
      final src = exerciseFile.readAsStringSync();
      expect(src, contains('DropCard'));
      // The mis-fire path must persist the card AND print to stderr.
      expect(src, contains('emitAndPersist'));
    });

    test('exercise is registered in gym.yaml (B07)', () {
      expect(gymFile.existsSync(), isTrue);
      final doc = loadYaml(gymFile.readAsStringSync()) as YamlMap;
      final exercises = doc['exercises'] as YamlList;
      final entry = exercises.firstWhere(
        (e) => (e as YamlMap)['id'] == 'extend-zfa-cli',
        orElse: () => throw StateError('extend-zfa-cli not in gym.yaml'),
      );
      final m = entry as YamlMap;
      expect(m['brief'], isNotNull);
      expect(m['setup'], isNotNull);
      expect(m['verifyCommand'], contains('exercise-extend-zfa-cli.dart'));
      expect(m['evaluate'], contains('exit 0 => pass'));
    });
  });

  group('extend-zfa-cli sandbox isolation (B13)', () {
    test('exercise file does not modify lib/ source tree', () {
      final src = exerciseFile.readAsStringSync();
      // The exercise writes only under .gym/.sandbox/. It must NOT
      // write to lib/ or test/ or any other source path.
      expect(src.contains("writeAsStringSync('lib/"), isFalse);
      expect(src.contains("writeAsStringSync('test/"), isFalse);
      // The sandbox path is the only write target.
      expect(src, contains('sandboxRoot'));
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('name: zuraffa\n')) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find zuraffa repo root');
    }
    dir = parent;
  }
}
