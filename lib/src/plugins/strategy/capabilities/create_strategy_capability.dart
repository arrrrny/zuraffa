import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../strategy_plugin.dart';

/// Creates strategy skeletons for a given fetch domain.
class CreateStrategyCapability implements ZuraffaCapability {
  final StrategyPlugin plugin;

  CreateStrategyCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description =>
      'Generate FetchStrategy abstract base, concrete variants, and StrategySelector';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description':
            'PascalCase name for the strategy domain (e.g. UrlListing)',
      },
      'strategies': {
        'type': 'string',
        'description':
            'Comma-separated variant names (e.g. scraper,ai). Each becomes a concrete class.',
      },
      'params': {
        'type': 'string',
        'description':
            'Input type for FetchStrategy<Input, Output> (e.g. UrlSpark)',
      },
      'returns': {
        'type': 'string',
        'description':
            'Output type for FetchStrategy<Input, Output> (e.g. Listing)',
      },
      'domain': {
        'type': 'string',
        'description':
            'Provider domain folder (e.g. listing). Defaults to name snake_case.',
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
    'required': ['name', 'strategies'],
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
    final name = args['name'] as String;
    final strategiesRaw = args['strategies'] as String? ?? '';
    final strategyNames = strategiesRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final config = GeneratorConfig(
      name: name,
      outputDir: plugin.outputDir,
      enableStrategy: true,
      strategyNames: strategyNames,
      paramsType: args['params'] as String?,
      returnsType: args['returns'] as String?,
      domain: args['domain'] as String?,
      dryRun: dryRun,
      force: args['force'] ?? false,
      verbose: args['verbose'] ?? false,
    );

    return plugin.generate(config);
  }
}
