import 'package:args/command_runner.dart';

import '../../commands/mcp_command.dart';
import '../../core/context/file_system.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'capabilities/scaffold_mcp_server_capability.dart';

/// Codegen plugin that scaffolds a runtime MCP server into a
/// Zuraffa app.
///
/// `zfa plugin mcp` (or equivalently `zfa mcp scaffold`) writes:
///
///  * `lib/src/plugin/mcp_server_plugin.dart` — runtime
///    `McpServerPlugin extends ZuraffaPlugin` subclass that wires
///    the app's [McpTool]s into the DI tree.
///  * `lib/src/mcp/tools.dart` — the app's declared [McpTool]
///    list (initially a placeholder list the developer fills in).
///  * `bin/mcp_server.dart` — standalone entrypoint that boots
///    the engine + `McpServerPlugin` and serves stdio.
///
/// Plus it appends the plugin registration to `lib/main.dart`
/// (mirroring the `zfa plugin add` mutation logic).
///
/// This is the codegen-side counterpart to the runtime
/// `McpServerPlugin` (lib/src/core/module/mcp_server_plugin.dart).
/// Together they satisfy issue #369's acceptance criteria:
///  - `zfa plugin mcp` scaffolds an MCP server into a generated app
///  - `zfa mcp serve` runs the scaffolded server (stdio or SSE)
///  - `zfa mcp list-tools` lists the registered tools
class McpPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;

  McpPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  @override
  String get id => 'mcp';

  @override
  String get name => 'MCP Plugin';

  @override
  String get version => '1.0.0';

  @override
  List<ZuraffaCapability> get capabilities => [
    ScaffoldMcpServerCapability(this),
  ];

  @override
  Command<void> createCommand() => McpCommand(this);

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name.isEmpty ? 'mcp' : context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      domain: context.data['domain'],
    );
    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    final capability = capabilities.first as ScaffoldMcpServerCapability;
    final result = await capability.execute({
      'name': config.name.isEmpty ? 'mcp' : config.name,
      'dryRun': config.dryRun,
      'force': config.force,
      'verbose': config.verbose,
      'revert': config.revert,
    });
    final files = result.data?['generatedFiles'];
    return files is List<GeneratedFile> ? files : const <GeneratedFile>[];
  }
}
