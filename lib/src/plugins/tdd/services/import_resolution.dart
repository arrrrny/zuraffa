/// Import-resolution scanning for the TDD migration surface (issue #912
/// defect 4 remediation).
///
/// `zfa tdd migrate-paths` used to rewrite only the moved test's RELATIVE
/// subject import and report `migrated=N` success while a `package:` URI
/// import still named the pre-move location — an unloadable suite, honestly
/// reported as green. The commands now self-check: every relative and
/// self-package import of a touched test file must RESOLVE ON DISK before
/// the command may declare success, and `zfa tdd doctor` reports dangling
/// imports of recorded test files as drift prescribed to the migration.
///
/// `dart:` URIs and foreign-package URIs are always resolvable-by-fiat
/// (they resolve from the package_config, not from this tree) and are
/// skipped; a missing host pubspec disables self-package checks entirely
/// rather than guessing the package name.
library;

import 'dart:io';
import 'package:path/path.dart' as p;

/// One import URI from [unresolvedImports] that does not resolve on disk.
class ImportResolutionIssue {
  /// The import/export URI as written in the source.
  final String uri;

  /// Why it does not resolve (display form).
  final String reason;

  const ImportResolutionIssue(this.uri, this.reason);

  @override
  String toString() => '$uri ($reason)';
}

/// The import/export URIs declared by [source].
List<String> importUrisOf(String source) {
  final pattern = RegExp(
    r'''^\s*(?:import|export)\s*['"]([^'"]+)['"]''',
    multiLine: true,
  );
  return pattern.allMatches(source).map((m) => m.group(1)!).toList();
}

/// The relative and self-package imports in [source] (a file at
/// [filePath] inside the project rooted at [projectRoot]) that do NOT
/// resolve to an existing file on disk. `dart:` URIs and foreign-package
/// URIs are skipped ([packageName] null disables self-package checks).
List<ImportResolutionIssue> unresolvedImports({
  required String source,
  required String filePath,
  required String projectRoot,
  String? packageName,
}) {
  final issues = <ImportResolutionIssue>[];
  for (final uri in importUrisOf(source)) {
    if (uri.startsWith('dart:')) continue;
    if (uri.startsWith('package:')) {
      final rest = uri.substring('package:'.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) continue;
      final pkg = rest.substring(0, slash);
      if (packageName == null || pkg != packageName) continue;
      final target = p.join(projectRoot, 'lib', rest.substring(slash + 1));
      if (!File(target).existsSync()) {
        issues.add(
          ImportResolutionIssue(uri, 'package URI does not resolve under lib/'),
        );
      }
      continue;
    }
    // Relative URI (possibly `./`-prefixed). Resolve it from the file's
    // own directory.
    final rawPath = Uri.tryParse(uri)?.path ?? uri;
    final target = p.normalize(p.join(p.dirname(filePath), rawPath));
    if (!File(target).existsSync()) {
      issues.add(
        ImportResolutionIssue(uri, 'relative import does not resolve on disk'),
      );
    }
  }
  return issues;
}

/// The host package name from `<projectRoot>/pubspec.yaml`, or null when
/// the pubspec is missing/unreadable (self-package checks are then
/// disabled rather than guessed).
String? hostPackageName(String projectRoot) {
  final file = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!file.existsSync()) return null;
  try {
    final match = RegExp(
      r'^name:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(file.readAsStringSync());
    return match?.group(1);
  } on FileSystemException {
    return null;
  }
}
