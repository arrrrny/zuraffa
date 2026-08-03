import 'dart:io';

import 'base_detector.dart';
import '../migration_models.dart';

/// Detects usage of the legacy `ControlledWidget` base class.
class ControlledWidgetDetector extends MigrationDetector {
  @override
  String get detectorId => 'v5_controlled_widget';

  @override
  String get displayName => 'Legacy ControlledWidget usage';

  @override
  List<String> get globs => ['lib/**/*.dart'];

  static final _extendsPattern = RegExp(
    r'extends\s+ControlledWidget\b',
  );

  @override
  Future<DetectorResult> detect(String projectDir) async {
    final findings = <MigrationFinding>[];
    final libDir = Directory('$projectDir/lib');
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

      for (final match in _extendsPattern.allMatches(content)) {
        final line = _lineNumber(content, match.start);
        findings.add(MigrationFinding(
          message: 'Class extends legacy ControlledWidget',
          filePath: relativePath,
          line: line,
          ruleId: 'v5_controlled_widget',
          severity: MigrationSeverity.info,
          suggestion: 'Migrate to ControlledWidgetBuilder for fine-grained rebuilds',
        ));
      }
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }

  String _relative(String absolute, String base) {
    final abs = absolute.replaceAll(r'\', '/');
    final b = base.replaceAll(r'\', '/');
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