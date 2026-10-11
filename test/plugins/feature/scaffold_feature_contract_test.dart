// Spec 1098 — FeaturePlugin contract validation tests.
//
// Gap 5: FeaturePlugin validates only `name: string` (scaffold capability)
// — no existence check, no boundary knowledge. Materialization step 5: the
// capability validates the name against a KNOWN FeatureContract and passes
// the contract (not the string) into buildContext.
//
// Back-compat rule under test: when a project declares NO feature contracts
// (no specs/*/contract.yaml), scaffolding is unvalidated exactly as before.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_manager.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/plugins/feature/capabilities/scaffold_feature_capability.dart';
import 'package:zuraffa/src/plugins/feature/feature_plugin.dart';

const _loginContractYaml = '''
id: login
display_name: Login
entities:
  - User
  - Session
routes:
  - /login
boundary:
  type_name: LoginRepository
  interface_file: lib/src/domain/repositories/login_repository.dart
''';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_scaffold_contract_');
    await File(
      p.join(workspace.path, 'pubspec.yaml'),
    ).writeAsString('name: contract_probe\nenvironment:\n  sdk: ^3.11.0\n');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  ScaffoldFeatureCapability capability(String root) =>
      ScaffoldFeatureCapability(
        FeaturePlugin(outputDir: 'lib/src', options: GeneratorOptions()),
        projectRoot: root,
      );

  group('scaffold validates name against known contracts (gap 5)', () {
    test('unknown feature with contracts present → plan is invalid', () async {
      final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
      await specDir.create(recursive: true);
      await File(
        p.join(specDir.path, 'contract.yaml'),
      ).writeAsString(_loginContractYaml);

      final report = await capability(
        workspace.path,
      ).plan({'name': 'nonexistent'});

      expect(report.isValid, isFalse);
      expect(
        report.message,
        contains('login'),
        reason: 'the failure must list the known contract ids',
      );
      expect(report.message, contains('nonexistent'));
    });

    test('unknown feature with contracts present → execute refuses', () async {
      final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
      await specDir.create(recursive: true);
      await File(
        p.join(specDir.path, 'contract.yaml'),
      ).writeAsString(_loginContractYaml);

      final result = await capability(
        workspace.path,
      ).execute({'name': 'nonexistent'});

      expect(result.success, isFalse);
      expect(result.message, contains('nonexistent'));
    });

    test('known feature passes validation and plans successfully', () async {
      final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
      await specDir.create(recursive: true);
      await File(
        p.join(specDir.path, 'contract.yaml'),
      ).writeAsString(_loginContractYaml);

      final report = await capability(workspace.path).plan({'name': 'login'});

      expect(report.isValid, isTrue, reason: report.message ?? '');
    });

    test(
      'no contracts anywhere → validation stays off (back-compat)',
      () async {
        final report = await capability(
          workspace.path,
        ).plan({'name': 'anything_at_all'});

        expect(
          report.isValid,
          isTrue,
          reason:
              'a project that never declared feature contracts must keep '
              'scaffolding without enforcement',
        );
      },
    );
  });

  group('buildContext passes the contract (not the string)', () {
    test('PluginManager.buildContext accepts a typed feature contract', () {
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: workspace.path,
      );

      final login = FeatureContract(
        id: 'login',
        displayName: 'Login',
        routes: const {'/login'},
      );
      final context = manager.buildContext(
        name: 'Login',
        argResults: null,
        activePlugins: const [],
        feature: login,
      );

      expect(
        context.core.feature?.id,
        'login',
        reason:
            'plugins read the active feature from context, not from '
            'raw args',
      );
      expect(context.core.name, 'Login');
    });

    test('buildContext without a feature keeps core.feature null', () {
      final manager = PluginManager(
        registry: PluginRegistry(),
        projectRoot: workspace.path,
      );

      final context = manager.buildContext(
        name: 'Login',
        argResults: null,
        activePlugins: const [],
      );

      expect(context.core.feature, isNull);
    });
  });
}
