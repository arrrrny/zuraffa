import 'dart:io';

import 'base_detector.dart';
import '../migration_models.dart';

/// Detects `dependency_overrides` in `pubspec.yaml` that are v5-specific.
class DependencyOverridesDetector extends MigrationDetector {
  @override
  String get detectorId => 'v5_dependency_overrides';

  @override
  String get displayName => 'v5 dependency_overrides in pubspec.yaml';

  @override
  List<String> get globs => ['pubspec.yaml'];

  @override
  Future<DetectorResult> detect(String projectDir) async {
    final findings = <MigrationFinding>[];
    final pubspecFile = File('$projectDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    final content = readFile(pubspecFile.path);
    if (content == null) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    final inDepOverrides = _findDependencyOverridesSection(content);
    if (inDepOverrides == null) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    final sectionStart = content.indexOf(inDepOverrides);
    final sectionLines = inDepOverrides.split('\n');
    for (int i = 0; i < sectionLines.length; i++) {
      final line = sectionLines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final overrideMatch = RegExp(r'^(\w[\w-]*):\s*(.+)').firstMatch(line);
      if (overrideMatch != null) {
        final package = overrideMatch.group(1)!;
        final version = overrideMatch.group(2)!.trim();

        if (package == 'analyzer') {
          findings.add(MigrationFinding(
            message: 'dependency_overrides: analyzer: $version is a v5 zorphy 1.x workaround',
            filePath: 'pubspec.yaml',
            line: _lineNumber(content, sectionStart) + i + 1,
            ruleId: 'v5_dependency_overrides',
            severity: MigrationSeverity.warning,
            suggestion: 'Remove if zorphy 2.0 is in use',
          ));
        } else {
          findings.add(MigrationFinding(
            message: 'dependency_overrides: $package: $version',
            filePath: 'pubspec.yaml',
            line: _lineNumber(content, sectionStart) + i + 1,
            ruleId: 'v5_dependency_overrides',
            severity: MigrationSeverity.info,
          ));
        }
      }
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }

  String? _findDependencyOverridesSection(String content) {
    final match = RegExp(
      r'^dependency_overrides:\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;

    final after = content.substring(match.end);
    final endMatch = RegExp(r'^\S', multiLine: true).firstMatch(after);
    if (endMatch == null) return after.trimRight();
    return after.substring(0, endMatch.start).trimRight();
  }

  int _lineNumber(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
  }
}