import '../core/plugin_system/plugin_interface.dart';
import '../models/generator_config.dart';
import 'base_plugin_command.dart';

class ModularDiCommand extends PluginCommand {
  ModularDiCommand(super.plugin) {
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain name for the usecase/entity',
    );
    argParser.addFlag(
      'use-mock',
      negatable: false,
      help: 'Use mock implementation for datasources',
    );
  }

  @override
  String get name => 'di';

  @override
  String get description => 'Generate DI registration for a UseCase or Entity.';

  @override
  Future<void> run() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      print('❌ Usage: zfa di <Name> [options]');
      return;
    }

    final name = args[0];
    final domain = argResults!['domain'] as String?;

    final config = GeneratorConfig(
      name: name,
      domain: domain,
      generateDi: true,
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    // Cast plugin to FileGeneratorPlugin to call generate
    if (plugin is FileGeneratorPlugin) {
      final files = await (plugin as FileGeneratorPlugin).generate(config);
      logSummary(files);
    } else {
      print('❌ Plugin ${plugin.name} is not a FileGeneratorPlugin');
    }
  }
}
