import 'dart:io';

import 'base_detector.dart';
import '../migration_models.dart';

/// Detects manual `get_it` registration patterns that should use
/// `@Datasource` / `@Repository` annotations in v6.
class ManualDiDetector extends MigrationDetector {
  @override
  String get detectorId => 'v5_manual_di';

  @override
  String get displayName => 'Manual get_it DI registrations';

  @override
  List<String> get globs => ['lib/**/*.dart'];

  static final _getItRegisterPattern = RegExp(
    r'getIt\.(registerLazySingleton|registerSingleton|registerFactory|registerLazyFactory)\s*<',
  );

  static final _locatorRegisterPattern = RegExp(
    r'locator\.(registerLazySingleton|registerSingleton|registerFactory|registerLazyFactory)\s*<',
  );

  static final _getItInstancePattern = RegExp(r'GetIt\.instance(?:<[^>]+>)?');

  @override
  Future<DetectorResult> detect(String projectDir) async {
    final findings = <MigrationFinding>[];
    final libDir = Directory('$projectDir/lib');
    if (!libDir.existsSync()) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    await for (final entity in libDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart')) {
        continue;
      }

      final relativePath = relativePathOf(entity.path, projectDir);
      if (!shouldScan(relativePath)) continue;

      final content = readFile(entity.path);
      if (content == null) continue;

      for (final match in _getItRegisterPattern.allMatches(content)) {
        final line = lineNumberAt(content, match.start);
        findings.add(
          MigrationFinding(
            message: 'Manual getIt registration found',
            filePath: relativePath,
            line: line,
            ruleId: 'v5_manual_di',
            severity: MigrationSeverity.info,
            suggestion: 'Consider using @Datasource/@Repository annotations',
          ),
        );
      }

      for (final match in _locatorRegisterPattern.allMatches(content)) {
        final line = lineNumberAt(content, match.start);
        findings.add(
          MigrationFinding(
            message: 'Manual locator registration found',
            filePath: relativePath,
            line: line,
            ruleId: 'v5_manual_di',
            severity: MigrationSeverity.info,
            suggestion: 'Consider using @Datasource/@Repository annotations',
          ),
        );
      }

      for (final match in _getItInstancePattern.allMatches(content)) {
        final line = lineNumberAt(content, match.start);
        findings.add(
          MigrationFinding(
            message: 'GetIt.instance service location call found',
            filePath: relativePath,
            line: line,
            ruleId: 'v5_manual_di',
            severity: MigrationSeverity.info,
            suggestion:
                'In v6, prefer constructor injection over service location',
          ),
        );
      }
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }
}
