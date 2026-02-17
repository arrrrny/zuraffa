import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../usecase/usecase_plugin.dart';
import '../../repository/repository_plugin.dart';
import '../../view/view_plugin.dart';
import '../../controller/controller_plugin.dart';
import '../../state/state_plugin.dart';

class ScaffoldFeatureCapability implements ZuraffaCapability {
  final FeaturePlugin plugin;

  ScaffoldFeatureCapability(this.plugin);

  @override
  String get name => 'scaffold';

  @override
  String get description => 'Scaffold a full feature set (VPC, Repo, UseCase, etc.)';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the feature (e.g. UserProfile)'
          },
          'vpcs': {
            'type': 'boolean',
            'description': 'Generate View, Presenter, Controller, State',
            'default': true
          },
          'repository': {
            'type': 'boolean',
            'description': 'Generate Repository',
            'default': true
          },
          'usecases': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of usecases to generate',
            'default': ['get', 'update']
          },
          'outputDir': {'type': 'string', 'default': 'lib/src'},
          'dryRun': {
            'type': 'boolean',
            'description': 'Run without writing files',
            'default': false,
          },
          'force': {
            'type': 'boolean',
            'description': 'Force overwrite existing files',
            'default': false,
          },
          'verbose': {
            'type': 'boolean',
            'description': 'Enable verbose logging',
            'default': false,
          },
        },
        'required': ['name']
      };

  @override
  JsonSchema get outputSchema => {
        'type': 'object',
        'properties': {
          'files': {
            'type': 'array',
            'items': {'type': 'string'}
          }
        }
      };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: true);
    
    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(
                file: f.path,
                action: f.action,
                diff: null,
              ))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _generateFiles(Map<String, dynamic> args, {required bool dryRun}) async {
    final outputDir = args['outputDir'] ?? 'lib/src';
    final featureName = args['name'];
    final generateVpcs = args['vpcs'] ?? true;
    final generateRepo = args['repository'] ?? true;
    final usecases = (args['usecases'] as List?)?.cast<String>() ?? [];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final revert = args['revert'] ?? false;

    final allFiles = <GeneratedFile>[];

    // Repository
    if (generateRepo) {
      final repoPlugin = RepositoryPlugin(
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        generateRepository: true,
        generateData: true,
        generateDataSource: true,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );
      allFiles.addAll(await repoPlugin.generate(config));
    }

    // UseCases
    if (usecases.isNotEmpty) {
      final usecasePlugin = UseCasePlugin(
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      // We need to generate each usecase
      // GeneratorConfig for usecase takes 'name' as the usecase name.
      // But here we have a feature name.
      // Usually usecases are named "GetFeature", "UpdateFeature".
      for (final verb in usecases) {
        // Simple heuristic for naming
        // e.g. verb="get", feature="User" -> "GetUser"
        final ucName = '${verb[0].toUpperCase()}${verb.substring(1)}$featureName';
        final config = GeneratorConfig(
          name: ucName,
          outputDir: outputDir,
          useCaseType: 'entity', // Default
          repo: '${featureName}Repository',
          dryRun: dryRun,
          force: force,
          verbose: verbose,
          revert: revert,
        );
        allFiles.addAll(await usecasePlugin.generate(config));
      }
    }

    // VPC
    if (generateVpcs) {
      // View, Presenter, Controller, State, DI
      // This requires instantiating multiple plugins.
      // For brevity, let's just do View and Controller for now as proof of concept.
      final viewPlugin = ViewPlugin(
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final controllerPlugin = ControllerPlugin(
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );
      final statePlugin = StatePlugin(
        outputDir: outputDir,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
      );

      final config = GeneratorConfig(
        name: featureName,
        outputDir: outputDir,
        idField: 'id',
        idType: 'String',
        generateVpcs: generateVpcs,
        generateView: generateVpcs,
        generateController: generateVpcs,
        generateState: generateVpcs,
        dryRun: dryRun,
        force: force,
        verbose: verbose,
        revert: revert,
      );

      allFiles.addAll(await viewPlugin.generate(config));
      allFiles.addAll(await controllerPlugin.generate(config));
      allFiles.addAll(await statePlugin.generate(config));
    }

    return allFiles;
  }
}
