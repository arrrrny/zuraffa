import 'dart:convert';
import 'package:args/command_runner.dart';
import '../core/plugin_system/plugin_registry.dart';

/// Command to list all available capabilities in JSON format.
///
/// This is used by MCP clients to discover available tools.
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
  }

  @override
  String get name => 'manifest';

  @override
  String get description => 'List all available capabilities';

  @override
  Future<void> run() async {
    final format = argResults?['format'] ?? 'json';

    if (format == 'mcp') {
      // Format as MCP tools definition
      final tools = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
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
      final output = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
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
}
