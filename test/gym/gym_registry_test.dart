// Tests for the package-level gym registry (.gym/gym.yaml).
//
// The gym.yaml file is consumed by the miki GYM runner (a separate
// headless Dart tool). A misconfiguration in gym.yaml (missing
// verifyCommand, wrong exercise id, missing entry for an exercise file
// that exists on disk) breaks the runner silently. These tests are the
// regression guard.
//
// Coverage:
//   1. The two canonical exercises are registered with stable ids.
//   2. Every exercise .dart file in .gym/ has a matching entry in
//      gym.yaml with a `verifyCommand` pointing at it.
//   3. The new detect-non-zuraffa-package exercise (issue #478) is
//      registered with the expected shape.

import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

String get _gymDir {
  // Test files are run from the package root, so .gym/ is at CWD/.gym/.
  // Walk up to find .gym/ to be resilient to CWD shifts.
  var dir = Directory.current;
  for (var i = 0; i < 12; i += 1) {
    final candidate = Directory(p.join(dir.path, '.gym'));
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return p.join(Directory.current.path, '.gym');
}

String get _gymYaml => File(p.join(_gymDir, 'gym.yaml')).readAsStringSync();

void main() {
  group('package gym.yaml registry', () {
    test('exposes the generate-feature exercise', () {
      expect(_gymYaml, contains('id: generate-feature'));
      expect(
        _gymYaml,
        contains('dart run .gym/exercise-generate-feature.dart'),
      );
    });

    test('exposes the detect-non-zuraffa-package exercise (issue #478)', () {
      expect(_gymYaml, contains('id: detect-non-zuraffa-package'));
      expect(
        _gymYaml,
        contains('dart run .gym/exercise-detect-non-zuraffa-package.dart'),
      );
    });

    test(
      'every exercise .dart file in .gym/ has a registered verifyCommand',
      () {
        final exerciseFiles = Directory(_gymDir)
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith('exercise-'))
            .where((f) => p.extension(f.path) == '.dart')
            .map((f) => p.basename(f.path))
            .toList();

        expect(
          exerciseFiles,
          isNotEmpty,
          reason: 'No exercise-*.dart files found in $_gymDir',
        );

        for (final file in exerciseFiles) {
          final needle = 'dart run .gym/$file';
          expect(
            _gymYaml,
            contains(needle),
            reason: 'Exercise file $file has no verifyCommand in gym.yaml',
          );
        }
      },
    );

    test('detect-non-zuraffa-package exercise file exists on disk', () {
      final exerciseFile = File(
        p.join(_gymDir, 'exercise-detect-non-zuraffa-package.dart'),
      );
      expect(
        exerciseFile.existsSync(),
        isTrue,
        reason: 'The exercise file referenced by gym.yaml must exist on disk.',
      );
    });
  });
}
