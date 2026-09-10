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
///
/// Issue #1471: the same resolution must hold for EVERY command in the
/// family, not only `plan` — `run` spawns `gen`/`verify-red`/`make`/
/// `refactor` children with `--feature <reference>`, so the parent hands
/// them the canonical [ResolvedFeatureDir.ref] and the children resolve it
/// back to the identical directory. A feature whose parent resolved to
/// `.specify/bugs/<slug>` must never be `specs/<slug>` for its children.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The resolved location of a TDD feature: the directory that holds
/// `spec.md` and `tdd/`, the canonical feature NAME the artifacts carry,
/// and the canonical REFERENCE that resolves back to both (issue #1471).
class ResolvedFeatureDir {
  /// The feature directory on disk (normalized; absolute when the
  /// reference was absolute).
  final String dir;

  /// The canonical feature name for receipts, rows and labels.
  final String name;

  /// The canonical reference: resolving it against the same project root
  /// yields this same [dir] and [name]. The two-cycle driver hands it to
  /// the child steps (`--feature <ref>`), so a parent run and its spawned
  /// children always agree on the feature directory (issue #1471).
  final String ref;

  const ResolvedFeatureDir({
    required this.dir,
    required this.name,
    required this.ref,
  });
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
        ref: featureRef,
      );
    }

    final normalized = p.normalize(featureRef);

    // 2. Absolute path: used as-is (normalized). The basename is the
    //    canonical name.
    if (p.isAbsolute(featureRef)) {
      return ResolvedFeatureDir(
        dir: normalized,
        name: p.basename(normalized),
        ref: normalized,
      );
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
        ref: normalized,
      );
    }

    // 4. Undeclared relative shape: keep the legacy resolution so the
    //    caller's "spec not found" message names the path the command
    //    always reported for garbage input.
    return ResolvedFeatureDir(
      dir: p.join(projectRoot, 'specs', featureRef),
      name: featureRef,
      ref: featureRef,
    );
  }

  /// True when [featureRef] is one of the four documented shapes this
  /// resolver supports — the shared gate for the per-command validators
  /// (issue #1471): a plain segment, `specs/<name>`, `.specify/bugs/<slug>`
  /// or an absolute path. Everything else stays refused: empty, `.`, `..`,
  /// a relative shape whose segments could escape the project root, and a
  /// reference with a trailing separator (`specs/`, `specs/.`) that names
  /// the specs ROOT rather than a feature. Teaching the commands the
  /// bug-directory shape therefore opens no traversal hole.
  static bool isSupportedRef(String featureRef) {
    if (featureRef.isEmpty) return false;
    final hasSeparator = featureRef.contains('/') || featureRef.contains(r'\');
    if (!hasSeparator) return featureRef != '.' && featureRef != '..';
    if (p.isAbsolute(featureRef)) return true;
    if (_hasDotDotSegment(featureRef)) return false;
    // This check has to run on the RAW reference: `p.normalize` collapses a
    // trailing separator (`specs/` → `specs`), which would make the guard
    // unreachable. A bare `specs/` names the specs ROOT, not a feature, and
    // every command refused it before issue #1471 (see
    // run_command_path_format_test.dart's "bare specs/" case).
    if (featureRef.endsWith('/') || featureRef.endsWith(r'\')) return false;
    final unified = p.normalize(featureRef).replaceAll(r'\', '/');
    // `specs` alone is only reachable through a normalizing shape such as
    // `specs/.` — the same specs root, so it is refused with `specs/`.
    return unified.startsWith('specs/') || unified.startsWith('.specify/bugs/');
  }

  /// The bug extension's feature pin (issue #1471): the directory named by
  /// `.specify/feature.json`'s `feature_directory`. Null when the pin file
  /// is absent, unreadable, malformed, or carries no usable value — a
  /// broken pin stays a miss, never a silent redirect.
  static ResolvedFeatureDir? pinned({required String projectRoot}) {
    final file = File(p.join(projectRoot, '.specify', 'feature.json'));
    if (!file.existsSync()) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
    if (decoded is! Map) return null;
    final raw = decoded['feature_directory'];
    if (raw is! String || raw.trim().isEmpty) return null;
    // Normalize before validating: a pin written with a trailing separator
    // (`specs/x/`) must still resolve. `isSupportedRef` refuses the raw
    // trailing-separator shape for user-supplied references, where `specs/`
    // names the specs root and nothing else.
    final ref = p.normalize(raw.trim());
    if (!isSupportedRef(ref)) return null;
    return resolve(projectRoot: projectRoot, featureRef: ref);
  }

  /// [resolve] plus the bug extension's pin fallback (issue #1471).
  ///
  /// The pinned `feature_directory` is consulted ONLY for a plain,
  /// separator-free name whose legacy `specs/<name>` directory does not
  /// exist, and only when the pinned directory's basename is exactly that
  /// name. An explicit path reference always resolves like [resolve]:
  /// what the caller names beats ambient state, and the pin can never
  /// hijack an unrelated feature. Filesystem access: unlike [resolve] this
  /// method stats the legacy directory and reads the pin file.
  static ResolvedFeatureDir resolveWithPin({
    required String projectRoot,
    required String featureRef,
  }) {
    final isPlain =
        featureRef.isNotEmpty &&
        !featureRef.contains('/') &&
        !featureRef.contains(r'\') &&
        featureRef != '.' &&
        featureRef != '..';
    final legacy = resolve(projectRoot: projectRoot, featureRef: featureRef);
    if (!isPlain) return legacy;
    if (Directory(legacy.dir).existsSync()) return legacy;
    final pinnedDir = pinned(projectRoot: projectRoot);
    if (pinnedDir != null && pinnedDir.name == featureRef) return pinnedDir;
    return legacy;
  }

  static bool _hasDotDotSegment(String raw) =>
      raw.split(RegExp(r'[/\\]')).contains('..');
}
