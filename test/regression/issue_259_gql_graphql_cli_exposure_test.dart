@Tags(['regression', 'slow'])
// Regression test for issue #259.
//
// "[v6][audit] gql + graphql plugins exist in source but are NOT exposed in
// the zfa CLI / manifest — verified 2026-08-05"
//
// As of the current master, both the `gql` and `graphql` plugins ARE exposed
// in `zfa --help` AND in `zfa manifest`. This test asserts they stay exposed
// so a future refactor (e.g. dropping the `CliAwarePlugin` marker interface
// from one of them, or skipping the command-registration loop for a plugin
// id) cannot silently make them disappear again.
//
// See: https://github.com/arrrrny/zuraffa/issues/259
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
    test('zfa --help lists gql and graphql as available commands', () async {
      final output = await runner.runCapturing(['help']);
      // The help text enumerates every available command, one per line,
      // with the command name as the first word.
      expect(output, contains('gql'));
      expect(output, contains('graphql'));
      // Tighter assertions: the help text should mention each command by
      // name on its own line, in the "Available commands:" section.
      final helpLines = output.split('\n').map((l) => l.trim()).toList();
      expect(
        helpLines.any((l) => l.startsWith('gql ')),
        isTrue,
        reason:
            'gql command should be listed in `zfa help` output. If you '
            'intentionally removed the gql command, please close #259 with '
            'a rationale and remove this test.',
      );
      expect(
        helpLines.any((l) => l.startsWith('graphql ')),
        isTrue,
        reason:
            'graphql command should be listed in `zfa help` output. If '
            'you intentionally removed the graphql command, please close '
            '#259 with a rationale and remove this test.',
      );
    });

    test('zfa gql --help prints usage (command is wired)', () async {
      final output = await runner.runCapturing(['gql', '--help']);
      // A registered command prints a usage block; an unregistered one
      // prints "Could not find a command named gql".
      expect(output, isNot(contains('Could not find a command named')));
      expect(output.toLowerCase(), contains('usage'));
    });

    test('zfa graphql --help prints usage (command is wired)', () async {
      final output = await runner.runCapturing(['graphql', '--help']);
      expect(output, isNot(contains('Could not find a command named')));
      expect(output.toLowerCase(), contains('usage'));
    });

    test('zfa manifest includes gql + graphql plugins', () async {
      final output = await runner.runCapturing(['manifest']);
      // manifest emits a JSON array of capability objects. Each has a
      // "plugin" field. Both plugins must appear at least once.
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
        containsAll(<String>{'gql', 'graphql'}),
        reason:
            '`zfa manifest` must list both `gql` and `graphql` '
            'capabilities. If you intentionally removed one of these '
            'plugins from the manifest, please close #259 with a rationale '
            'and remove this test.',
      );
    });

    test(
      'PluginLoader.buildRegistry registers GqlPlugin and GraphqlPlugin',
      () {
        final loader = PluginLoader(
          outputDir: 'lib/src',
          dryRun: false,
          force: false,
          verbose: false,
          config: PluginConfig(),
        );
        final registry = loader.buildRegistry();
        final ids = registry.plugins.map((p) => p.id).toSet();
        expect(ids, containsAll(<String>{'gql', 'graphql'}));
      },
    );

    test(
      'PluginRegistry.instance has gql + graphql after CliRunner init',
      () async {
        // CliRunner._ensureInitialized is called by runCapturing; verify the
        // singleton registry now has both plugins registered.
        await runner.runCapturing(['help']);
        final ids = PluginRegistry.instance.plugins.map((p) => p.id).toSet();
        expect(ids, containsAll(<String>{'gql', 'graphql'}));
      },
    );
  });
}
