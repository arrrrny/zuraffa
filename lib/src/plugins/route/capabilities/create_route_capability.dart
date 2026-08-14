import '../../../core/plugin_system/capability.dart';
import '../route_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../../utils/entity_id_type.dart';

class CreateRouteCapability implements ZuraffaCapability {
  final RoutePlugin plugin;

  CreateRouteCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create Route';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },

      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of methods (get,create,update,delete,list,watch,getList,watchList)',
        'default': ['get', 'update'],
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

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final methods =
        (args['methods'] as List?)?.cast<String>() ?? ['get', 'update'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // #336: keep route id path params consistent with the view's id
    // field type (probe the entity source / last make plan) so int-id
    // entities get `int.parse(state.pathParameters['id']!)` instead of
    // assigning a String into an int-typed view param.
    final idFieldType =
        args['id-field-type'] as String? ??
        await resolveEntityIdFieldType(entityName: name);

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      methods: methods,
      generateRoute: true,
      generateDi: false, // Prevent repository injections in views
      idFieldType: idFieldType ?? 'String',
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
