import '../../../core/plugin_system/capability.dart';
import '../provider_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateProviderCapability implements ZuraffaCapability {
  final ProviderPlugin plugin;

  CreateProviderCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Provider';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Name of the provider',
          },
          'outputDir': {
            'type': 'string',
            'description': 'Directory to output the file',
            'default': 'lib/src',
          },
          'domain': {
            'type': 'string',
            'description': 'Domain folder for the provider',
          },
          'params': {
            'type': 'string',
            'description': 'Parameter type for the provider method',
            'default': 'NoParams',
          },
          'returns': {
            'type': 'string',
            'description': 'Return type for the provider method',
            'default': 'void',
          },
          'type': {
            'type': 'string',
            'description': 'Provider method type (sync, stream, completable)',
            'default': 'usecase',
          },
          'data': {
            'type': 'boolean',
            'description': 'Generate data layer dependencies',
            'default': true,
          },
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
        'required': ['name'],
      };

  @override
  JsonSchema get outputSchema => {
        'type': 'object',
        'properties': {
          'files': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
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
    final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _generateFiles(Map<String, dynamic> args, {required bool dryRun}) async {
    final name = args['name'];
    final outputDir = args['outputDir'] ?? 'lib/src';
    final domain = args['domain'];
    final paramsType = args['params'];
    final returnsType = args['returns'];
    final useCaseType = args['type'];
    final generateData = args['data'] ?? true;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: name,
      domain: domain,
      methods: [],
      paramsType: paramsType,
      returnsType: returnsType,
      useCaseType: useCaseType,
      generateData: generateData,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
