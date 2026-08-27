import 'package:path/path.dart' as p;

import '../core/context/file_system.dart';
import '../core/dependencies/dependency_wirer.dart';

/// The framework flavor of the *target* project being generated into.
///
/// Used by the presentation-layer generators (controller/presenter/view) to
/// avoid emitting Flutter-dependent code into a pure-Dart package, which
/// violates Constitution VII (Engine Purity) and breaks `dart analyze`.
enum ProjectFlavor {
  /// pubspec.yaml declares a `flutter:` SDK dependency.
  flutter,

  /// pubspec.yaml exists but does not declare a `flutter:` dependency.
  pureDart,

  /// No pubspec.yaml was found while walking up from [startDir].
  ///
  /// Treated as "legacy / unknown" — consumers should fall back to the
  /// historical Flutter-first generation so existing behavior (and tests
  /// that run without a pubspec) is preserved.
  unknown,
}

/// Walks up from [startDir] looking for the nearest `pubspec.yaml` and reports
/// whether the target project is a Flutter project.
///
/// - A `pubspec.yaml` declaring `flutter:` → [ProjectFlavor.flutter].
/// - A `pubspec.yaml` without `flutter:` → [ProjectFlavor.pureDart].
/// - No `pubspec.yaml` found (or unreadable) → [ProjectFlavor.unknown].
///
/// Mirrors [DependencyWirer.isFlutterProject]'s conservative default for
/// unreadable content.
Future<ProjectFlavor> detectProjectFlavor(
  String startDir,
  FileSystem fs,
) async {
  var dir = p.canonicalize(startDir);
  while (true) {
    final pubspecPath = p.join(dir, 'pubspec.yaml');
    if (await fs.exists(pubspecPath)) {
      try {
        final content = await fs.read(pubspecPath);
        return DependencyWirer.isFlutterProject(content)
            ? ProjectFlavor.flutter
            : ProjectFlavor.pureDart;
      } catch (_) {
        return ProjectFlavor.unknown;
      }
    }
    final parent = p.dirname(dir);
    if (parent == dir) return ProjectFlavor.unknown;
    dir = parent;
  }
}
