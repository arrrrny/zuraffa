import '../../../core/plugin_system/capability.dart';
import '../usecase_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

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
        'description': 'List of methods (get,create,update,delete,list,watch,getList,watchList)',
        'default': ['get', 'update'],
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
    var useCaseType = args['type'];
    final returns = args['returns'] as String?;

    // Smart Type Inference if not explicitly set
    if (useCaseType == null || useCaseType == 'future') {
      if (returns != null) {
        if (returns.startsWith('Stream<')) {
          useCaseType = 'stream';
        } else if (returns == 'void' || returns == 'Future<void>') {
          // Maybe we want to default to 'completable' here?
          // But 'future' (void) is also valid.
          // Let's stick to future unless user asks for completable.
        }
      }
    }
    useCaseType ??= 'future';

    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final methods = (args['methods'] as List<dynamic>?)?.cast<String>() ?? [];

    final repo = args['repo']?.toString();
    final service = args['service']?.toString();
    final params = args['params']?.toString();
    final usecases = (args['usecases'] as List<dynamic>?)?.cast<String>() ?? [];
    final variants = (args['variants'] as List<dynamic>?)?.cast<String>() ?? [];

    final isCustomUseCase =
        repo != null ||
        service != null ||
        usecases.isNotEmpty ||
        variants.isNotEmpty ||
        (params != null && returns != null);

    final config = GeneratorConfig(
      name: name,
      useCaseType: useCaseType,
      methods: (methods.isEmpty && !isCustomUseCase)
          ? ['get', 'update']
          : methods,
      outputDir: args['outputDir'] ?? 'lib/src',
      domain: args['domain'],
      repo: repo,
      service: service,
      usecases: usecases,
      paramsType: params,
      returnsType: returns,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      revert: args['revert'] ?? false,
    );

    return await plugin.generate(config);
  }
}
