import '../../../core/plugin_system/capability.dart';
import '../method_append_plugin.dart';
import '../builders/method_append_builder.dart';
import '../../../models/generator_config.dart';

class AppendMethodCapability implements ZuraffaCapability {
  final MethodAppendPlugin plugin;

  AppendMethodCapability(this.plugin);

  @override
  String get name => 'append';

  @override
  String get description => 'Append method to Repository or Service';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the method (or usecase name)',
      },
      'repo': {'type': 'string', 'description': 'Target repository name'},
      'service': {'type': 'string', 'description': 'Target service name'},
      'returns': {'type': 'string', 'description': 'Return type'},
      'params': {'type': 'string', 'description': 'Parameter type'},
      'outputDir': {
        'type': 'string',
        'description': 'Directory to output the file',
        'default': 'lib/src',
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
    final result = await _runAppend(args, dryRun: false);

    final writtenFiles = <String>[];
    for (final file in result.updatedFiles) {
      writtenFiles.add(file.path);
    }

    return ExecutionResult(
      success: true,
      files: writtenFiles,
      message: result.warnings.isNotEmpty ? result.warnings.join('\n') : null,
    );
  }

  Future<MethodAppendResult> _runAppend(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = args['outputDir'] ?? 'lib/src';
    final repo = args['repo'];
    final service = args['service'];
    final returns = args['returns'];
    final params = args['params'];

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      repo: repo,
      service: service,
      returnsType: returns,
      paramsType: params,
      appendToExisting: true,
      dryRun: dryRun,
      force: !dryRun,
      verbose: false,
    );

    // We access the builder directly through the plugin if possible, or just call appendMethod
    return await plugin.appendMethod(config);
  }
}
