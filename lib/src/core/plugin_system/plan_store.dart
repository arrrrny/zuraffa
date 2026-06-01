import 'dart:convert';
import 'dart:io';

import '../project/project_paths.dart';
import 'capability.dart';

/// Manages storage and retrieval of execution plans.
class PlanStore {
  static final PlanStore _instance = PlanStore._();
  static PlanStore get instance => _instance;

  // For testing
  String? _rootDirectory;
  set rootDirectory(String? path) => _rootDirectory = path;

  PlanStore._();

  ProjectPaths _paths(String? baseDir) =>
      ProjectPaths(baseDir ?? _rootDirectory ?? Directory.current.path);

  File _getPlanFile(String planId, {String? baseDir}) =>
      _paths(baseDir).planFile(planId);

  File _getLegacyPlanFile(String planId, {String? baseDir}) =>
      _paths(baseDir).legacyPlanFile(planId);

  Future<void> savePlan(EffectReport report, {String? baseDir}) async {
    final file = _getPlanFile(report.planId, baseDir: baseDir);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(report.toJson()));
  }

  Future<EffectReport?> loadPlan(String planId, {String? baseDir}) async {
    final currentFile = _getPlanFile(planId, baseDir: baseDir);
    final legacyFile = _getLegacyPlanFile(planId, baseDir: baseDir);
    final file = currentFile.existsSync() ? currentFile : legacyFile;
    if (!file.existsSync()) {
      return null;
    }
    final json = jsonDecode(await file.readAsString());
    return EffectReport(
      planId: json['plan_id'],
      pluginId: json['plugin_id'],
      capabilityName: json['capability_name'],
      args: json['args'],
      changes: (json['changes'] as List)
          .map(
            (e) => Effect(
              file: e['file'],
              action: e['action'],
              diff: e['diff'],
              previousContent: e['previous_content'],
            ),
          )
          .toList(),
      isValid: json['valid'] ?? true,
      message: json['message'],
    );
  }

  Future<void> deletePlan(String planId, {String? baseDir}) async {
    final files = [
      _getPlanFile(planId, baseDir: baseDir),
      _getLegacyPlanFile(planId, baseDir: baseDir),
    ];
    for (final file in files) {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
