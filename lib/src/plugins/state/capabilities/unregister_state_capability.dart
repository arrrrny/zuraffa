import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/register_file_locator.dart';
import '../state_plugin.dart';

class UnregisterStateCapability implements ZuraffaCapability {
  final StatePlugin plugin;
  final AppendExecutor appendExecutor;

  UnregisterStateCapability(this.plugin, {AppendExecutor? appendExecutor})
    : appendExecutor = appendExecutor ?? const AppendExecutor();

  @override
  String get name => 'unregister';

  @override
  String get description => 'Unregister a field from an existing State class';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the field to remove',
      },
      'entity': {'type': 'string', 'description': 'Entity name'},
      'domain': {'type': 'string', 'description': 'Domain folder'},
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force removal',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['target'],
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
    final result = await _runUnregistration(args, dryRun: true);
    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: result.files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final dryRun = args['dryRun'] as bool? ?? false;
    final result = await _runUnregistration(args, dryRun: dryRun);
    return ExecutionResult(
      success: result.success,
      files: result.files.map((f) => f.path).toList(),
      data: {'generatedFiles': result.files},
      message: result.message,
    );
  }

  Future<RegisterResult> _runUnregistration(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final target = args['target'] as String;
    final outputDir = plugin.outputDir;
    final force = args['force'] as bool? ?? false;
    final verbose = args['verbose'] as bool? ?? false;
    final entity = (args['entity'] as String?) ?? target;
    final locator = RegisterFileLocator(outputDir: outputDir);
    var domain = args['domain'] as String?;
    domain ??= locator.inferDomain(target) ?? StringUtils.camelToSnake(entity);

    final statePath = locator.findStateFile(entity, domain);
    if (!File(statePath).existsSync()) {
      return RegisterResult(
        success: false,
        files: [],
        message:
            'State file not found for entity "$entity" in domain "$domain"',
      );
    }
    return _processStateFile(statePath, target, force, verbose, dryRun);
  }

  Future<RegisterResult> _processStateFile(
    String filePath,
    String fieldName,
    bool force,
    bool verbose,
    bool dryRun,
  ) async {
    final file = File(filePath);
    final source = file.readAsStringSync();
    final defaultClassName = StringUtils.convertToPascalCase(
      path.basenameWithoutExtension(filePath).replaceAll('_state', ''),
    );
    final className = '${defaultClassName}State';

    var modifiedSource = source;
    final lines = modifiedSource.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      if (!line.contains(' $fieldName;') &&
          !line.contains('$fieldName:') &&
          !line.contains('$fieldName,')) {
        kept.add(line);
      }
    }
    modifiedSource = kept.join('\n');

    if (dryRun) {
      return RegisterResult(
        success: true,
        files: [
          GeneratedFile(
            path: filePath,
            type: 'state',
            action: 'modified',
            content: modifiedSource,
          ),
        ],
        message: 'Would remove field $fieldName from $className',
      );
    }
    final writtenFile = await FileUtils.writeFile(
      filePath,
      modifiedSource,
      'state',
      force: true,
      dryRun: false,
      verbose: verbose,
    );
    return RegisterResult(
      success: true,
      files: [writtenFile],
      message: 'Unregistered field $fieldName from $className',
    );
  }
}
