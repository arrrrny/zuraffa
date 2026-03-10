import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/core/plugin_system/plan_store.dart';
import 'package:path/path.dart' as path;

void main() {
  group('EffectReport & Effect', () {
    test('Effect serialization', () {
      final effect = Effect(
        file: 'lib/main.dart',
        action: 'create',
        diff: 'some diff',
      );
      final json = effect.toJson();
      expect(json['file'], 'lib/main.dart');
      expect(json['action'], 'create');
      expect(json['diff'], 'some diff');
    });

    test('EffectReport serialization', () {
      final effect = Effect(file: 'lib/main.dart', action: 'create');
      final report = EffectReport(
        planId: 'plan_1',
        pluginId: 'plugin_1',
        capabilityName: 'create_test',
        args: {'name': 'Test'},
        changes: [effect],
        message: 'Success',
      );

      final json = report.toJson();
      expect(json['plan_id'], 'plan_1');
      expect(json['plugin_id'], 'plugin_1');
      expect(json['capability_name'], 'create_test');
      expect(json['args']['name'], 'Test');
      expect(json['valid'], true);
      expect(json['message'], 'Success');
      expect(json['changes'], isList);
      expect(json['changes'].length, 1);
      expect(json['changes'][0]['file'], 'lib/main.dart');
    });
  });

  group('PlanStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zuraffa_plan_test_');
      PlanStore.instance.rootDirectory = tempDir.path;
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      PlanStore.instance.rootDirectory = null;
    });

    test('savePlan creates file with correct content', () async {
      final report = EffectReport(
        planId: 'plan_123',
        pluginId: 'test_plugin',
        capabilityName: 'test_cap',
        args: {'key': 'value'},
        changes: [Effect(file: 'test.dart', action: 'create')],
      );

      await PlanStore.instance.savePlan(report);

      final planFile = File(
        path.join(tempDir.path, '.zuraffa', 'plans', 'plan_123.json'),
      );
      expect(planFile.existsSync(), isTrue);

      final content = await planFile.readAsString();
      expect(content, contains('plan_123'));
      expect(content, contains('test_plugin'));
    });

    test('loadPlan retrieves saved plan', () async {
      final report = EffectReport(
        planId: 'plan_456',
        pluginId: 'test_plugin',
        capabilityName: 'test_cap',
        args: {'foo': 'bar'},
        changes: [Effect(file: 'test.dart', action: 'modify', diff: 'diff')],
      );

      await PlanStore.instance.savePlan(report);

      final loaded = await PlanStore.instance.loadPlan('plan_456');
      expect(loaded, isNotNull);
      expect(loaded!.planId, 'plan_456');
      expect(loaded.pluginId, 'test_plugin');
      expect(loaded.capabilityName, 'test_cap');
      expect(loaded.args['foo'], 'bar');
      expect(loaded.changes.length, 1);
      expect(loaded.changes.first.file, 'test.dart');
      expect(loaded.changes.first.action, 'modify');
      expect(loaded.changes.first.diff, 'diff');
    });

    test('loadPlan returns null for non-existent plan', () async {
      final loaded = await PlanStore.instance.loadPlan('non_existent');
      expect(loaded, isNull);
    });

    test('deletePlan removes file', () async {
      final report = EffectReport(
        planId: 'plan_789',
        pluginId: 'test_plugin',
        capabilityName: 'test_cap',
        args: {},
        changes: [],
      );

      await PlanStore.instance.savePlan(report);

      final planFile = File(
        path.join(tempDir.path, '.zuraffa', 'plans', 'plan_789.json'),
      );
      expect(planFile.existsSync(), isTrue);

      await PlanStore.instance.deletePlan('plan_789');
      expect(planFile.existsSync(), isFalse);
    });
  });
}
