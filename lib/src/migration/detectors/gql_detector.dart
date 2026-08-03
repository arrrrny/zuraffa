import 'dart:io';

import 'base_detector.dart';
import '../migration_models.dart';

/// Detects v5-style const-string GraphQL documents in Dart source files.
class GqlConstStringDetector extends MigrationDetector {
  @override
  String get detectorId => 'v5_gql_const_string';

  @override
  String get displayName => 'GraphQL const-string documents';

  @override
  List<String> get globs => ['lib/**/*.dart'];

  /// Pattern: gql() function calls.
  static final _gqlCallPattern = RegExp(r'gql\s*\(');

  @override
  Future<DetectorResult> detect(String projectDir) async {
    final findings = <MigrationFinding>[];
    final libDir = Directory('projectDir' + '/lib');
    if (!libDir.existsSync()) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    await for (final entity in libDir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('.g.dart') || entity.path.contains('.freezed.dart')) {
        continue;
      }

      final relativePath = _relative(entity.path, projectDir);
      if (!shouldScan(relativePath)) continue;

      final content = readFile(entity.path);
      if (content == null) continue;

      for (final match in _gqlCallPattern.allMatches(content)) {
        final line = _lineNumber(content, match.start);
        findings.add(MigrationFinding(
          message: 'GraphQL document defined as inline Dart string via gql() call',
          filePath: relativePath,
          line: line,
          ruleId: 'v5_gql_const_string',
          severity: MigrationSeverity.warning,
          suggestion: 'Extract to a .graphql file and use zfa migrate gql',
        ));
      }
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }

  String _relative(String absolute, String base) {
    final abs = absolute.replaceAll('\\', '/');
    final b = base.replaceAll('\\', '/');
    if (abs.startsWith(b)) {
      var rel = abs.substring(b.length);
      while (rel.startsWith('/')) rel = rel.substring(1);
      return rel;
    }
    return absolute;
  }

  int _lineNumber(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
  }
}
