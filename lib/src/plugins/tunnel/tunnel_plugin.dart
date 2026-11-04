import 'package:args/command_runner.dart';

import '../../commands/tunnel_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';

/// The `zuraffa_tunnel` plugin (specs/1724-zuraffa-tunnel — issue #2045).
///
/// A pure RUNTIME plugin: it owns no codegen capability (its `capabilities`
/// list is empty) and contributes exactly one operator surface — the
/// `zfa tunnel` command (run / status) that wraps a local app port with a
/// Cloudflare tunnel. It composes with the `mcp` plugin: a `zuraffa_mcp`
/// HTTP endpoint behind the tunnel is the web-based MCP shape.
class TunnelPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  TunnelPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });

  final String outputDir;
  final GeneratorOptions options;

  @override
  String get id => 'tunnel';

  @override
  String get name => 'Tunnel Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command<void> createCommand() => TunnelCommand(this);

  @override
  Future<List<GeneratedFile>> generateWithContext(
    PluginContext context,
  ) async => const <GeneratedFile>[];

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async =>
      const <GeneratedFile>[];
}
