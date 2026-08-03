import 'dart:io';
import 'package:meta/meta.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

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
    final normalizedPath = path.replaceAll('\\', '/');
    final normalizedPattern = pattern.replaceAll('\\', '/');
    final glob = Glob(normalizedPattern);
    return glob.matches(normalizedPath);
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

  @protected
  String relativePathOf(String absolute, String base) {
    final abs = absolute.replaceAll('\\', '/');
    final b = base.replaceAll('\\', '/');
    if (abs.startsWith(b)) {
      var rel = abs.substring(b.length);
      while (rel.startsWith('/')) rel = rel.substring(1);
      return rel;
    }
    return absolute;
  }

  @protected
  int lineNumberAt(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
  }
}
