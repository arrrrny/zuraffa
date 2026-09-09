import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../api_plugin.dart';

/// Capability that generates a VM Service extension bridge for a Zuraffa entity.
///
/// Called by `ApiCommand` when the user runs `zfa api <EntityName>`.
/// Delegates to [ApiBridgeBuilder] for the actual code generation.
class CreateApiBridgeCapability implements ZuraffaCapability {
  final ApiPlugin plugin;

  CreateApiBridgeCapability(this.plugin);

  @override
  String get name => 'create-api-bridge';

  @override
  String get description =>
      'Generate VM Service extension bridge for a Zuraffa entity';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Entity name (PascalCase), e.g. Product',
      },
      'domain': {
        'type': 'string',
        'description':
            'Override domain name segment in extension methods (defaults to snake_case of name)',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Preview without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable detailed logging',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'generatedFiles': {
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
    final dryRun = args['dryRun'] as bool? ?? false;
    final files = await _generateFiles(args, dryRun: dryRun);
    // Spec 1334 (verify misfire #1386, EPIC #1132 honesty floor): the api
    // verb exists to bridge UseCases. When discovery finds ZERO UseCases
    // (the only zero-file non-dry-run outcome of the builder) the run
    // must fail, not exit 0 as "success" — the user asked for a bridge
    // and nothing was produced. Dry runs are exempt (preview is explicit
    // user intent). ApiCommand already honors success:false with
    // `❌ Failed to generate API bridge: <message>` + exit 1 (bug #1139
    // pattern). Receipt contract unchanged (#769): nothing written, no
    // receipt.
    if (!dryRun && files.isEmpty) {
      return ExecutionResult(
        success: false,
        files: const [],
        message:
            'No UseCases found for the entity — nothing to bridge. '
            '--> fix: create UseCases first '
            '(e.g. zfa usecase create <Entity> --methods=get,update), '
            'then re-run zfa api <Entity>',
      );
    }
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
    final entityName = args['name'] as String;
    final domain = args['domain'] as String?;
    final force = args['force'] as bool? ?? false;
    final verbose = args['verbose'] as bool? ?? false;
    final outputDirOverride = args['outputDir'] as String?;

    final config = GeneratorConfig(
      name: entityName,
      outputDir: outputDirOverride ?? plugin.outputDir,
      domain: domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return plugin.generate(config);
  }
}
