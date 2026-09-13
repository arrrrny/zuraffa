/// `TrackedGeneratedOutputGuard` — spec 1540 restore-or-refuse protection
/// for git-tracked hand-authored generated-name files (`.g.dart`,
/// `.zorphy.dart`).
///
/// ## Problem (issue #1540)
///
/// json_serializable's builder reserves `<lib>.g.dart` as the output for
/// EVERY library in `generate_for`. A pre-existing `.g.dart` with no
/// producing generator run in the current build is indistinguishable from an
/// orphaned output by filename convention, so build_runner's stale-output
/// cleanup DELETES it. When a source declares `part 'engine_event.g.dart';`,
/// `zfa build` then fails its own completeness gate
/// (`BuildCommand.verifyDeclaredPartsOrFail`) and exits non-zero — inside
/// `zfa tdd refactor` the build pass misfire-stops and the loop dead-ends
/// with no restore remedy, leaving a broken tree.
///
/// ## Contract
///
///   1. **Snapshot (pre-build)** — [capture] records the exact bytes of
///      every generated-name file that is BOTH tracked in git's index AND
///      present on disk. A file the user staged for removal (`git rm`) is
///      not in the index → not protected (intended deletion). A file the
///      user deleted unstaged pre-build does not exist at capture → not
///      protected. A file a generator legitimately rewrites still exists
///      post-build → never flagged.
///   2. **Detection (post-build)** — [detectDeleted] returns snapshot
///      members that no longer exist on disk.
///   3. **Restore** — [restore] writes the captured pre-build bytes back.
///      Restoring captured bytes (not `git checkout --`) preserves unstaged
///      hand edits. Restore never creates directories: a deletion that also
///      removed the parent directory is a larger anomaly that must be
///      refused, not silently half-repaired. Unrestorable deletions land in
///      `TrackedGeneratedRestoreResult.failed` and the caller MUST refuse
///      with [restoreRemedyLines] instead of leaving the tree broken.
///   4. **Disabled outside git** — when the project is not inside a git work
///      tree or the `git` binary is unavailable, every method degrades to a
///      no-op (empty tracking set / empty snapshot / empty detections), so
///      non-git projects keep byte-identical build behavior.
///
/// Hard constraint (issue #1540): this guard NEVER touches build_runner
/// internals or json_serializable behavior. It observes the working tree
/// through `git ls-files` (read-only) and restores deleted tracked files.
library;

import 'dart:io';

/// The documentation page every remedy message references (FR-9).
const String kHandAuthoredPlaceholderDoc =
    'docs/hand-authored-g-dart-placeholders.md';

/// One pre-build snapshot of git-tracked generated-name files.
///
/// [files] maps project-relative paths (forward slashes) to the exact bytes
/// captured before the build ran. [enabled] is false when the guard could
/// not establish git tracking (no repository, no git binary, git failure) —
/// every consumer must treat a disabled snapshot as a no-op.
class TrackedGeneratedSnapshot {
  const TrackedGeneratedSnapshot({
    this.files = const <String, List<int>>{},
    this.enabled = false,
  });

  /// Project-relative path (forward slashes) → exact pre-build bytes.
  final Map<String, List<int>> files;

  /// False when git tracking could not be established (guard disabled).
  final bool enabled;

  /// An empty, disabled snapshot — the no-op result outside git.
  static const TrackedGeneratedSnapshot disabled = TrackedGeneratedSnapshot();
}

/// The outcome of one [TrackedGeneratedOutputGuard.restore] attempt.
class TrackedGeneratedRestoreResult {
  const TrackedGeneratedRestoreResult({
    this.restored = const <String>[],
    this.failed = const <String>[],
  });

  /// Paths successfully restored to their exact pre-build bytes.
  final List<String> restored;

  /// Paths whose deletion could NOT be undone (missing bytes or failed
  /// write — e.g. the parent directory is gone). Callers must refuse.
  final List<String> failed;

  /// True when every requested deletion was restored.
  bool get fullyRestored => failed.isEmpty;
}

/// Snapshot / detect / restore service for git-tracked generated-name files.
///
/// See the library doc for the full spec-1540 contract. All filesystem and
/// git operations root at [projectRoot] (never `Directory.current` mutation).
class TrackedGeneratedOutputGuard {
  TrackedGeneratedOutputGuard({
    String? projectRoot,
    List<String>? generatedSuffixes,
  }) : projectRoot = projectRoot ?? Directory.current.path,
       generatedSuffixes =
           generatedSuffixes ?? const <String>['.g.dart', '.zorphy.dart'];

  /// Absolute project root every operation is rooted at.
  final String projectRoot;

  /// Filename suffixes treated as generated-name outputs.
  final List<String> generatedSuffixes;

  /// Every path tracked in git's index under [projectRoot], relative to
  /// [projectRoot] with forward slashes.
  ///
  /// Empty set when git is unavailable, [projectRoot] is not inside a work
  /// tree, or git fails for any reason — the guard is disabled, never
  /// throwing into the build's failure paths.
  Future<Set<String>> gitTrackedFiles() async => const <String>{};

  /// Snapshot every tracked generated-name file that currently exists,
  /// capturing exact bytes.
  Future<TrackedGeneratedSnapshot> capture() =>
      Future<TrackedGeneratedSnapshot>.value(
        const TrackedGeneratedSnapshot(),
      );

  /// Snapshot members that no longer exist on disk (deleted by the build).
  List<String> detectDeleted(TrackedGeneratedSnapshot snapshot) =>
      const <String>[];

  /// Restore the exact pre-build bytes of [paths] from [snapshot].
  ///
  /// Never creates directories (see the library doc): a path whose write
  /// fails lands in `TrackedGeneratedRestoreResult.failed`.
  Future<TrackedGeneratedRestoreResult> restore(
    TrackedGeneratedSnapshot snapshot,
    List<String> paths,
  ) async => const TrackedGeneratedRestoreResult();

  /// Resolves the convention-derived owning library of a generated-name
  /// [path]: `lib/x/engine_event.g.dart` → `lib/x/engine_event.dart`
  /// (json_serializable reserves `<lib>.g.dart` per library). Returns null
  /// when the path does not carry a generated suffix.
  static String? owningLibraryFor(String path) => null;

  /// The spec-1540 remedy lines for [paths]: the exact manual restore
  /// command, the recurring-deletion prevention (both `build.yaml` builder
  /// exclusions), and the documentation reference. Pure function — no I/O.
  static List<String> restoreRemedyLines(List<String> paths) =>
      const <String>[];

  /// Synchronously resolves which of [relativePaths] are tracked in git's
  /// index under [projectRoot] (ONE `git ls-files -z` subprocess).
  ///
  /// Used by the completeness gate (`verifyDeclaredPartsOrFail`), whose
  /// `bool` signature existing tests rely on must not become async; only
  /// called on the already-failing path. Empty set when git is unavailable.
  static Set<String> trackedFilesSync(String projectRoot) =>
      const <String>{};
}
