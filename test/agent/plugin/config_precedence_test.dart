import 'package:args/args.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/config/zfa_config.dart';
import 'package:zuraffa/src/core/planning/generation_plan.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';

void main() {
  group('AgentPlugin opt-in precedence — FR-003 / SC-004', () {
    /// Builds a PlanResolver against the real PluginLoader (which now
    /// includes the AgentPlugin) and exercises the four precedence
    /// combinations.
    ///
    /// The AgentPlugin's generateWithContext is not actually invoked
    /// here — the test asserts that the plugin ENDS UP in the active
    /// plan exactly when expected. Generation behavior is covered by
    /// agent_plugin_test.dart.
    late PluginLoader loader;

    setUp(() {
      loader = PluginLoader(
        outputDir: '/tmp/lib/src',
        dryRun: true,
        force: true,
        verbose: false,
        config: PluginConfig(),
      );
    });

    ArgResults parse(List<String> args) {
      final parser = ArgParser();
      // Mirror the flags MakeCommand auto-registers for every plugin
      // (negatable, defaultsTo: true).
      for (final plugin in loader.buildRegistry().plugins) {
        parser.addFlag(
          plugin.id,
          help: 'Enable or disable ${plugin.name}',
          defaultsTo: true,
          negatable: true,
        );
      }
      // The agent plugin uses defaultsTo: false at the config layer —
      // so absent flags from the CLI never include 'agent' in
      // _selectionFromOptions.
      return parser.parse(args);
    }

    ZfaConfig configWithAgent(bool on) {
      return ZfaConfig(pluginDefaults: {'agent': on});
    }

    bool planIncludesAgent(GenerationPlan plan) =>
        plan.activePlugins.any((p) => p.id == 'agent');

    test('Case 1: flag on + config on → AgentPlugin active', () {
      final argResults = parse(['--agent']);
      final resolver = PlanResolver(
        registry: loader.buildRegistry(),
        config: configWithAgent(true),
      );
      final plan = resolver.resolve(name: 'Demo', argResults: argResults);
      expect(planIncludesAgent(plan), isTrue);
    });

    test('Case 2: flag on + config off → AgentPlugin active (flag wins)', () {
      final argResults = parse(['--agent']);
      final resolver = PlanResolver(
        registry: loader.buildRegistry(),
        config: configWithAgent(false),
      );
      final plan = resolver.resolve(name: 'Demo', argResults: argResults);
      expect(planIncludesAgent(plan), isTrue);
    });

    test(
      'Case 3: flag off (--no-agent) + config on → AgentPlugin NOT active (flag wins)',
      () {
        final argResults = parse(['--no-agent']);
        final resolver = PlanResolver(
          registry: loader.buildRegistry(),
          config: configWithAgent(true),
        );
        final plan = resolver.resolve(name: 'Demo', argResults: argResults);
        expect(planIncludesAgent(plan), isFalse);
      },
    );

    test(
      'Case 4: flag off (no flag) + config off → AgentPlugin NOT active',
      () {
        final argResults = parse([]);
        final resolver = PlanResolver(
          registry: loader.buildRegistry(),
          config: configWithAgent(false),
        );
        final plan = resolver.resolve(name: 'Demo', argResults: argResults);
        expect(planIncludesAgent(plan), isFalse);
      },
    );

    test('config `agent: true` enables generation without --agent flag', () {
      final argResults = parse([]);
      final resolver = PlanResolver(
        registry: loader.buildRegistry(),
        config: configWithAgent(true),
      );
      final plan = resolver.resolve(name: 'Demo', argResults: argResults);
      expect(planIncludesAgent(plan), isTrue);
    });
  });

  group('ZfaConfig — agent plugin default config key', () {
    test('configKeyForPlugin("agent") returns agentByDefault', () {
      expect(ZfaConfig.configKeyForPlugin('agent'), 'agentByDefault');
    });

    test('ZfaConfig.isPluginEnabledByDefault("agent") is false by default', () {
      final cfg = ZfaConfig();
      expect(cfg.isPluginEnabledByDefault('agent'), isFalse);
    });

    test('ZfaConfig.isPluginEnabledByDefault("agent") is true when set', () {
      final cfg = ZfaConfig(pluginDefaults: {'agent': true});
      expect(cfg.isPluginEnabledByDefault('agent'), isTrue);
    });
  });

  group('ZuraffaPlugin surface — FR-001', () {
    test('PluginLoader.listPlugins includes agent', () {
      final loader = PluginLoader(
        outputDir: '/tmp/lib/src',
        dryRun: true,
        force: true,
        verbose: false,
        config: PluginConfig(),
      );
      final plugins = loader.listPlugins();
      final ids = plugins.map((p) => p.id).toSet();
      expect(ids, contains('agent'));
    });
  });
}
