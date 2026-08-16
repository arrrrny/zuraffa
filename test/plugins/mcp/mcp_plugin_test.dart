import 'package:test/test.dart';
import 'package:zuraffa/src/commands/mcp_command.dart';
import 'package:zuraffa/src/plugins/mcp/mcp_plugin.dart';
import 'package:zuraffa/src/plugins/mcp/capabilities/scaffold_mcp_server_capability.dart';

void main() {
  group('McpPlugin', () {
    test('id is "mcp"', () {
      expect(McpPlugin(outputDir: 'lib/src').id, 'mcp');
    });

    test('name is "MCP Plugin"', () {
      expect(McpPlugin(outputDir: 'lib/src').name, 'MCP Plugin');
    });

    test('version is 1.0.0', () {
      expect(McpPlugin(outputDir: 'lib/src').version, '1.0.0');
    });

    test('exposes one capability: ScaffoldMcpServerCapability', () {
      final p = McpPlugin(outputDir: 'lib/src');
      expect(p.capabilities.length, 1);
      expect(p.capabilities.first, isA<ScaffoldMcpServerCapability>());
    });

    test('capability name is "scaffold"', () {
      final p = McpPlugin(outputDir: 'lib/src');
      expect(p.capabilities.first.name, 'scaffold');
    });

    test('createCommand returns a McpCommand named "mcp"', () {
      final p = McpPlugin(outputDir: 'lib/src');
      final cmd = p.createCommand();
      expect(cmd, isA<McpCommand>());
      expect(cmd.name, 'mcp');
    });

    test('McpCommand registers serve + list-tools subcommands', () {
      final p = McpPlugin(outputDir: 'lib/src');
      final cmd = p.createCommand() as McpCommand;
      final subcommandNames = cmd.subcommands.keys.toSet();
      expect(subcommandNames, containsAll(['serve', 'list-tools']));
      // The capability subcommand is also auto-registered by PluginCommand.
      expect(subcommandNames, contains('scaffold'));
    });
  });
}
