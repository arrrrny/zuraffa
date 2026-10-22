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
// committed subject — the self-hosted `lib/tdd/**` fixtures and every
// nested package's own (`example/`, `examples/todo_tdd/`) — must carry a
// portable header. A fixture that was never re-emitted (or a re-emit that
// regressed) fails here, so the leak cannot come back through a file the
// generator test never sees.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The header line the compose step writes — `// composed against: …`.
///
/// The prose line above it ("composed against the feature's green …")
/// carries no colon and never matches; the `///` doc comment does not
/// either.
final RegExp _headerLine = RegExp(r'^//\s*composed against:\s*(.+)$');

/// A Windows absolute path: drive-absolute (`C:\…`) or UNC
/// (`\\server\share\…`).
///
/// The UNC form is absolute on Windows even though a Unix-shaped check
/// reads it as relative — a committed subject carrying one still names
/// a machine-specific location, so the sweep rejects it too.
final RegExp _windowsAbsolute = RegExp(r'^([A-Za-z]:[\\/]|\\\\)');

/// The subject roots the repository is KNOWN to have.
///
/// Every one of them must exist. A root that vanished is a rename of a
/// fixture tree, and skipping it silently would take the guard with it —
/// the sweep would scan nothing there and report success, and the leak
/// this test closes would come straight back. Roots the repository gains
/// LATER are picked up by the discovery below, so this list pins what
/// exists, not what may exist.
const List<String> _declaredRoots = [
  'lib/tdd',
  'example/lib/tdd',
  'examples/todo_tdd/lib/tdd',
];

/// Directory names the discovery walk never descends into — build output
/// and dependency trees hold no committed subjects, and walking them
/// would only slow the sweep.
const Set<String> _skipDirNames = {'build', 'node_modules'};

/// Every `lib/tdd` subject root in the working tree.
///
/// The roots are DISCOVERED, not only declared: a nested package (the
/// `example` project, `examples/todo_tdd`) keeps its own committed
/// subjects under `<package>/lib/tdd`, and a NEW example project must be
/// covered by the sweep without this file being edited.
List<String> _discoverRoots() {
  final roots = <String>{};
  for (final top in Directory('.').listSync(followLinks: false)) {
    if (top is! Directory) continue;
    final name = p.basename(top.path);
    if (name.startsWith('.') || _skipDirNames.contains(name)) continue;
    for (final nested in top.listSync(recursive: true, followLinks: false)) {
      if (nested is! Directory) continue;
      final path = p.normalize(nested.path);
      final segments = p.split(path);
      if (segments.length >= 2 &&
          segments[segments.length - 1] == 'tdd' &&
          segments[segments.length - 2] == 'lib') {
        roots.add(path);
      }
    }
  }
  return roots.toList()..sort();
}

/// The index of the `)` closing the `(` at [open], or -1 when the span is
/// unterminated.
int _matchingParen(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final ch = text[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// The anchor paths a header names.
///
/// The parenthesised span is walked with a paren-depth counter instead
/// of a regex: an anchor path may itself contain parentheses
/// (`C:\Program Files (x86)\…`), and a `\(([^()]+)\)` match would stop
/// at the inner `)` and hand back `x86` — a relative fragment that
/// hides the absolute prefix.
List<String> _anchorPaths(String header) {
  final paths = <String>[];
  var i = 0;
  while (i < header.length) {
    final open = header.indexOf('(', i);
    if (open < 0) break;
    final close = _matchingParen(header, open);
    // An unterminated span is taken whole: a path carrying a stray `(`
    // must not be able to hide its prefix from the sweep.
    final path = close < 0
        ? header.substring(open + 1)
        : header.substring(open + 1, close);
    paths.add(path.trim());
    if (close < 0) break;
    i = close + 1;
  }
  return paths;
}

/// Whether [path] names a machine-absolute location.
bool _isAbsoluteAnchor(String path) =>
    path.startsWith('/') || _windowsAbsolute.hasMatch(path);

/// The absolute anchor paths a header line names — empty when the header
/// is portable.
List<String> _absoluteAnchors(String line) {
  final header = _headerLine.firstMatch(line);
  if (header == null) return const [];
  return _anchorPaths(
    header.group(1)!,
  ).where(_isAbsoluteAnchor).toList(growable: false);
}

void main() {
  group('the anchor-path detector', () {
    test('rejects a POSIX absolute path', () {
      expect(
        _absoluteAnchors(
          r'// composed against: U1 (/home/z/my-project/zuraffa/lib/tdd/u1_subject.dart)',
        ),
        equals([r'/home/z/my-project/zuraffa/lib/tdd/u1_subject.dart']),
      );
    });

    test('rejects a Windows drive-absolute path', () {
      expect(
        _absoluteAnchors(
          r'// composed against: U1 (C:\zuraffa\lib\tdd\u1_subject.dart)',
        ),
        equals([r'C:\zuraffa\lib\tdd\u1_subject.dart']),
      );
    });

    test('rejects a Windows UNC path', () {
      expect(
        _absoluteAnchors(
          r'// composed against: U1 (\\server\share\u1_subject.dart)',
        ),
        equals([r'\\server\share\u1_subject.dart']),
      );
    });

    test('rejects an absolute path that contains parentheses', () {
      const path = r'C:\Program Files (x86)\zuraffa\lib\tdd\u1_subject.dart';
      expect(
        _absoluteAnchors('// composed against: U1 ($path)'),
        equals([path]),
      );
    });

    test('accepts a portable package-relative path', () {
      expect(
        _absoluteAnchors(
          r'// composed against: U1 (lib/tdd/072-dependency-mocks/u1_subject.dart)',
        ),
        isEmpty,
      );
    });

    test('reports the absolute anchor of a multi-anchor header only', () {
      expect(
        _absoluteAnchors(
          r'// composed against: U1 (lib/tdd/feature/u1_subject.dart), '
          r'U2 (/workspace/zuraffa/lib/tdd/feature/u2_subject.dart)',
        ),
        equals([r'/workspace/zuraffa/lib/tdd/feature/u2_subject.dart']),
      );
    });

    test('ignores a line that is not a composed-against header', () {
      expect(
        _absoluteAnchors(
          r"// composed against the feature's green / entity-wired unit subjects",
        ),
        isEmpty,
      );
    });
  });

  test('issue 1992: no committed subject header carries an absolute path', () {
    for (final root in _declaredRoots) {
      expect(
        Directory(root).existsSync(),
        isTrue,
        reason:
            'the subject root "$root" is missing — the sweep would scan '
            'nothing there and pass vacuously, so the guard this test IS '
            'would be gone with no signal.',
      );
    }

    final offenders = <String>[];
    final roots = <String>{..._declaredRoots, ..._discoverRoots()};

    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('_subject.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final path in _absoluteAnchors(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: $path');
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
