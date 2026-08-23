import '../../../core/plugin_system/capability.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../sqlite_plugin.dart';

/// Generates a SQLite-backed DataSource for an entity (`zfa sqlite adapter`).
class CreateSqliteAdapterCapability implements ZuraffaCapability {
  final SqlitePlugin plugin;

  CreateSqliteAdapterCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a SQLite data source adapter';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Task)',
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'DataSource methods to implement '
            '(get, getList, list, create, update, toggle, delete, watch, '
            'watchList, initialize)',
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
    try {
      final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);
      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {'generatedFiles': files},
      );
    } catch (e) {
      return ExecutionResult(success: false, message: 'Failed: $e');
    }
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'] as String;
    final methods = (args['methods'] as List<dynamic>? ?? const <dynamic>[])
        .cast<String>()
        .toList();

    final config = GeneratorConfig(
      name: name,
      outputDir: plugin.outputDir,
      dryRun: dryRun,
      force: args['force'] ?? false,
      verbose: args['verbose'] ?? false,
      methods: methods.isEmpty
          ? const ['get', 'getList', 'create', 'update', 'delete']
          : methods,
      idField: args['id-field'] ?? 'id',
      idFieldType: args['id-field-type'] ?? 'String',
    );

    return plugin.generate(config);
  }
}
