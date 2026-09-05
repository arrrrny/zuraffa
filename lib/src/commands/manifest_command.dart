import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import '../core/plugin_system/cli_aware_plugin.dart';
import '../core/plugin_system/plugin_registry.dart';
import 'base_plugin_command.dart';

/// Command to list all available capabilities in JSON format.
///
/// This is used by MCP clients to discover available tools.
///
/// Spec #979 (order 3): `zfa manifest --verify [pluginIds...]` certifies
/// the flag surface — for every CLI-aware plugin (or the requested
/// subset), every plugin-specific, parent-level option its command
/// registers must be consumed by that command's `run()`
/// ([PluginCommand.consumedParentFlags]) or absent. A parent option that
/// is parsed and advertised by `--help` but never read is the #876
/// "flags that lie" family; the certification reports each as a
/// `dead-flag` finding with a `--> fix:` line and exits 1. With no plugin
/// ids, every CLI-aware plugin in the registry is certified.
class ManifestCommand extends Command<void> {
  final PluginRegistry registry;

  ManifestCommand([PluginRegistry? registry])
    : registry = registry ?? PluginRegistry.instance {
    argParser.addOption(
      'format',
      abbr: 'f',
      allowed: ['json', 'mcp'],
      defaultsTo: 'json',
      help: 'Output format',
    );
    argParser.addFlag(
      'verify',
      negatable: false,
      help:
          'Certify the parent-flag surface: every plugin-specific '
          'parent-level option is consumed by its command\'s run() or '
          'absent (dead-flag findings exit 1). Optional trailing plugin '
          'ids scope the certification.',
    );
  }

  @override
  String get name => 'manifest';

  @override
  String get description => 'List all available capabilities';

  @override
  Future<void> run() async {
    if (argResults?['verify'] == true) {
      await _runVerify(argResults?.rest ?? const <String>[]);
      return;
    }

    final format = argResults?['format'] ?? 'json';

    if (format == 'mcp') {
      // Format as MCP tools definition
      final tools = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
        // Only capabilities of CLI-aware plugins are advertised: the manifest
        // is a command-invocation contract, and capabilities of plugins without
        // a registered command (internal orchestrators) are unreachable from
        // the CLI and would mislead MCP/tooling clients that auto-resolve
        // names against this list.
        if (plugin is! CliAwarePlugin) continue;
        for (final capability in plugin.capabilities) {
          tools.add({
            'name': 'zfa_${plugin.id}_${capability.name}',
            'description': capability.description,
            'inputSchema': capability.inputSchema,
          });
        }
      }
      print(jsonEncode({'tools': tools}));
    } else {
      // Default JSON format with full details
      //
      // Only capabilities of CLI-aware plugins are advertised: the manifest
      // is a command-invocation contract, and capabilities of plugins without
      // a registered command (internal orchestrators) are unreachable from
      // the CLI and would mislead MCP/tooling clients that auto-resolve
      // names against this list.
      final output = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
        if (plugin is! CliAwarePlugin) continue;
        for (final capability in plugin.capabilities) {
          output.add({
            'plugin': plugin.id,
            'name': capability.name,
            'description': capability.description,
            'inputSchema': capability.inputSchema,
            'outputSchema': capability.outputSchema,
          });
        }
      }
      print(jsonEncode(output));
    }
  }

  /// The certification pass (spec #979 order 3).
  Future<void> _runVerify(List<String> scope) async {
    // The flags every PluginCommand carries as shared machinery, plus
    // package:args' automatic --help — none of these are the plugin
    // contract.
    const baseFlags = {
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
      'help',
    };

    final findings = <String>[];
    final certified = <String>[];

    for (final plugin in registry.plugins) {
      if (plugin is! CliAwarePlugin) continue;
      if (scope.isNotEmpty && !scope.contains(plugin.id)) continue;

      final command = (plugin as CliAwarePlugin).createCommand();
      final pluginFlags = command.argParser.options.keys
          .where((f) => !baseFlags.contains(f))
          .toSet();
      final consumed = command is PluginCommand
          ? command.consumedParentFlags
          : const <String>{};
      final dead = pluginFlags.difference(consumed);

      if (dead.isEmpty) {
        certified.add(
          '  ✓ ${plugin.id} — every plugin-specific parent option is '
          'functional or absent',
        );
        continue;
      }

      for (final flag in dead) {
        findings.add(
          '[dead-flag] zfa ${plugin.id} --$flag is parsed and advertised '
          'by --help but never read in run() (issue #876 family)\n'
          '    --> fix: delete the parent-level --$flag registration — '
          'the live surface is `zfa ${plugin.id} <subcommand> --$flag`, '
          'synthesized from the capability inputSchema — or consume it in '
          'run() and declare it in consumedParentFlags.',
        );
      }
    }

    print(
      'manifest verify: ${certified.length} plugin command(s) certified, '
      '${findings.length} dead flag(s)',
    );
    for (final line in certified) {
      print(line);
    }
    if (findings.isEmpty) {
      print(
        '✅ flag surface certified: every plugin-specific parent option '
        'is functional or absent.',
      );
      exitCode = 0;
      return;
    }
    print('');
    print('Findings (${findings.length}):');
    for (final finding in findings) {
      print('  $finding');
    }
    exitCode = 1;
  }
}
