import '../../../core/plugin_system/capability.dart';
import '../mock_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../builders/simulation_fixture_writer.dart';

class CreateMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  CreateMockCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Mock';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the mock target'},
      // Issue #770: default to the canonical CRUD method set used by the
      // di/usecase/test/state/controller/datasource/repository plugins and
      // by MockPlugin.generateWithContext (#294). With an empty method set
      // the generated mock datasource implements the datasource interface
      // without any members and fails analyze with
      // non_abstract_class_inherits_abstract_member.
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'default': ['get', 'update', 'toggle'],
        'description':
            'List of methods for the mock datasource (get,create,update,delete,list,watch,getList,watchList,toggle)',
      },
      'dataOnly': {
        'type': 'boolean',
        'description': 'Generate mock data only',
        'default': false,
      },
      'fixturesDir': {
        'type': 'string',
        'description':
            'Commit per-entity fixture data under this directory (e.g. '
            'specs/<feature>/tdd/fixtures) and re-certify it through the '
            '#832 fixture registry (spec 893)',
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
      'service': {
        'type': 'string',
        'description': 'Service name for mock provider',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the mock provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for mock methods',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for mock methods',
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
    final dataOnly = args['dataOnly'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final service = args['service'];
    final domain = args['domain'];
    final params = args['params'];
    final returns = args['returns'];
    final fixturesDir = args['fixturesDir'] as String?;
    // Issue #770: semantic default for direct execute() callers that omit
    // the key — same canonical set as the schema default and
    // MockPlugin.generateWithContext (#294). Explicit values are honored.
    final methods =
        (args['methods'] as List?)?.cast<String>() ??
        const ['get', 'update', 'toggle'];

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: service,
      domain: domain,
      paramsType: params,
      returnsType: returns,
      methods: methods,
      generateMock: !dataOnly,
      generateMockDataOnly: dataOnly,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final files = await plugin.generate(config);

    // Spec 893 (T003, FR-003): commit per-entity fixture data under the
    // feature's tdd/fixtures/ directory and re-certify it through the
    // #832 fixture registry. Fixture commitment is part of the standard
    // `zfa mock create` workflow, not a manual step.
    if (fixturesDir != null && fixturesDir.isNotEmpty && !dryRun && !dataOnly) {
      final entityName = config.repo != null
          ? config.repo!.replaceAll('Repository', '')
          : config.name;
      final writer = SimulationFixtureWriter(
        outputDir: outputDir,
        verbose: verbose,
      );
      files.add(
        await writer.write(
          entityName: entityName,
          fixturesDir: fixturesDir,
          commandLine:
              'zfa mock create $entityName --fixtures-dir $fixturesDir',
        ),
      );
    }

    return files;
  }
}
