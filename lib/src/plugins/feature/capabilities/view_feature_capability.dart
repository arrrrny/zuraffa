import '../../../core/plugin_system/capability.dart';
import '../feature_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../../view/view_plugin.dart';
import '../../../core/generator_options.dart';

class ViewFeatureCapability implements ZuraffaCapability {
  final FeaturePlugin plugin;

  ViewFeatureCapability(this.plugin);

  @override
  String get name => 'view';

  @override
  String get description => 'Add view to an existing feature';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the feature'},
      'id-field': {'type': 'string', 'default': 'id'},
      'id-field-type': {'type': 'string', 'default': 'String'},
      'query-field': {'type': 'string', 'default': 'id'},
      'query-field-type': {'type': 'string', 'default': 'String'},
      'outputDir': {'type': 'string', 'default': 'lib/src'},
      'dryRun': {'type': 'boolean', 'default': false},
      'force': {'type': 'boolean', 'default': false},
      'verbose': {'type': 'boolean', 'default': false},
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
    final files = await _generateFiles(args, dryRun: false);
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
    final outputDir = args['outputDir'] ?? 'lib/src';
    final featureName = args['name'];
    final idField = args['id-field'] as String? ?? 'id';
    final idFieldType = args['id-field-type'] as String? ?? 'String';
    final queryField = args['query-field'] as String? ?? 'id';
    final queryFieldType = args['query-field-type'] as String? ?? 'String';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final revert = args['revert'] ?? false;

    final options = GeneratorOptions(
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final viewPlugin = ViewPlugin(outputDir: outputDir, options: options);

    final config = GeneratorConfig(
      name: featureName,
      outputDir: outputDir,
      generateView: true,
      generateVpcs: true,
      idField: idField,
      idFieldType: idFieldType,
      queryField: queryField,
      queryFieldType: queryFieldType,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      revert: revert,
    );

    return viewPlugin.generate(config);
  }
}
