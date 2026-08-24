import 'dart:io';
import 'package:path/path.dart' as p;

/// Robust project root resolution for Zuraffa.
///
/// Searches upward from a starting path to find the nearest directory
/// containing a `pubspec.yaml` file, which indicates the project root.
class ProjectRoot {
  /// Finds the project root starting from [startPath].
  ///
  /// Returns the absolute path to the project root, or [startPath] if no
  /// `pubspec.yaml` is found in any parent directory.
  /// Resolves the current working directory, tolerating an invalid CWD.
  ///
  /// `Directory.current.path` throws [PathNotFoundException] when the process
  /// CWD is an already-removed or otherwise invalid directory (e.g. a deleted
  /// temp dir under `dart test`, or a chdir into a gone path in CI/containers).
  /// In that case we fall back to the `PWD` environment variable and then to
  /// the running script's directory instead of crashing.
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

  // Backwards-compatible private alias — internal call sites still use this.
  static String _safeCurrentDir() => safeCurrentPath();

  static String find({String? startPath}) {
    final start = startPath ?? _safeCurrentDir();
    var current = Directory(p.normalize(p.absolute(start)));

    // If the start path doesn't exist, try its parent
    if (!current.existsSync()) {
      current = current.parent;
    }

    // Walk up the directory tree looking for pubspec.yaml
    while (true) {
      final pubspecPath = p.join(current.path, 'pubspec.yaml');
      if (File(pubspecPath).existsSync()) {
        return current.path;
      }

      final parent = current.parent;
      // Reached filesystem root without finding pubspec.yaml
      if (parent.path == current.path) {
        return p.normalize(p.absolute(start));
      }
      current = parent;
    }
  }

  /// Finds the project root and validates it exists.
  ///
  /// Throws [StateError] if the resolved root does not exist.
  static String findOrThrow({String? startPath}) {
    final root = find(startPath: startPath);
    if (!Directory(root).existsSync()) {
      throw StateError(
        'Project root does not exist: $root (resolved from ${startPath ?? _safeCurrentDir()})',
      );
    }
    return root;
  }
}
