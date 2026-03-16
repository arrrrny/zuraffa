import '../../../core/plugin_system/capability.dart';
import '../../../core/plugin_system/plugin_interface.dart';
import '../builders/inject_builder.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class InjectCapability implements ZuraffaCapability {
  final ZuraffaPlugin plugin;
  final InjectBuilder injectBuilder;
  final String targetType; // 'datasource', 'provider', 'mock'

  InjectCapability(
    this.plugin, {
    required this.injectBuilder,
    required this.targetType,
  });

  @override
  String get name => 'inject';

  @override
  String get description => 'Inject a dependency into the existing $targetType';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the target class (e.g. XyzProvider)',
      },
      'dependency': {
        'type': 'string',
        'description': 'Name of the dependency class (e.g. AuthService, AuthRepository)',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
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
    'required': ['target', 'dependency'],
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
    final result = await _runInject(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: result
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final result = await _runInject(args, dryRun: args['dryRun'] ?? false);

    return ExecutionResult(
      success: true,
      files: result.map((f) => f.path).toList(),
      data: {'generatedFiles': result},
    );
  }

  Future<List<GeneratedFile>> _runInject(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final target = args['target'];
    final dependency = args['dependency'];

    return await injectBuilder.inject(
      targetClass: target,
      dependencyName: dependency,
      targetType: targetType,
    );
  }
}
