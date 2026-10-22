// The portable form of a subject artifact's path.
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
// The portable form names the anchor's PACKAGE and the path inside it:
//
//   // composed against: U-001 (lib/tdd/002-subscription-error-vocabulary/u1_subject.dart)
//   // composed against: U-001 (packages/app:lib/tdd/002-subscription-error-vocabulary/u1_subject.dart)
//
// The first form is the flat layout — the package IS the project root, so
// no qualifier is needed. The second names a package that sits below the
// project root: the part before the `:` is the package's directory
// relative to the project root, the part after it is the path inside that
// package. Either way the reader resolves the path from the project root,
// and an anchor that lives in a DIFFERENT package than the composed
// subject is unambiguous.
//
// A file outside the project root has no portable form: it is rendered as
// `<outside-project>/<basename>`, never as a machine-absolute path.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'path_canonicalizer.dart';

/// The portable form of [path] for a composed subject's header.
///
/// [projectRoot] is the base every path is resolved against — the project
/// the composition runs in. The result is never absolute:
///
/// - a file inside a package below the project root: the package's
///   directory relative to the project root, a `:`, and the path inside
///   that package (`packages/app:lib/tdd/900/u1_subject.dart`); the
///   qualifier is omitted when the package IS the project root
///   (`lib/tdd/900/u1_subject.dart`);
/// - a file inside the project root that no package owns: the path
///   relative to the project root;
/// - a file outside the project root: `<outside-project>/<basename>`.
Future<String> packageRelativePath(
  String path, {
  required String projectRoot,
}) async {
  final resolved = await canonicalizeMissingPath(p.normalize(p.absolute(path)));
  final root = await canonicalizeMissingPath(
    p.normalize(p.absolute(projectRoot)),
  );

  if (!p.isWithin(root, resolved)) {
    // Outside the project root there is no base to be relative to — and
    // the absolute path is exactly the leak issue #1983 is about.
    return '<outside-project>/${p.basename(resolved)}';
  }

  final packageRoot = _packageRootOf(resolved, bound: root);
  if (packageRoot == null) {
    // No package below the project root owns the file: the project-root
    // relative path is the only portable form there is.
    return _posix(p.relative(resolved, from: root));
  }
  final insidePackage = _posix(p.relative(resolved, from: packageRoot));
  final packageDir = _posix(p.relative(packageRoot, from: root));
  if (packageDir == '.') return insidePackage;
  return '$packageDir:$insidePackage';
}

/// The nearest ancestor directory of [absolutePath] carrying a
/// `pubspec.yaml` — the package the file belongs to — or `null` when no
/// package at or below [bound] owns it.
///
/// The walk is BOUNDED by [bound]: an ancestor `pubspec.yaml` above the
/// project root belongs to another workspace (or to the user's home
/// directory), and relativizing to it would put a machine-specific prefix
/// back into the header in a different shape.
String? _packageRootOf(String absolutePath, {required String bound}) {
  var current = Directory(p.dirname(p.normalize(absolutePath)));
  while (true) {
    if (File(p.join(current.path, 'pubspec.yaml')).existsSync()) {
      return current.path;
    }
    if (p.equals(current.path, bound)) return null;
    if (!p.isWithin(bound, current.path)) return null;
    current = current.parent;
  }
}

String _posix(String path) => path.replaceAll(r'\', '/');
