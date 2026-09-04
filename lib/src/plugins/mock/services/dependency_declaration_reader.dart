/// DependencyDeclarationReader (feature 072, issue #960): loads the
/// declared External Dependencies & Contracts rows for a feature — the
/// capability's and the loop's single source of declared truth.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../tdd/models/behavior.dart' show SpecDependency;
import '../../tdd/services/spec_parser.dart';
import '../../tdd/services/test_list_reader.dart';

/// One declared row + its spec line (for refusals/provenance).
class DependencyRow {
  final String name;
  final String type;
  final String contract;
  final String? mockPriority;
  final int? specLine;

  const DependencyRow({
    required this.name,
    required this.type,
    required this.contract,
    this.mockPriority,
    this.specLine,
  });
}

class DependencyDeclarationError implements Exception {
  final String message;
  final String fix;
  const DependencyDeclarationError(this.message, {required this.fix});
}

abstract final class DependencyDeclarationReader {
  /// Load declared rows for [feature] (or the `.specify/feature.json`
  /// pinned feature when null). Throws [DependencyDeclarationError]
  /// when the feature/spec cannot be resolved.
  static Future<List<DependencyRow>> load({
    required String projectRoot,
    String? feature,
  }) async {
    final featureName = feature ?? _pinnedFeature(projectRoot);
    if (featureName == null || featureName.isEmpty) {
      throw DependencyDeclarationError(
        'no feature resolved — pass --feature or pin '
        '.specify/feature.json',
        fix: '--> fix: zfa tdd plan <feature> pins .specify/feature.json.',
      );
    }
    final featureDir = p.join(projectRoot, 'specs', featureName);
    final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!testList.existsSync()) {
      throw DependencyDeclarationError(
        'feature "$featureName" has no tdd/test-list.md',
        fix: '--> fix: run `zfa tdd plan $featureName` first.',
      );
    }
    final reader = TestListReader(featureDir);
    final List<SpecDependency> deps;
    try {
      deps = await reader.readDependencies();
    } catch (_) {
      throw DependencyDeclarationError(
        'the dependency section of specs/$featureName/tdd/test-list.md '
        'is unreadable',
        fix:
            '--> fix: re-run `zfa tdd plan $featureName` to regenerate '
            'the section, then re-run.',
      );
    }

    // Spec lines: scan spec.md for each declared name (the plan
    // artifact carries the rows; the spec carries their lines).
    final specFile = File(p.join(featureDir, 'spec.md'));
    final specLines = <String, int>{};
    if (specFile.existsSync()) {
      var lineNo = 0;
      for (final line in specFile.readAsLinesSync()) {
        lineNo++;
        for (final dep in deps) {
          final cells = line.split('|').map((c) => c.trim()).toList();
          if (cells.length > 1 && cells[1] == dep.dependency) {
            specLines.putIfAbsent(dep.dependency, () => lineNo);
          }
        }
      }
    }

    return [
      for (final d in deps)
        DependencyRow(
          name: d.dependency,
          type: d.type,
          contract: d.contract,
          mockPriority: d.mockPriority,
          specLine: specLines[d.dependency],
        ),
    ];
  }

  static String? _pinnedFeature(String projectRoot) {
    final f = File(p.join(projectRoot, '.specify', 'feature.json'));
    if (!f.existsSync()) return null;
    try {
      final json = f.readAsStringSync();
      final m = RegExp(r'"feature_directory"\s*:\s*"([^"]+)"').firstMatch(json);
      return m?.group(1);
    } on FileSystemException {
      return null;
    }
  }
}
