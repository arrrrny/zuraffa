/// TDD feature-path resolution (issue #1182).
///
/// The bug extension's TDD mode (spec-whole for bugs) pins
/// `.specify/feature.json` → `feature_directory: .specify/bugs/<slug>`
/// and expects the TDD commands to operate on that directory.
/// `plan_command.dart` used to hardcode `<root>/specs/<feature>/spec.md`,
/// which forced the undocumented `specs/bug-<slug>` symlink bridge — and
/// any tool resolving paths through that bridge reported odd relative
/// paths.
///
/// The SUPPORTED shapes (the documented contract):
///
///  1. `<name>`                → `<root>/specs/<name>` — the legacy
///     shape, unchanged for every plain feature name (no separator).
///  2. `specs/<name>`          → `<root>/specs/<name>` — the canonical
///     path format the docs and error messages show; matches run's
///     `stripSpecsPrefix` semantics.
///  3. `.specify/bugs/<slug>`  → `<root>/.specify/bugs/<slug>` — the bug
///     extension's `feature_directory` pin; no symlink bridge needed
///     (issue #1182).
///  4. an absolute path        → used as-is (normalized).
///
/// Any other relative shape keeps the legacy `<root>/specs/<raw>`
/// resolution so the caller's "spec not found" message names the same
/// path it always did for garbage input.
///
/// The canonical feature NAME carried by artifacts (test-list rows,
/// receipts, traceability labels) is the reference itself for a plain
/// name and the directory BASENAME for a path reference — `specs/020-foo`
/// and `020-foo` name the same feature. Bug features resolved directly
/// keep the slug as their name; downstream bug detection stays on
/// `CompositionTargets.isBugFeatureDir`, which recognizes both the `bug-`
/// basename prefix and a real `.specify/bugs/` path segment.
library;

import 'package:path/path.dart' as p;

/// The resolved location of a TDD feature: the directory that holds
/// `spec.md` and `tdd/`, plus the canonical feature NAME the artifacts
/// carry.
class ResolvedFeatureDir {
  /// The feature directory on disk (normalized; absolute when the
  /// reference was absolute).
  final String dir;

  /// The canonical feature name for receipts, rows and labels.
  final String name;

  const ResolvedFeatureDir({required this.dir, required this.name});
}

/// The single resolver every TDD command routes its `<feature>` argument
/// through (issue #1182).
abstract final class TddFeaturePaths {
  /// Resolves [featureRef] against [projectRoot].
  ///
  /// Pure path computation — no filesystem access, no existence checks:
  /// the caller reports "spec not found" against the returned [dir] so
  /// the message names the path the user actually referenced.
  static ResolvedFeatureDir resolve({
    required String projectRoot,
    required String featureRef,
  }) {
    // 1. Plain name: a single, separator-free segment keeps the legacy
    //    specs/ location. Mirrors `validateFeatureSegment`'s stance that
    //    a feature reference without separators is one directory name.
    final isPlain =
        !featureRef.contains('/') &&
        !featureRef.contains(r'\') &&
        featureRef != '.' &&
        featureRef != '..';
    if (isPlain) {
      return ResolvedFeatureDir(
        dir: p.join(projectRoot, 'specs', featureRef),
        name: featureRef,
      );
    }

    final normalized = p.normalize(featureRef);

    // 2. Absolute path: used as-is (normalized). The basename is the
    //    canonical name.
    if (p.isAbsolute(featureRef)) {
      return ResolvedFeatureDir(dir: normalized, name: p.basename(normalized));
    }

    // 3. Documented relative shapes: `specs/<name>` (run's
    //    stripSpecsPrefix semantics, backslash-aware for parity) and the
    //    bug extension's `.specify/bugs/<slug>` pin (issue #1182).
    final unified = normalized.replaceAll(r'\', '/');
    final isSpecsRef = unified == 'specs' || unified.startsWith('specs/');
    final isBugRef = unified.startsWith('.specify/bugs/');
    if (isSpecsRef || isBugRef) {
      return ResolvedFeatureDir(
        dir: p.join(projectRoot, normalized),
        name: p.basename(normalized),
      );
    }

    // 4. Undeclared relative shape: keep the legacy resolution so the
    //    caller's "spec not found" message names the path the command
    //    always reported for garbage input.
    return ResolvedFeatureDir(
      dir: p.join(projectRoot, 'specs', featureRef),
      name: featureRef,
    );
  }
}
