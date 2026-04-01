import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'capability.dart';

/// Manages storage and retrieval of execution plans.
class PlanStore {
  static final PlanStore _instance = PlanStore._();
  static PlanStore get instance => _instance;

  // For testing
  String? _rootDirectory;
  set rootDirectory(String? path) => _rootDirectory = path;

  PlanStore._();

  File _getPlanFile(String planId, {String? baseDir}) {
    final root = baseDir ?? _rootDirectory ?? Directory.current.path;
    final planDir = path.join(root, '.zuraffa', 'plans');
    return File(path.join(planDir, '$planId.json'));
  }

  Future<void> savePlan(EffectReport report, {String? baseDir}) async {
    final file = _getPlanFile(report.planId, baseDir: baseDir);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(report.toJson()));
  }

  Future<EffectReport?> loadPlan(String planId, {String? baseDir}) async {
    final file = _getPlanFile(planId, baseDir: baseDir);
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
    final file = _getPlanFile(planId, baseDir: baseDir);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
