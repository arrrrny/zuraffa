import 'dart:io';

import 'base_detector.dart';
import '../migration_models.dart';

/// Detects v5-style mixed state classes that lack the v6 DomainState/ViewState split.
///
/// v5 pattern: A single `XxxState` class with both domain data fields
/// (entity references) and UI state fields (isLoading, error).
/// v6 pattern: `XxxDomainState` (data only, bound to UseCase slices) +
/// `XxxViewState` (transient UI state: tabs, scroll position).
class StateDetector extends MigrationDetector {
  @override
  String get detectorId => 'v5_mixed_state';

  @override
  String get displayName => 'Mixed state (needs DomainState + ViewState split)';

  @override
  List<String> get globs => ['lib/**/*_state.dart'];

  @override
  Future<DetectorResult> detect(String projectDir) async {
    final findings = <MigrationFinding>[];
    final libDir = Directory('$projectDir/lib');
    if (!libDir.existsSync()) {
      return DetectorResult(detectorId: detectorId, findings: findings);
    }

    await for (final entity in libDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('_state.dart')) continue;
      if (entity.path.contains('domain_state') || entity.path.contains('view_state')) {
        continue;
      }
      if (entity.path.contains('.g.dart') || entity.path.contains('.freezed.dart')) {
        continue;
      }

      final relativePath = _relative(entity.path, projectDir);
      final content = readFile(entity.path);
      if (content == null) continue;

      final analysis = _analyzeStateFile(content);
      if (analysis.needsMigration) {
        findings.add(MigrationFinding(
          message: 'Mixed state class `${analysis.className}` contains both domain data '
              '(${analysis.domainFieldCount} fields) and UI state '
              '(${analysis.uiFieldCount} fields). Consider splitting into '
              'DomainState + ViewState for v6.',
          filePath: relativePath,
          line: analysis.classLine,
          ruleId: 'v5_mixed_state',
          severity: MigrationSeverity.warning,
          suggestion: 'Run `zfa migrate state` to generate DomainState + ViewState',
        ));
      }
    }

    return DetectorResult(detectorId: detectorId, findings: findings);
  }

  _StateAnalysis _analyzeStateFile(String content) {
    String? className;
    int classLine = 0;
    int domainFieldCount = 0;
    int uiFieldCount = 0;

    final classMatch = RegExp(r'class\s+(\w+State)\b').firstMatch(content);
    if (classMatch != null) {
      className = classMatch.group(1);
      classLine = _lineNumber(content, classMatch.start);
    }

    if (className == null) {
      return _StateAnalysis(
        className: '<unknown>',
        classLine: 0,
        domainFieldCount: 0,
        uiFieldCount: 0,
        needsMigration: false,
      );
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      final fieldMatch = RegExp(
        r'^(?:final\s+)?(\w+(?:<[^>]+>)?)\s+(\w+)\s*[;=]'
      ).firstMatch(trimmed);
      if (fieldMatch == null) continue;

      final type = fieldMatch.group(1)!;
      final name = fieldMatch.group(2)!;
      if (name.startsWith('_')) continue;

      if (_isUiField(type, name)) {
        uiFieldCount++;
      } else {
        domainFieldCount++;
      }
    }

    return _StateAnalysis(
      className: className,
      classLine: classLine,
      domainFieldCount: domainFieldCount,
      uiFieldCount: uiFieldCount,
      needsMigration: domainFieldCount > 0 && uiFieldCount > 0,
    );
  }

  bool _isUiField(String type, String name) {
    if ((type == 'bool' || type == 'bool?') && (name.startsWith('is') || name.startsWith('has'))) return true;
    if (name == 'error' || type == 'AppFailure?' || type == 'AppFailure') return true;
    if (name == 'isLoading' || name == 'isRefreshing') return true;
    if (name == 'offset' || name == 'limit' || name == 'hasMore') return true;
    return false;
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

class _StateAnalysis {
  final String className;
  final int classLine;
  final int domainFieldCount;
  final int uiFieldCount;
  final bool needsMigration;

  const _StateAnalysis({
    required this.className,
    required this.classLine,
    required this.domainFieldCount,
    required this.uiFieldCount,
    required this.needsMigration,
  });
}
