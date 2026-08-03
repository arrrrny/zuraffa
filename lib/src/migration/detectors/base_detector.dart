import 'dart:io';
import 'package:meta/meta.dart';

import '../migration_models.dart';

/// Base class for all v5 pattern detectors.
///
/// Subclasses scan the project tree for specific v5 patterns and
/// return a [DetectorResult] with any findings.
abstract class MigrationDetector {
  String get detectorId;

  String get displayName;

  Future<DetectorResult> detect(String projectDir);

  List<String> get globs;

  bool shouldScan(String relativePath) {
    for (final pattern in globs) {
      if (_matchesGlob(relativePath, pattern)) return true;
    }
    return false;
  }

  static bool _matchesGlob(String path, String pattern) {
    final p = path.replaceAll('\\', '/');
    final pat = pattern.replaceAll('\\', '/');
    if (pat == '**' || pat == '*') return true;
    if (pat.startsWith('**/')) {
      return p.endsWith(pat.substring(3)) || p.contains(pat.substring(2));
    }
    if (pat.endsWith('/**')) {
      return p.startsWith(pat.substring(0, pat.length - 3));
    }
    return p == pat ||
        (p.startsWith(pat) && p.length > pat.length && p[pat.length] == '/');
  }

  @protected
  String? readFile(String absolutePath) {
    final file = File(absolutePath);
    if (!file.existsSync()) return null;
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }
}
