@Tags(['regression', 'slow'])
library;

// Regression test for issue #441.
//
// `zfa make` (and other commands) resolved the project root via an unguarded
// `Directory.current.path`. When the process CWD is an already-removed or
// otherwise invalid directory (a deleted temp dir under `dart test`, or a
// chdir into a gone path in CI/containers), `Directory.current.path` throws
// `PathNotFoundException` and the command dies with exit 255 instead of a
// clean diagnostic.
//
// `ProjectRoot.find` now guards the CWD read and falls back to the `PWD`
// environment variable (then the running script's directory) instead of
// crashing. PR #458 covered `ProjectRoot.find()` and `MakeCommand._findProjectRoot`
// only; this file also exercises the broader fix that routes the remaining
// commands listed in the issue body (app_shell, build_command, build_yaml_guard,
// config, create, doctor, migrate, module, xray_mock, xray_deck) through the
// same guarded resolver.
//
// See: https://github.com/arrrrny/zuraffa/issues/441
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_yaml_guard.dart';
import 'package:zuraffa/src/core/project/project_root.dart';

void main() {
  void restoreCwd(String previous) {
    try {
      Directory.current = previous;
    } catch (_) {
      // Best-effort restore; ignore failures (the test framework will report
      // any state leakage separately).
    }
  }

  test('ProjectRoot.find tolerates an invalid (removed) CWD', () {
    final tempDir = Directory.systemTemp.createTempSync('projroot_');
    final removed = Directory(p.join(tempDir.path, 'gone'))..createSync();

    final previous = Directory.current;
    try {
      // Make the CWD a directory, then delete it out from under ourselves so
      // `Directory.current.path` would throw PathNotFoundException.
      Directory.current = removed.path;
      expect(removed.existsSync(), isTrue);
      removed.deleteSync();

      // Before the fix this threw PathNotFoundException; now it must resolve
      // gracefully (via the PWD fallback) and return a non-empty path.
      expect(
        () => ProjectRoot.find(),
        returnsNormally,
        reason: 'find() must not throw on an invalid CWD (issue #441).',
      );

      final root = ProjectRoot.find();
      expect(root, isNotEmpty);
    } finally {
      restoreCwd(previous.path);
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ProjectRoot.find uses an explicit startPath without touching CWD', () {
    // An explicit startPath must be honoured even when CWD is invalid.
    final tempDir = Directory.systemTemp.createTempSync('projroot_expl_');
    final removed = Directory(p.join(tempDir.path, 'gone'))..createSync();

    final previous = Directory.current;
    try {
      Directory.current = removed.path;
      removed.deleteSync();

      expect(() => ProjectRoot.find(startPath: tempDir.path), returnsNormally);
      expect(ProjectRoot.find(startPath: tempDir.path), equals(tempDir.path));
    } finally {
      restoreCwd(previous.path);
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'ProjectRoot.safeCurrentPath() does not throw on an invalid CWD (#441)',
    () {
      final tempDir = Directory.systemTemp.createTempSync('projroot_safe_');
      final removed = Directory(p.join(tempDir.path, 'gone'))..createSync();

      final previous = Directory.current;
      try {
        Directory.current = removed.path;
        removed.deleteSync();

        // The public resolver the broader #441 fix exposes; every patched
        // command routes through it. Must return a non-empty string (the PWD
        // fallback or the script dir), never throw.
        expect(
          () => ProjectRoot.safeCurrentPath(),
          returnsNormally,
          reason:
              'safeCurrentPath() must not throw on an invalid CWD (issue #441).',
        );
        expect(ProjectRoot.safeCurrentPath(), isNotEmpty);
      } finally {
        restoreCwd(previous.path);
        tempDir.deleteSync(recursive: true);
      }
    },
  );

  test('BuildYamlGuard.check() does not throw on an invalid CWD (#441)', () {
    final tempDir = Directory.systemTemp.createTempSync('projroot_byg_');
    final removed = Directory(p.join(tempDir.path, 'gone'))..createSync();

    final previous = Directory.current;
    try {
      Directory.current = removed.path;
      removed.deleteSync();

      // BuildYamlGuard.check() previously read `Directory.current.path`
      // directly; the broader fix routes it through `safeCurrentPath()`.
      // Must return a status instead of throwing PathNotFoundException.
      expect(
        () => BuildYamlGuard.check(),
        returnsNormally,
        reason:
            'BuildYamlGuard.check() must not throw on an invalid CWD (issue #441).',
      );
      expect(BuildYamlGuard.check(), isA<BuildYamlStatus>());
    } finally {
      restoreCwd(previous.path);
      tempDir.deleteSync(recursive: true);
    }
  });

  test('BuildYamlGuard.scaffold() honors an explicit root on an invalid CWD '
      '(#441)', () async {
    final tempDir = Directory.systemTemp.createTempSync('projroot_bygs_');
    final removed = Directory(p.join(tempDir.path, 'gone'))..createSync();
    final scratch = Directory.systemTemp.createTempSync(
      'projroot_bygs_scratch_',
    );

    final previous = Directory.current;
    try {
      Directory.current = removed.path;
      removed.deleteSync();

      // With an explicit projectRoot, scaffold() must succeed even when the
      // CWD is invalid; the test asserts no PathNotFoundException.
      await expectLater(
        BuildYamlGuard.scaffold(projectRoot: scratch.path),
        completes,
      );
      expect(File(p.join(scratch.path, 'build.yaml')).existsSync(), isTrue);
    } finally {
      restoreCwd(previous.path);
      tempDir.deleteSync(recursive: true);
      if (scratch.existsSync()) {
        scratch.deleteSync(recursive: true);
      }
    }
  });
}
