@Tags(['regression', 'slow'])
library;

// Regression test for issue #259, updated by issue #1149 (kill list).
//
// "[v6][audit] gql + graphql plugins exist in source but are NOT exposed in
// the zfa CLI / manifest — verified 2026-08-05"
//
// Issue #1149 deleted the `gql` plugin (it was a duplicate of `graphql`
// sharing the same output paths): its correct getList naming and
// FileSystem injection were folded into GraphqlBuilder, and `--with=gql`
// aliases to `graphql` for one deprecation cycle. The graphql exposure
// assertions from #259 remain; the gql assertions now pin the alias and
// the removal.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  group('Issue #259: gql + graphql plugins are exposed in the CLI', () {
    test('zfa --help lists graphql as an available command', () async {
      final output = await runner.runCapturing(['help']);
      // The help text enumerates every available command, one per line,
      // with the command name as the first word.
      expect(output, contains('graphql'));
      // Tighter assertions: the help text should mention each command by
      // name on its own line, in the "Available commands:" section.
      final helpLines = output.split('\n').map((l) => l.trim()).toList();
      expect(
        helpLines.any((l) => l.startsWith('graphql ')),
        isTrue,
        reason:
            'graphql command should be listed in `zfa help` output. If '
            'you intentionally removed the graphql command, please close '
            '#259 with a rationale and remove this test.',
      );
    });

    test('issue #1149: the standalone gql command is GONE '
        '(plugin deleted)', () async {
      final output = await runner.runCapturing(['gql', '--help']);
      expect(
        output.toLowerCase(),
        contains('could not find'),
        reason:
            'The gql plugin was deleted (issue #1149). The standalone '
            '`zfa gql` command must no longer resolve.',
      );
    });

    test('zfa graphql --help prints usage (command is wired)', () async {
      final output = await runner.runCapturing(['graphql', '--help']);
      expect(output, isNot(contains('Could not find a command named')));
      expect(output.toLowerCase(), contains('usage'));
    });

    test('zfa manifest includes the graphql plugin', () async {
      final output = await runner.runCapturing(['manifest']);
      // manifest emits a JSON array of capability objects. Each has a
      // "plugin" field. The graphql plugin must appear at least once.
      final List<dynamic> decoded;
      try {
        decoded = jsonDecode(output) as List<dynamic>;
      } catch (e) {
        fail('`zfa manifest` did not emit valid JSON: $e\nOutput:\n$output');
      }
      final pluginIds = decoded
          .map((m) => (m as Map<String, dynamic>)['plugin'] as String?)
          .toSet();
      expect(
        pluginIds,
        contains('graphql'),
        reason:
            '`zfa manifest` must list `graphql` capabilities. If you '
            'intentionally removed this plugin from the manifest, please '
            'close #259 with a rationale and remove this test.',
      );
      expect(
        pluginIds,
        isNot(contains('gql')),
        reason:
            'The gql plugin was deleted (issue #1149) — it must not '
            'appear in the manifest.',
      );
    });

    test('PluginLoader.buildRegistry registers GraphqlPlugin (gql deleted, '
        'issue #1149)', () {
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig(),
      );
      final registry = loader.buildRegistry();
      final ids = registry.plugins.map((p) => p.id).toSet();
      expect(ids, contains('graphql'));
      expect(ids, isNot(contains('gql')));
    });

    test(
      'PluginRegistry.instance has graphql (and no gql) after CliRunner init',
      () async {
        // CliRunner._ensureInitialized is called by runCapturing; verify the
        // singleton registry state after the #1149 kill.
        await runner.runCapturing(['help']);
        final ids = PluginRegistry.instance.plugins.map((p) => p.id).toSet();
        expect(ids, contains('graphql'));
        expect(ids, isNot(contains('gql')));
      },
    );
  });
}
