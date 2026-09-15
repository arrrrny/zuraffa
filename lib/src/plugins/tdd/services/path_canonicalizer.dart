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
///
/// Precondition (issue #1610): inputs MUST be ABSOLUTE. The walk-up
/// resolves against the real filesystem, so a relative input makes
/// `Directory(p.dirname(path))` collapse to `.` (the process CWD) and the
/// result is silently CWD-joined — a CWD-dependent answer with no error
/// surfaced, exactly the silent-wrong-result class the containment guard
/// exists to prevent. Every call site absolutizes first
/// (`p.normalize(p.absolute(...))`, joining recorded relative subjects
/// onto the absolute project root); keep doing the same in new callers.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Canonicalize [path] when the file itself does not exist yet: walk up
/// to the nearest EXISTING ancestor, resolve THAT through symlinks, and
/// re-append the remaining (missing) segments. Returns [path] unchanged
/// when no ancestor resolves (issue #1603 / pull/1516 review: a symlinked
/// temp root must not make the project's own recorded subject path compare
/// as outside the project root).
///
/// [path] MUST be absolute — absolutize first, e.g.
/// `p.normalize(p.absolute(...))` or join onto the absolute project root,
/// as every call site does. For a relative input the dirname collapses to
/// `.` (the process CWD) and the result is silently CWD-joined.
///
/// Fallback contract: when NO ancestor resolves the walk returns [path]
/// UNCHANGED. That branch is defensive and unreachable through the public
/// surface on POSIX (the filesystem root itself always resolves); it is
/// asserted by the direct unit tests only as the walk-up exhaustion
/// contract (see
/// `test/plugins/tdd/services/path_canonicalizer_test.dart`).
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
