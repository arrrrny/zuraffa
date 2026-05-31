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
  static String find({String? startPath}) {
    final start = startPath ?? Directory.current.path;
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
        'Project root does not exist: $root (resolved from ${startPath ?? Directory.current.path})',
      );
    }
    return root;
  }
}
