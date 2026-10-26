/// The project-wiring preflight (issue #2021).
///
/// `zfa tdd run`'s loop is Dart-only: `zfa tdd gen` unconditionally
/// emits `test/<feature>/<id>_test.dart` + `lib/<feature>/<id>_subject.dart`
/// and the profile templates are `dart test` commands. On a non-Dart
/// project (a TypeScript repo carrying `package.json` and a vitest
/// profile) the run used to scaffold Dart artifacts into the repo root
/// and then die at `verify-red` on the missing `single:` template —
/// pollution with a failure the project could never fix.
///
/// This gate answers ONE question BEFORE any side effect: does the
/// project root — or ANY ancestor — carry a zuraffa/Dart wiring marker?
///
///   - `.zfa.json` — the speckit tdd-plan/tdd-run Step-0 wired marker;
///   - `pubspec.yaml` — a Dart package (the `ProjectRoot` walk marker);
///   - `dart_test.yaml` — a Dart test configuration.
///
/// Fail-open by design: the walk-up mirrors [ProjectRoot.find], so a
/// monorepo worktree whose marker lives in the workspace parent stays
/// runnable — a marker ANYWHERE up the tree answers ok, and only a tree
/// with no marker at all is refused (the TypeScript-repo shape).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The wiring markers, in check order.
const List<String> kProjectWiringMarkers = [
  '.zfa.json',
  'pubspec.yaml',
  'dart_test.yaml',
];

/// The gate verdict: [ok] when a marker was found — [marker] inside
/// [markerDir] — and not-ok when the walk reached the filesystem root
/// without finding one.
class ProjectWiringReport {
  const ProjectWiringReport({required this.ok, this.marker, this.markerDir});

  /// The not-wired verdict (the TypeScript-repo shape).
  const ProjectWiringReport.notWired() : this(ok: false);

  /// True when the project root or an ancestor carries a wiring marker.
  final bool ok;

  /// The marker file name that answered the walk ([ok] reports only).
  final String? marker;

  /// The directory (project root or ancestor) holding [marker].
  final String? markerDir;
}

/// Stateless preflight over one [projectRoot]; see the library doc for
/// the contract. Mirrors the other run preflights (`await ProjectWiring(
/// projectRoot: ...).check()`).
class ProjectWiring {
  const ProjectWiring({required this.projectRoot});

  /// The resolved project root the walk starts from (inclusive).
  final String projectRoot;

  /// Walks up from [projectRoot] to the filesystem root, returning the
  /// first directory (inclusive) that carries any of
  /// [kProjectWiringMarkers] as [ProjectWiringReport.ok]; the root itself
  /// when no marker exists anywhere up the tree.
  Future<ProjectWiringReport> check() async {
    var current = Directory(p.normalize(p.absolute(projectRoot)));
    // A start path that no longer exists (removed temp dir) walks from
    // its parent, like `ProjectRoot.find` — marker files in ancestors
    // are still checked either way.
    if (!current.existsSync()) current = current.parent;
    while (true) {
      for (final marker in kProjectWiringMarkers) {
        if (File(p.join(current.path, marker)).existsSync()) {
          return ProjectWiringReport(
            ok: true,
            marker: marker,
            markerDir: current.path,
          );
        }
      }
      final parent = current.parent;
      // Reached the filesystem root with no marker — not wired.
      if (parent.path == current.path) {
        return const ProjectWiringReport.notWired();
      }
      current = parent;
    }
  }
}
