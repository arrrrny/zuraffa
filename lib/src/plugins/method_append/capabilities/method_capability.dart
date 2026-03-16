import '../../../core/plugin_system/capability.dart';
import '../../../core/plugin_system/plugin_interface.dart';
import '../builders/method_append_builder.dart';
import '../../../models/generator_config.dart';

class MethodCapability implements ZuraffaCapability {
  final ZuraffaPlugin plugin;
  final MethodAppendBuilder methodAppendBuilder;
  final String
  targetType; // 'service', 'repository', 'datasource', 'provider', 'mock'

  MethodCapability(
    this.plugin, {
    required this.methodAppendBuilder,
    required this.targetType,
  });

  @override
  String get name => 'method';

  @override
  String get description => 'Append a new method to the existing $targetType';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the target (e.g. User, XyzService)',
      },
      'name': {
        'type': 'string',
        'description': 'Name of the method (or usecase name)',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type (e.g. String, List<int>)',
        'default': 'void',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type (e.g. String, MyParams)',
        'default': 'NoParams',
      },
      'type': {
        'type': 'string',
        'description': 'Method type (sync, stream, completable, usecase)',
        'default': 'usecase',
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
    'required': ['target', 'name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'warnings': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final result = await _runAppend(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: result.updatedFiles
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final result = await _runAppend(args, dryRun: args['dryRun'] ?? false);

    final writtenFiles = <String>[];
    for (final file in result.updatedFiles) {
      writtenFiles.add(file.path);
    }

    return ExecutionResult(
      success: true,
      files: writtenFiles,
      message: result.warnings.isNotEmpty ? result.warnings.join('\n') : null,
      data: {'generatedFiles': result.updatedFiles},
    );
  }

  Future<MethodAppendResult> _runAppend(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final target = args['target'];
    final name = args['name'];
    final outputDir = args['outputDir'] ?? 'lib/src';
    final returns = args['returns'] ?? 'void';
    final params = args['params'] ?? 'NoParams';
    final type = args['type'] ?? 'usecase';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // Based on targetType, we set the right config flags
    final config = GeneratorConfig(
      name: target,
      outputDir: outputDir,
      repo:
          targetType == 'repository' ||
              targetType == 'datasource' ||
              targetType == 'mock'
          ? target
          : null,
      service:
          targetType == 'service' ||
              targetType == 'provider' ||
              targetType == 'mock'
          ? target
          : null,
      repoMethod: name,
      serviceMethod: name,
      returnsType: returns,
      paramsType: params,
      useCaseType: type,
      appendToExisting: true,
      generateData: targetType != 'service',
      generateDataSource: targetType == 'datasource' || targetType == 'mock',
      generateMock: targetType == 'mock',
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await methodAppendBuilder.appendMethod(config);
  }
}
