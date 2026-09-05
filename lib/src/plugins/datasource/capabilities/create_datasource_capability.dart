import '../../../core/plugin_system/capability.dart';
import '../datasource_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateDataSourceCapability implements ZuraffaCapability {
  final DataSourcePlugin plugin;

  CreateDataSourceCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Data Source';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the data source'},

      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
        'default': false,
      },
      'remote': {
        'type': 'boolean',
        'description': 'Generate remote data source (and API integration)',
        'default': true,
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable caching',
        'default': false,
      },
      'useService': {
        'type': 'boolean',
        'description':
            'Request a service instead of a datasource. Supersedes '
            'datasource generation: the request is declined with an '
            'honest skip reason (spec #977).',
        'default': false,
      },
      'id-field': {
        'type': 'string',
        'description':
            'Entity id field name the datasource resolves (#294 audit '
            'trail). Defaults to `id`.',
        'default': 'id',
      },
      'id-field-type': {
        'type': 'string',
        'description': 'Entity id field type.',
        'default': 'String',
      },
      'query-field': {
        'type': 'string',
        'description': 'Entity query field name. Defaults to `id`.',
        'default': 'id',
      },
      'query-field-type': {
        'type': 'string',
        'description': 'Entity query field type.',
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
    final config = _buildConfig(args, dryRun: args['dryRun'] ?? false);

    // Spec #977: a service request supersedes the datasource layer. The
    // plugin's emission semantics are frozen (it still returns [] for
    // `hasService`); the CONTRACT around it is what changed — the skip
    // is reported as a structured failure with the reason so neither the
    // #769 zero-files guard nor a host can mistake it for a success.
    if (config.hasService) {
      return ExecutionResult(
        success: false,
        files: const [],
        message:
            'datasource generation skipped: `${config.name}` requests a '
            'service (use-service) — the service layer supersedes a '
            'dedicated datasource, so nothing was emitted. Re-run without '
            'the service request if a datasource is really wanted.',
        data: const {
          'generatedFiles': <GeneratedFile>[],
          'skipReason': 'hasService',
        },
      );
    }

    try {
      final files = await plugin.generate(config);

      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {
          'generatedFiles': files,
          // #977: resolved input the generation consumed — shipped so the
          // standalone receipt records the id-field / query-field
          // resolution (#294 audit trail).
          'input': {
            'id-field': config.idField,
            'id-field-type': config.idFieldType,
            'query-field': config.queryField,
            'query-field-type': config.queryFieldType,
            'local': config.generateLocal,
            'remote': config.generateRemote,
            'cache': config.enableCache,
            'init': config.generateInit,
          },
        },
      );
    } catch (e) {
      // #977: a thrown generation is an honest failure with a reason,
      // never an empty success.
      return ExecutionResult(
        success: false,
        files: const [],
        message: 'Failed: $e',
      );
    }
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) {
    return plugin.generate(_buildConfig(args, dryRun: dryRun));
  }

  GeneratorConfig _buildConfig(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) {
    final name = args['name'];
    return GeneratorConfig(
      name: name,
      outputDir: plugin.outputDir,
      generateDataSource: true,
      generateLocal: args['local'] ?? false,
      generateRemote: args['remote'] ?? true,
      enableCache: args['cache'] ?? false,
      methods: (args['methods'] as List?)?.cast<String>() ?? [],
      paramsType: args['params'],
      returnsType: args['returns'],
      useCaseType: args['type'] ?? 'usecase',
      generateInit: args['init'] == true,
      useService: args['useService'] == true || args['use-service'] == true,
      service: args['service'] as String?,
      idField: args['id-field'] ?? 'id',
      idFieldType: args['id-field-type'] ?? 'String',
      queryField: args['query-field'] ?? 'id',
      queryFieldType: args['query-field-type'] as String?,
      dryRun: dryRun,
      force: args['force'] ?? false,
      verbose: args['verbose'] ?? false,
    );
  }
}
