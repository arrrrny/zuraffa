import 'dart:io';

import 'package:path/path.dart' as p;

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
      'name': {'type': 'string', 'description': 'Name of the provider'},

      'domain': {
        'type': 'string',
        'description': 'Domain folder for the provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for the provider method',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for the provider method',
      },
      'type': {
        'type': 'string',
        'description': 'Provider method type (sync, stream, completable)',
      },
      // Issue #768: MUST match the positional `zfa provider <Entity>` CLI
      // path (ProviderCommand defaults `data` to true). The previous schema
      // default (`false`) made the documented minimal invocation
      // `zfa provider create --name X` a silent no-op: the provider plugin's
      // gate returned zero files while the command reported success.
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
    final domain = args['domain'];
    final paramsType = args['params'];
    final returnsType = args['returns'];
    final useCaseType = args['type'] ?? 'usecase';
    // Issue #768: semantic default for direct execute() callers that omit
    // the key — same contract as the schema default and the positional CLI
    // path. Explicit values, including `false`, are always honored.
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
      generateInit: args['init'] == true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // Issue #768: a provider implements a service interface — the builder
    // imports `domain/services/<service>_service.dart` for this capability's
    // non-entity-based config (methods: []). Generating without that
    // interface produces a file that cannot compile; generating nothing
    // silently is the #769 family of false success. Validate up front and
    // fail with an actionable message instead.
    if (generateData) {
      final serviceSnake = config.serviceSnake;
      if (serviceSnake != null) {
        final serviceFile = p.join(
          outputDir,
          'domain',
          'services',
          '${serviceSnake}_service.dart',
        );
        if (!File(serviceFile).existsSync()) {
          throw StateError(
            'No service interface found for `${config.effectiveService}`.\n'
            'Expected: $serviceFile\n'
            'A provider implements a service interface, so it cannot be '
            'generated before the service exists. Create the service first:\n'
            '  zfa service create --name ${args['name']}\n'
            'or run the full-stack flow (which generates provider + service '
            'together):\n'
            '  zfa make ${args['name']}',
          );
        }
      }
    }

    return await plugin.generate(config);
  }
}
