/// Suite-command resolution for slice suite runs (issue #1144).
///
/// The sandbox suite (`slice verify --json`) and the host suite
/// (`slice merge`) shell out to `dart test` — but a Flutter package's
/// suite can only run under `flutter test` (`dart test` cannot resolve
/// `flutter_test` from the SDK). This helper reads the package's
/// pubspec and picks the right driver, so a zik_zak-shaped host (and
/// its cut sandbox) run their real suite instead of failing on
/// resolution.
library;

import 'dart:io';

/// Whether the package rooted at [dir] is a Flutter package: its
/// pubspec.yaml declares the Flutter SDK under `dependencies:` (the
/// canonical `flutter: sdk: flutter` block).
bool isFlutterPackage(String dir) {
  final file = File('$dir/pubspec.yaml');
  if (!file.existsSync()) return false;
  var inDependencies = false;
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final isTopLevel = rawLine.startsWith(RegExp(r'\S'));
    if (isTopLevel) {
      inDependencies = line == 'dependencies:';
      continue;
    }
    if (inDependencies && line == 'flutter:') return true;
    if (inDependencies && line.startsWith('flutter:') && line.contains('sdk')) {
      return true;
    }
  }
  return false;
}

/// The test driver for the package rooted at [dir]: `flutter` when it is
/// a Flutter package, `dart` otherwise.
String suiteCommandFor(String dir) =>
    isFlutterPackage(dir) ? 'flutter' : 'dart';
