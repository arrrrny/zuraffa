import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/feature/feature_plugin.dart';
import '../core/plugin_system/capability.dart';

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
    argParser.addFlag(
      'test',
      help: 'Generate Tests',
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
    argParser.addOption(
      'query-field',
      help: 'Query field name for get/watch methods',
    );
    argParser.addOption(
      'query-field-type',
      help: 'Query field type for get/watch methods',
    );
    argParser.addOption('id-field', help: 'ID field name');
    argParser.addOption('id-field-type', help: 'ID field type');
    argParser.addFlag(
      'zorphy',
      help:
          'Use Zorphy patterns (e.g., LocalePatch instead of Partial<Locale>)',
      defaultsTo: false,
      negatable: false,
    );
  }

  @override
  String get name => 'feature';

  @override
  String get description => 'Scaffold full features';

  ZuraffaCapability? _findCapability(String name) {
    try {
      return plugin.capabilities.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      printUsage();
      return;
    }

    final firstArg = argResults!.rest.first;
    final allGeneratedFiles = <GeneratedFile>[];

    // Get the capability names
    final capabilityNames = plugin.capabilities.map((c) => c.name).toSet();

    // Check if first arg is a capability name AND there's a second arg (the feature name)
    // This handles: zfa feature route Locale, zfa feature di Locale, etc.
    if (capabilityNames.contains(firstArg) && argResults!.rest.length > 1) {
      // Handle: zfa feature <capability> <name> [options]
      final capability = _findCapability(firstArg);
      final featureName = argResults!.rest[1];

      if (capability != null) {
        final execArgs = _buildArgs(featureName);
        final result = await capability.execute(execArgs);

        if (result.success) {
          final files =
              result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
          allGeneratedFiles.addAll(files);
        } else {
          print('Failed to generate $firstArg');
          return;
        }
      }
    } else {
      // Handle: zfa feature Locale [flags] OR zfa feature Locale (defaults to scaffold)
      final featureName = firstArg;

      // Check which capabilities should run based on flags
      // Default to scaffold if no specific flags are set
      final bool runScaffold =
          (!argResults!.wasParsed('route') &&
              !argResults!.wasParsed('di') &&
              !argResults!.wasParsed('mock') &&
              !argResults!.wasParsed('test')) ||
          argResults!.wasParsed('vpcs') ||
          argResults!.wasParsed('repository') ||
          argResults!.wasParsed('datasource');

      final capabilityFlags = {
        'scaffold': runScaffold,
        'route': argResults!.wasParsed('route'),
        'di': argResults!.wasParsed('di'),
        'mock': argResults!.wasParsed('mock'),
        'test': argResults!.wasParsed('test'),
        'view': false,
        'presenter': false,
        'controller': false,
        'state': false,
      };

      // Run selected capabilities
      for (final entry in capabilityFlags.entries) {
        if (entry.value) {
          final cap = _findCapability(entry.key);
          if (cap != null) {
            final execArgs = _buildArgs(featureName);
            final result = await cap.execute(execArgs);
            if (result.success) {
              final files =
                  result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
              allGeneratedFiles.addAll(files);
            }
          }
        }
      }
    }

    if (allGeneratedFiles.isNotEmpty) {
      logSummary(allGeneratedFiles);
    } else {
      print('No files generated');
    }
  }

  Map<String, dynamic> _buildArgs(String featureName) {
    final usecases = argResults!['usecases'] as List<String>;

    final Map<String, dynamic> execArgs = {
      'name': featureName,
      'usecases': usecases,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'revert': isRevert,
      'outputDir': outputDir,
    };

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
    addIfParsed('test');
    addIfParsed('query-field');
    addIfParsed('query-field-type');
    addIfParsed('id-field');
    addIfParsed('id-field-type');
    addIfParsed('zorphy');

    return execArgs;
  }
}
