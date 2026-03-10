import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/di/capabilities/create_di_capability.dart';

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
    final useMock = argResults!['use-mock'] == true;

    final capability = plugin.capabilities.firstWhere(
      (c) => c is CreateDiCapability,
    ) as CreateDiCapability;

    final result = await capability.execute({
      'name': name,
      'domain': domain,
      'useMock': useMock,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate DI');
    }
  }
}
