// The package-root-relative form of a subject artifact's path.
//
// Issue #1983: the composed subject's header names the unit subjects it
// composed against. It used to carry the ABSOLUTE path the discovery
// resolved — e.g.
//
//   // composed against: U-001 (/Users/<dev>/zuraffa_purchase/packages/
//   zuraffa_purchase/lib/tdd/002-subscription-error-vocabulary/u1_subject.dart)
//
// The header is a committed source file, so one developer's home directory
// ends up in the repository: it is noise for every reader, it leaks the
// local layout, and the trace means nothing on another machine or in CI.
//
// The portable form is the path relative to the PACKAGE root — the
// directory carrying the package's `pubspec.yaml`:
//
//   // composed against: U-001 (lib/tdd/002-subscription-error-vocabulary/u1_subject.dart)
//
// The package root is the nearest ancestor of the file carrying a
// `pubspec.yaml`; the project root is the fallback when the file sits
// outside every package (a subject outside `lib/`, or a fixture without a
// package of its own).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The path of [absolutePath] relative to its PACKAGE root, with POSIX
/// separators.
///
/// Falls back to the project-root-relative path when the file sits outside
/// every package, and to the path itself when neither root contains it —
/// a path that cannot be made portable is never silently mangled.
String packageRelativePath(String absolutePath, {String? projectRoot}) {
  final resolved = _resolve(absolutePath);

  final packageRoot = _packageRootOf(resolved);
  if (packageRoot != null && p.isWithin(packageRoot, resolved)) {
    return _posix(p.relative(resolved, from: packageRoot));
  }
  if (projectRoot != null) {
    final resolvedRoot = _resolve(projectRoot);
    if (p.isWithin(resolvedRoot, resolved)) {
      return _posix(p.relative(resolved, from: resolvedRoot));
    }
  }
  return _posix(resolved);
}

/// The path with its symlinks resolved — macOS /var/folders ->
/// /private/var/folders, so the walk and the relative computation agree
/// with each other. A path that cannot be resolved is used as given.
String _resolve(String path) {
  try {
    return Link(path).resolveSymbolicLinksSync();
  } catch (_) {
    // Not a link, or the path does not exist — use the path as given.
    return path;
  }
}

/// The nearest ancestor directory of [absolutePath] carrying a
/// `pubspec.yaml` — the package the file belongs to — or `null` when the
/// walk reaches the filesystem root without finding one.
String? _packageRootOf(String absolutePath) {
  var current = Directory(p.dirname(p.normalize(p.absolute(absolutePath))));
  while (true) {
    if (File(p.join(current.path, 'pubspec.yaml')).existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

String _posix(String path) => path.replaceAll(r'\', '/');
