import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/feature/feature_plugin.dart';
import '../plugins/feature/capabilities/scaffold_feature_capability.dart';

class FeatureCommand extends PluginCommand {
  @override
  final FeaturePlugin plugin;

  FeatureCommand(this.plugin) : super(plugin) {
    argParser.addFlag(
      'vpcs',
      help: 'Generate View, Presenter, Controller, State',
      defaultsTo: true,
    );
    argParser.addFlag(
      'repository',
      help: 'Generate Repository',
      defaultsTo: true,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate DataSource (Remote and/or Local)',
      defaultsTo: true,
    );
    argParser.addFlag(
      'local',
      help: 'Generate local data source (instead of remote)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'mock',
      help: 'Generate Mock data',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'di',
      help: 'Generate Dependency Injection setup',
      defaultsTo: true,
    );
    argParser.addFlag(
      'cache',
      help: 'Enable Caching (generates local + remote datasources)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'route',
      help: 'Generate Routing definitions',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'List of usecases to generate (e.g. get,update,watch)',
      defaultsTo: ['get', 'update'],
      splitCommas: true,
    );
  }

  @override
  String get name => 'feature';

  @override
  String get description => 'Scaffold full features';

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      printUsage();
      return;
    }

    final featureName = argResults!.rest.first;
    final usecases = argResults!['usecases'] as List<String>;
    
    final capability = plugin.capabilities.firstWhere(
      (c) => c is ScaffoldFeatureCapability,
    ) as ScaffoldFeatureCapability;

    // Build args map
    // We use wasParsed to allow the Capability to fall back to ZfaConfig or defaults
    // only when the user hasn't explicitly set a flag.
    final Map<String, dynamic> execArgs = {
      'name': featureName,
      'usecases': usecases,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'revert': isRevert,
      'outputDir': outputDir,
    };

    // Helper to add flag if parsed
    void addIfParsed(String name) {
      if (argResults!.wasParsed(name)) {
        execArgs[name] = argResults![name];
      }
    }

    addIfParsed('vpcs');
    addIfParsed('repository');
    addIfParsed('datasource');
    addIfParsed('local');
    addIfParsed('mock');
    addIfParsed('di');
    addIfParsed('cache');
    addIfParsed('route');

    final result = await capability.execute(execArgs);

    if (result.success) {
      final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('Failed to generate feature');
    }
  }
}
