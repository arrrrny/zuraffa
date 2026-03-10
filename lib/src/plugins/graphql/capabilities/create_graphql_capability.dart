import '../../../core/plugin_system/capability.dart';
import '../graphql_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateGraphqlCapability implements ZuraffaCapability {
  final GraphqlPlugin plugin;

  CreateGraphqlCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create GraphQL';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
      },
      'type': {
        'type': 'string',
        'description': 'GraphQL operation type (query, mutation)',
        'default': 'query',
      },
      'returns': {'type': 'string', 'description': 'Return type'},
      'inputType': {'type': 'string', 'description': 'Input type name'},
      'inputName': {'type': 'string', 'description': 'Input variable name'},
      'opName': {'type': 'string', 'description': 'Operation name'},
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
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
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

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = args['outputDir'] ?? 'lib/src';
    final type = args['type'] ?? 'query';
    final returns = args['returns'];
    final inputType = args['inputType'];
    final inputName = args['inputName'];
    final opName = args['opName'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      generateGql: true,
      gqlType: type,
      gqlReturns: returns,
      gqlInputType: inputType,
      gqlInputName: inputName,
      gqlName: opName,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
