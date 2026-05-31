import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';

void main() {
  late PluginRegistry registry;

  setUp(() {
    registry = PluginRegistry();
    registry.registerAll([
      _FakePlugin('usecase'),
      _FakePlugin('repository'),
      _FakePlugin('datasource', dependsOn: const ['repository']),
      _FakePlugin('view'),
      _FakePlugin('presenter'),
      _FakePlugin('controller'),
      _FakePlugin('state'),
      _FakePlugin('di', configKey: 'diByDefault'),
      _FakePlugin('route', configKey: 'routeByDefault'),
      _FakePlugin('test', configKey: 'testByDefault'),
    ]);
  });

  test(
    'resolves preset, aliases, defaults, exclusions, and dependency order',
    () {
      final resolver = PlanResolver(
        registry: registry,
        config: ZfaConfig(diByDefault: true, routeByDefault: true),
        pluginConfig: PluginConfig(disabled: {'test'}),
      );

      final plan = resolver.resolve(
        name: 'Product',
        options: {
          'preset': 'crud',
          'with': ['vpc'],
          'without': ['route'],
        },
      );

      expect(plan.preset, 'crud');
      expect(
        plan.pluginIds,
        equals([
          'usecase',
          'repository',
          'datasource',
          'view',
          'presenter',
          'controller',
          'di',
        ]),
      );
      expect(plan.executionOrder, plan.pluginIds);
      expect(plan.warnings, isEmpty);
    },
  );

  test('warns when unknown preset or plugin is requested', () {
    final resolver = PlanResolver(registry: registry);

    final plan = resolver.resolve(
      name: 'Product',
      explicitPluginIds: const ['unknown-plugin'],
      options: const {'preset': 'missing-preset'},
    );

    expect(plan.pluginIds, isEmpty);
    expect(plan.warnings, hasLength(2));
    expect(plan.warnings.join(' '), contains('Unknown preset'));
    expect(plan.warnings.join(' '), contains('Unknown plugin'));
  });

  test('infers plugin selection from generator-style option flags', () {
    final resolver = PlanResolver(registry: registry);

    final plan = resolver.resolve(
      name: 'Order',
      options: const {
        'methods': ['get'],
        'data': true,
        'vpcs': true,
        'state': true,
      },
    );

    expect(
      plan.pluginIds,
      equals([
        'usecase',
        'repository',
        'datasource',
        'view',
        'presenter',
        'controller',
        'state',
      ]),
    );
  });
}

class _FakePlugin extends ZuraffaPlugin {
  @override
  final String id;

  @override
  final List<String> dependsOn;

  final String? _configKey;

  _FakePlugin(this.id, {this.dependsOn = const [], String? configKey})
    : _configKey = configKey;

  @override
  String? get configKey => _configKey;

  @override
  String get name => id;

  @override
  String get version => '1.0.0';
}
