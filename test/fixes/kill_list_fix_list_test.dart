// Issue #1149 (kill list, part of EPIC #1132 Machine Contract) — fix list:
//
// 1. shadcn advertised layouts `grid`/`table` but never implemented them —
//    the builder switch fell through to the list template, emitting a
//    mislabeled widget. Now only list/form are advertised and accepted.
// 2. benchmark shipped no scenarios: `zfa benchmark list/run` printed
//    "No benchmark scenarios registered." The plugin now ships
//    first-party scenarios over real zuraffa utility work.
// 3. feature: the eight copy-pasted `XxxFeatureCapability` clones are one
//    parameterized `PluginFeatureCapability`; MCP capability names
//    unchanged.
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/benchmark/benchmark_plugin.dart';
import 'package:zuraffa/src/plugins/feature/feature_plugin.dart';
import 'package:zuraffa/src/plugins/feature/capabilities/plugin_feature_capability.dart';
import 'package:zuraffa/src/plugins/feature/capabilities/scaffold_feature_capability.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/benchmark/benchmark_contract.dart';
import 'package:zuraffa/src/plugins/shadcn/shadcn_plugin.dart';
import 'package:zuraffa/src/plugins/benchmark/first_party_scenarios.dart';

void main() {
  group('shadcn advertised layouts (fix 1)', () {
    test('schema advertises exactly list and form', () {
      final plugin = ShadcnPlugin(outputDir: 'lib/src');
      final schema = plugin.configSchema;
      final layout = schema['properties']['layout'] as Map;
      expect(layout['enum'], ['list', 'form']);
    });
  });

  group('first-party benchmark scenarios (fix 2)', () {
    test('plugin ships scenarios by default (registry not empty)', () async {
      final plugin = BenchmarkPlugin();
      await plugin.discoverAndRegisterScenarios();
      final scenarios = await plugin.registry.getAll();
      expect(
        scenarios,
        isNotEmpty,
        reason:
            '`zfa benchmark list` printed "No benchmark scenarios '
            'registered." pre-fix — the framework shipped without cargo.',
      );
      expect(
        scenarios.map((s) => s.id),
        containsAll(['string-utils-casing', 'spec-library-field-emit']),
      );
    });

    test('first-party scenarios run and report real metrics', () async {
      final plugin = BenchmarkPlugin();
      await plugin.discoverAndRegisterScenarios();
      final scenarios = await plugin.registry.getAll();
      expect(scenarios, hasLength(greaterThanOrEqualTo(2)));

      for (final BenchmarkContract scenario in scenarios) {
        final result = await scenario.run({});
        expect(
          result.status,
          BenchmarkStatus.passed,
          reason: '${scenario.id} must pass with default config',
        );
        expect(
          result.metrics['operations'],
          greaterThan(0),
          reason: '${scenario.id} must report its operation count',
        );
        expect(
          result.duration,
          isNot(Duration.zero),
          reason: '${scenario.id} must measure real elapsed work',
        );
      }
    });

    test('scenario ids are kebab-case and versions semver (contract)', () {
      const provider = FirstPartyBenchmarkProvider();
      for (final scenario in provider.provideScenarios()) {
        expect(
          ScenarioValidation.validate(scenario),
          isEmpty,
          reason: '${scenario.id} must satisfy the benchmark contract',
        );
      }
    });
  });

  group('feature capabilities parameterized (fix 3)', () {
    test('eight MCP-visible capability names preserved', () {
      final plugin = FeaturePlugin(outputDir: 'lib/src');
      final names = plugin.capabilities.map((c) => c.name).toSet();
      expect(
        names,
        containsAll([
          'di',
          'view',
          'presenter',
          'controller',
          'route',
          'state',
          'mock',
          'test',
          'scaffold',
        ]),
        reason: 'the MCP capability contract must not change',
      );
    });

    test('all single-plugin capabilities are PluginFeatureCapability', () {
      final plugin = FeaturePlugin(
        outputDir: 'lib/src',
        options: const GeneratorOptions(),
      );
      final clones = plugin.capabilities
          .whereType<PluginFeatureCapability>()
          .toList();
      expect(
        clones,
        hasLength(8),
        reason:
            'the 8 copy-pasted clone classes collapsed into 8 registrations '
            'of the ONE parameterized class',
      );
      expect(clones.map((c) => c.pluginId).toSet(), {
        'di',
        'view',
        'presenter',
        'controller',
        'route',
        'state',
        'mock',
        'test',
      });
      expect(
        plugin.capabilities.whereType<ScaffoldFeatureCapability>(),
        hasLength(1),
      );
    });

    test('the di capability mirrors mock onto use-mock (old behavior)', () {
      final plugin = FeaturePlugin(outputDir: 'lib/src');
      final di = plugin.capabilities
          .whereType<PluginFeatureCapability>()
          .firstWhere((c) => c.pluginId == 'di');
      expect(di.mapsMockArgToUseMock, isTrue);
      final mock = plugin.capabilities
          .whereType<PluginFeatureCapability>()
          .firstWhere((c) => c.pluginId == 'mock');
      expect(mock.mapsMockArgToUseMock, isFalse);
    });
  });
}
