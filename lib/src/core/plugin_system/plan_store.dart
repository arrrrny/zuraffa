import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'capability.dart';

/// Manages storage and retrieval of execution plans.
class PlanStore {
  static final PlanStore _instance = PlanStore._();
  static PlanStore get instance => _instance;

  PlanStore._();

  File _getPlanFile(String planId) {
    // final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final planDir = path.join(Directory.current.path, '.zuraffa', 'plans');
    return File(path.join(planDir, '$planId.json'));
  }

  Future<void> savePlan(EffectReport report) async {
    final file = _getPlanFile(report.planId);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    await file.writeAsString(jsonEncode(report.toJson()));
  }

  Future<EffectReport?> loadPlan(String planId) async {
    final file = _getPlanFile(planId);
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
          .map((e) => Effect(
                file: e['file'],
                action: e['action'],
                diff: e['diff'],
              ))
          .toList(),
      isValid: json['valid'] ?? true,
      message: json['message'],
    );
  }
  
  Future<void> deletePlan(String planId) async {
    final file = _getPlanFile(planId);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
