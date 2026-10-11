import 'dart:io';

import 'package:yaml/yaml.dart';

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

    final sectionInfo = _findDependencyOverridesSection(content);
    if (sectionInfo == null) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    try {
      final yaml = loadYaml(content) as YamlMap;
      final depOverrides = yaml['dependency_overrides'];
      if (depOverrides is! YamlMap) {
        return DetectorResult(detectorId: detectorId, findings: findings);
      }

      for (final entry in depOverrides.entries) {
        final package = entry.key.toString();
        final value = entry.value;

        // Determine display value
        String displayValue;
        if (value is String) {
          displayValue = value;
        } else if (value is YamlMap) {
          if (value.containsKey('path')) {
            displayValue = 'path: ${value['path']}';
          } else if (value.containsKey('git')) {
            displayValue = 'git: ${value['git']}';
          } else {
            displayValue = value.toString();
          }
        } else {
          displayValue = value.toString();
        }

        // Find the line number for this package key
        final packagePattern = RegExp(
          '^\\s*${RegExp.escape(package)}:\\s*',
          multiLine: true,
        );
        final packageMatch = packagePattern.firstMatch(
          content.substring(sectionInfo.offset),
        );
        final line = packageMatch != null
            ? lineNumberAt(content, sectionInfo.offset + packageMatch.start)
            : lineNumberAt(content, sectionInfo.offset);

        if (package == 'analyzer') {
          findings.add(
            MigrationFinding(
              message:
                  'dependency_overrides: analyzer: $displayValue is a v5 zorphy 1.x workaround',
              filePath: 'pubspec.yaml',
              line: line,
              ruleId: 'v5_dependency_overrides',
              severity: MigrationSeverity.warning,
              suggestion: 'Remove if zorphy 2.0 is in use',
            ),
          );
        } else {
          findings.add(
            MigrationFinding(
              message: 'dependency_overrides: $package: $displayValue',
              filePath: 'pubspec.yaml',
              line: line,
              ruleId: 'v5_dependency_overrides',
              severity: MigrationSeverity.info,
            ),
          );
        }
      }
    } catch (e) {
      // If YAML parsing fails, return empty findings
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }

  _Section? _findDependencyOverridesSection(String content) {
    final match = RegExp(
      r'^dependency_overrides:\s*$',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;

    final after = content.substring(match.end);
    final endMatch = RegExp(r'^\S', multiLine: true).firstMatch(after);

    final sectionText = endMatch == null
        ? after.trimRight()
        : after.substring(0, endMatch.start).trimRight();

    return _Section(text: sectionText, offset: match.end);
  }
}

class _Section {
  final String text;
  final int offset;
  const _Section({required this.text, required this.offset});
}
