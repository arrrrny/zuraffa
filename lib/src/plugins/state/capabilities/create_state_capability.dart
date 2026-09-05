import '../../../core/plugin_system/capability.dart';
import '../state_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateStateCapability implements ZuraffaCapability {
  final StatePlugin plugin;

  CreateStateCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a State class';

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
    // Issue #976: the schema now describes the ACTUAL return shape of
    // execute() — an ExecutionResult whose files entry lists the
    // written paths as strings AND whose data.generatedFiles carries
    // the full GeneratedFile objects. The old schema declared only
    // `files: string[]`, silently hiding the generatedFiles payload
    // every manifest/AI consumer plans against.
    'type': 'object',
    'properties': {
      'success': {
        'type': 'boolean',
        'description': 'Whether the state generation succeeded.',
      },
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Paths of the written state files.',
      },
      'data': {
        'type': 'object',
        'properties': {
          'generatedFiles': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'path': {
                  'type': 'string',
                  'description': 'Path of the generated state file.',
                },
                'type': {
                  'type': 'string',
                  'description': 'Artifact type (state).',
                },
                'action': {
                  'type': 'string',
                  'description':
                      'What the run did: create, update/modify or delete.',
                },
                'content': {
                  'type': 'string',
                  'description': 'Final emitted source of the artifact.',
                },
              },
            },
          },
        },
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

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      generateState: true,
      methods: methods,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
