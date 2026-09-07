import '../../../core/plugin_system/capability.dart';
import '../usecase_plugin.dart';
import '../../../models/generated_file.dart';
import 'usecase_create_request.dart';

class CreateUseCaseCapability implements ZuraffaCapability {
  final UseCasePlugin plugin;

  CreateUseCaseCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Clean Architecture UseCase';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the usecase (e.g. Login)',
      },
      'type': {
        'type': 'string',
        'enum': ['future', 'stream', 'completable', 'sync', 'background'],
        'default': 'future',
      },
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of usecases to orchestrate',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain name (required for non-entity usecases)',
      },
      'repo': {'type': 'string', 'description': 'Repository class to inject'},
      'service': {'type': 'string', 'description': 'Service class to inject'},
      'params': {'type': 'string', 'description': 'Parameter type'},
      'returns': {'type': 'string', 'description': 'Return type'},
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of methods (get,create,update,delete,list,watch,getList,watchList)',
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

  /// SPEC 1119 (order 5, split): the request resolution — smart type
  /// inference, custom-usecase detection, the honest default vocabulary —
  /// used to live here in monolithic form AND in the CLI command. Both
  /// now resolve through [UsecaseCreateRequest]; this capability is a
  /// thin shell over it.
  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final config = UsecaseCreateRequest.fromMap(
      args,
    ).toConfig(outputDir: plugin.outputDir);
    return await plugin.generate(config);
  }
}
