// The committed-subject header sweep for issue #1992 — the repository's
// OWN generated subjects must never carry a machine-absolute anchor path.
//
// Issue #1983 fixed the GENERATOR: the composed subject's header names
// each anchor by its portable, package-qualified path
// (`lib/tdd/<feature>/u1_subject.dart`, or
// `packages/app:lib/tdd/<feature>/u1_subject.dart` for a package below
// the project root). PR #1989 shipped that fix.
//
// The subjects committed BEFORE the fix were emitted by the old generator
// and still carried another machine's absolute paths
// (`/workspace/zuraffa/.worktrees/072-dependency-mocks/lib/tdd/...`,
// `/home/z/my-project/zuraffa/...`) — a committed source file leaking a
// developer's home directory into the repository, and a trace that means
// nothing on another machine or in CI.
//
// `bug_1983_compose_anchor_path_test.dart` pins the RENDER (the generator
// writes the portable form). This test pins the REPOSITORY: every
// committed subject — the self-hosted `lib/tdd/**` fixtures and the
// `example/` project's own — must carry a portable header. A fixture that
// was never re-emitted (or a re-emit that regressed) fails here, so the
// leak cannot come back through a file the generator test never sees.
library;

import 'dart:io';

import 'package:test/test.dart';

/// The header line the compose step writes — `// composed against: …`.
///
/// The prose line above it ("composed against the feature's green …")
/// carries no colon and never matches; the `///` doc comment does not
/// either.
final RegExp _headerLine = RegExp(r'^//\s*composed against:\s*(.+)$');

/// One anchor entry: `U1 (path)`, optionally followed by the
/// `[stub]` / `[entity-wired]` marker.
final RegExp _entry = RegExp(r'\(([^()]+)\)');

/// A Windows drive-absolute path (`C:\…`).
final RegExp _windowsAbsolute = RegExp(r'^[A-Za-z]:[\\/]');

/// The roots that hold the repository's own generated subjects.
const List<String> _roots = ['lib/tdd', 'example/lib/tdd'];

void main() {
  test('issue 1992: no committed subject header carries an absolute path', () {
    final offenders = <String>[];

    for (final root in _roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('_subject.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final header = _headerLine.firstMatch(lines[i]);
          if (header == null) continue;
          for (final entry in _entry.allMatches(header.group(1)!)) {
            final path = entry.group(1)!.trim();
            if (path.startsWith('/') || _windowsAbsolute.hasMatch(path)) {
              offenders.add('${entity.path}:${i + 1}: $path');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a committed subject header names an anchor by a '
          'machine-absolute path — the home directory of whoever '
          'composed it is committed to the repository. Re-emit the '
          'fixture with `zfa tdd gen <behavior> --repair` followed by '
          '`zfa tdd compose <behavior>` (issue #1992):\n'
          '${offenders.join('\n')}',
    );
  });
}
