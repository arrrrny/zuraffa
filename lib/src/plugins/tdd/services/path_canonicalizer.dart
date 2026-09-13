/// Path canonicalization for the TDD plugin's subject-containment guard
/// (issue #1603, pull/1516 review).
///
/// A missing artifact has nothing to `resolveSymbolicLinks`, so the raw
/// path fails the containment check whenever the project root travels a
/// symlink — macOS's `/var/folders` → `/private/var/folders` is the
/// canonical shape, and the project's own recorded subject was misreported
/// as "outside the project root" (the wrong refusal branch). Both sides of
/// the guard — the root and the subject — go through this helper, so
/// "both sides canonical" is a property of the check rather than a
/// coincidence (review of #1611).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Canonicalize [path] when the file itself does not exist yet: walk up
/// to the nearest EXISTING ancestor, resolve THAT through symlinks, and
/// re-append the remaining (missing) segments. Returns [path] unchanged
/// when no ancestor resolves (issue #1603 / pull/1516 review: a symlinked
/// temp root must not make the project's own recorded subject path compare
/// as outside the project root).
Future<String> canonicalizeMissingPath(String path) async {
  var dir = Directory(p.dirname(path));
  final tail = <String>[p.basename(path)];
  while (true) {
    try {
      final resolved = await dir.resolveSymbolicLinks();
      return p.joinAll([resolved, ...tail.reversed]);
    } on FileSystemException {
      final parent = dir.parent;
      if (parent.path == dir.path) return path;
      tail.add(p.basename(dir.path));
      dir = parent;
    }
  }
}
