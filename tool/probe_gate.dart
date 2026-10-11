import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/core/plugin_system/cli_aware_plugin.dart';
import 'package:zuraffa/src/core/plugin_system/cli_flag_surface.dart';

void main() {
  final loader = PluginLoader(
    outputDir: 'lib/src',
    dryRun: false,
    force: false,
    verbose: false,
    config: PluginConfig(),
  );
  final reg = loader.buildRegistry();
  for (final id in ['provider', 'view', 'route', 'datasource']) {
    final plugin = reg.plugins.firstWhere((p) => p.id == id) as CliAwarePlugin;
    final cmd = plugin.createCommand();
    print(
      '== $id root=${cmd.runtimeType} subcommands=${cmd.subcommands.keys.toList()}',
    );
    print('   parentParserOptions=${cmd.argParser.options.keys.toList()}');
    for (final cap in (plugin as dynamic).capabilities as List<dynamic>) {
      final serving = resolveServingCommand(
        cmd,
        (cap as dynamic).name as String,
      );
      final props =
          ((cap as dynamic).inputSchema['properties'] as Map?)?.keys.toList() ??
          [];
      print('   cap=${cap.name} serving=${serving.runtimeType} props=$props');
      print('      servingParser=${serving.argParser.options.keys.toList()}');
      String surf;
      try {
        surf = serving.usage;
      } catch (e) {
        surf = '<CRASH: ${e.runtimeType}>';
        try {
          surf = serving.argParser.usage;
        } catch (e2) {
          surf = '<DOUBLE CRASH>';
        }
      }
      print(
        '      oracleVerbose=${surf.contains("--verbose")} oracleForce=${surf.contains("--force")} surfHead=${surf.split(String.fromCharCode(10)).take(2).join(" | ")}',
      );
    }
  }
}
