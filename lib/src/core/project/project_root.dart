import 'dart:io';
import 'package:path/path.dart' as p;

/// Robust project root resolution for Zuraffa.
///
/// Searches upward from a starting path to find the nearest directory
/// containing a `pubspec.yaml` file, which indicates the project root.
class ProjectRoot {
  /// Resolves the current working directory, tolerating an invalid CWD.
  ///
  /// `Directory.current.path` throws [PathNotFoundException] when the process
  /// CWD is an already-removed or otherwise invalid directory (e.g. a deleted
  /// temp dir under `dart test`, or a chdir into a gone path in CI/containers).
  /// In that case we fall back to the `PWD` environment variable and then to
  /// the running script's directory instead of crashing.
  ///
  /// Exposed publicly so every command that previously read `Directory.current`
  /// directly can route through the same guarded resolver and inherit the same
  /// fallback ladder. See issue #441.
  static String safeCurrentPath() {
    try {
      return Directory.current.path;
    } catch (_) {
      final pwd = Platform.environment['PWD'];
      if (pwd != null && pwd.isNotEmpty) return pwd;
      try {
        return File(Platform.script.toFilePath()).parent.path;
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Finds the project root starting from [startPath].
  ///
  /// Returns the absolute path to the project root, or [startPath] if no
  /// project marker is found in any parent directory.
  ///
  /// [anchorDir] (issue #890) adds a second, optional project marker: the
  /// walk stops at the first ancestor containing a `pubspec.yaml` OR a
  /// direct child directory named [anchorDir] — the nearest project marker
  /// wins. The TDD commands pass `specs/` because their true project root
  /// is the directory holding `specs/<feature>/tdd/test-list.md`, and that
  /// root may carry no pubspec.yaml of its own while an ancestor (any
  /// parent workspace folder) does — the pubspec-only walk used to return
  /// the ancestor, gen scanned `<ancestor>/specs`, and the command died
  /// with a misleading `unknown behavior id`. Callers that pass no anchor
  /// keep the exact legacy pubspec-only semantics.
  static String find({String? startPath, String? anchorDir}) {
    final start = startPath ?? safeCurrentPath();
    var current = Directory(p.normalize(p.absolute(start)));

    // If the start path doesn't exist, try its parent
    if (!current.existsSync()) {
      current = current.parent;
    }

    // Walk up the directory tree looking for pubspec.yaml — or, when
    // [anchorDir] is given, the first directory carrying that marker.
    while (true) {
      final pubspecPath = p.join(current.path, 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) {
        return current.path;
      }

      if (anchorDir != null &&
          Directory(p.join(current.path, anchorDir)).existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      // Reached filesystem root without finding a project marker
      if (parent.path == current.path) {
        return p.normalize(p.absolute(start));
      }
      current = parent;
    }
  }

  /// Searches upward from [startPath] (default: the guarded CWD) for the
  /// nearest ancestor (inclusive) carrying a `pubspec.yaml` and returns that
  /// directory, or `null` when the walk reaches the filesystem root without
  /// finding one.
  ///
  /// Unlike [find] this never falls back to the start path — bug #1267:
  /// callers that must not guess a root (the generation commands `entity`,
  /// `make`, `build` write CWD-relative paths like `lib/src/domain/...`)
  /// branch on `null` and emit [noProjectFoundMessage] instead of silently
  /// scattering generated files into whatever directory the shell sat in.
  static String? findOrNull({String? startPath}) {
    final start = startPath ?? safeCurrentPath();
    var current = Directory(p.normalize(p.absolute(start)));

    if (!current.existsSync()) {
      current = current.parent;
    }

    while (true) {
      if (File(p.join(current.path, 'pubspec.yaml')).existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      // Reached filesystem root without finding a project marker.
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  /// The canonical error text emitted when the upward walk for a
  /// `pubspec.yaml` finds nothing (bug #1267 assessment — the exact string
  /// is part of the fix's contract).
  static const String noProjectFoundMessage =
      'No Flutter project found. Run from inside a project directory '
      'or use -C <path>.';

  /// Finds the project root and validates it exists.
  ///
  /// Throws [StateError] if the resolved root does not exist.
  static String findOrThrow({String? startPath}) {
    final root = find(startPath: startPath);
    if (!Directory(root).existsSync()) {
      throw StateError(
        'Project root does not exist: $root (resolved from ${startPath ?? safeCurrentPath()})',
      );
    }
    return root;
  }
}
