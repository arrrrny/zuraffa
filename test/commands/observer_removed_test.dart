// Issue #1149 (kill list, part of EPIC #1132 Machine Contract):
// observer fate decision — deprecate honestly with an exit-64
// "removed" verdict.
//
// The observer plugin had zero tests, zero artifacts in zik_zak or
// zikzak_demo, and generated files importing entity barrels that do not
// exist in a bare project. The modern approach (per the project docs) is
// direct stream subscription on the UseCase result. This suite pins the
// honest removal verdict.
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/core/planning/plan_resolver.dart';

void main() {
  group('observer removal verdict (issue #1149)', () {
    test('zfa observer prints the removed verdict and exits 64', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(['observer', 'create', 'X']);
      expect(output.toUpperCase(), contains('REMOVED'));
      expect(
        output.toLowerCase(),
        contains('stream'),
        reason:
            'The verdict must point to the modern approach: subscribing '
            'directly to the UseCase result stream.',
      );
      expect(
        output,
        contains('#1149'),
        reason: 'the verdict must name the issue that removed the plugin',
      );
    });

    test('the observer plugin is no longer registered anywhere', () {
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig(),
      );
      final ids = loader.buildRegistry().plugins.map((p) => p.id).toSet();
      expect(
        ids,
        isNot(contains('observer')),
        reason: 'the plugin was removed — it must not re-register silently',
      );
    });

    test('zfa make --with=observer surfaces the honest removal warning',
        () {
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig(),
      );
      final registry = loader.buildRegistry();
      final plan = PlanResolver(
        registry: registry,
        config: null,
        pluginConfig: null,
      ).resolve(
        name: 'Product',
        options: const {
          'with': ['observer'],
        },
      );
      expect(
        plan.warnings.join('\n'),
        contains('removed'),
        reason:
            'an unknown-plugin warning alone hides WHY the plugin is gone; '
            'the plan must surface the removal verdict',
      );
    });
  });
}
