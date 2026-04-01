import 'package:args/command_runner.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/mock/capabilities/create_mock_capability.dart';

class MockCommand extends PluginCommand {
  @override
  final MockPlugin plugin;

  MockCommand(this.plugin) : super(plugin) {
    addSubcommand(DataMockCommand(plugin));
    argParser.addFlag(
      'data-only',
      help: 'Generate only mock data (fixtures)',
      defaultsTo: false,
    );
    argParser.addOption('service', help: 'Service name for mock provider');
    argParser.addOption('domain', help: 'Domain folder for the mock provider');
    argParser.addOption('params', help: 'Parameter type for mock methods');
    argParser.addOption('returns', help: 'Return type for mock methods');
  }

  @override
  String get name => 'mock';

  @override
  String get description => 'Generate Mocks';

  @override
  Future<void> run() async {
    final command = argResults?.command;
    if (command != null) {
      return super.run();
    }

    if (argResults?.rest.isEmpty ?? true) {
      print('❌ Usage: zfa mock <EntityName> [options]');
      print('   Or: zfa mock data <EntityName> [options]');
      return;
    }

    final entityName = argResults!.rest.first;
    final dataOnly = argResults?['data-only'] as bool? ?? false;
    final service = argResults?['service'] as String?;
    final domain = argResults?['domain'] as String?;
    final params = argResults?['params'] as String?;
    final returns = argResults?['returns'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'dataOnly': dataOnly,
      'service': service,
      'domain': domain,
      'params': params,
      'returns': returns,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate mock');
    }
  }
}

class DataMockCommand extends Command<void> {
  final MockPlugin plugin;

  DataMockCommand(this.plugin) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
  }

  @override
  String get name => 'data';

  @override
  String get description => 'Generate only mock data (fixtures) for an entity';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      print('❌ Usage: zfa mock data <EntityName> [options]');
      return;
    }

    final entityName = results.rest.first;
    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'dataOnly': true,
      'dryRun': results['dry-run'] == true,
      'force': results['force'] == true,
      'verbose': results['verbose'] == true,
      'outputDir': results['output'] ?? 'lib/src',
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      // logSummary(files) - Need access to logSummary from PluginCommand
      // Since it's not accessible here, we just print a simple success message
      print('\n✅ Mock data generation complete for: $entityName');
      for (final file in files) {
        if (file.action == 'created') {
          print('  ✨ ${file.path}');
        } else if (file.action == 'overwritten') {
          print('  📝 ${file.path}');
        }
      }
    } else {
      print('❌ Error: ${result.message}');
    }
  }
}
