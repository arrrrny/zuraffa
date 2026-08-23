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
// crashing.
//
// See: https://github.com/arrrrny/zuraffa/issues/441

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/project/project_root.dart';

void main() {
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
      Directory.current = previous;
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
      Directory.current = previous;
      tempDir.deleteSync(recursive: true);
    }
  });
}
