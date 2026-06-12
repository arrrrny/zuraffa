import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/register_file_locator.dart';
import '../state_plugin.dart';

/// Capability to register a field in an existing State class.
///
/// This capability appends a field declaration and copyWith entry
/// to an existing State class file.
class RegisterStateCapability implements ZuraffaCapability {
  final StatePlugin plugin;
  final AppendExecutor appendExecutor;

  RegisterStateCapability(this.plugin, {AppendExecutor? appendExecutor})
    : appendExecutor = appendExecutor ?? const AppendExecutor();

  @override
  String get name => 'register';

  @override
  String get description => 'Register a field in an existing State class';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the field to add (e.g., product, items)',
      },
      'type': {
        'type': 'string',
        'description': 'Type of the field (e.g., Product?, List<Item>)',
      },
      'entity': {
        'type': 'string',
        'description': 'Entity name (overrides auto-inference)',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder (overrides auto-inference)',
      },
      'stateName': {
        'type': 'string',
        'description': 'State class name (overrides auto-inference from file)',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing fields',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['target', 'type'],
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
    final result = await _runRegistration(args, dryRun: true);
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
    final result = await _runRegistration(args, dryRun: dryRun);
    return ExecutionResult(
      success: result.success,
      files: result.files.map((f) => f.path).toList(),
      data: {'generatedFiles': result.files},
      message: result.message,
    );
  }

  Future<RegisterResult> _runRegistration(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final target = args['target'] as String;
    final fieldType = args['type'] as String;
    final outputDir = plugin.outputDir;
    final force = args['force'] as bool? ?? false;
    final verbose = args['verbose'] as bool? ?? false;

    // Entity name inference (if not provided, use target as entity)
    // Extract entity from type if not provided (e.g., Product? -> Product)
    final entity =
        (args["entity"] as String?) ??
        fieldType.replaceAll(RegExp(r"[?!]"), "");

    // Infer domain
    final locator = RegisterFileLocator(outputDir: outputDir);
    var domain = args['domain'] as String?;
    domain ??= locator.inferDomain(target) ?? StringUtils.camelToSnake(entity);

    // Find the state file
    final statePath = locator.findStateFile(entity, domain);
    final stateFile = File(statePath);

    if (!stateFile.existsSync()) {
      return RegisterResult(
        success: false,
        files: [],
        message:
            'State file not found for entity "$entity" in domain "$domain"',
      );
    }

    return _processStateFile(
      statePath,
      target,
      fieldType,
      force,
      verbose,
      dryRun,
    );
  }

  Future<RegisterResult> _processStateFile(
    String filePath,
    String fieldName,
    String fieldType,
    bool force,
    bool verbose,
    bool dryRun,
  ) async {
    final file = File(filePath);
    final originalSource = file.readAsStringSync();

    // Determine the state class name from the file or use convention
    final defaultClassName = StringUtils.convertToPascalCase(
      path.basenameWithoutExtension(filePath).replaceAll('_state', ''),
    );
    final className = '${defaultClassName}State';

    if (verbose) {
      print(
        'Registering field $fieldName ($fieldType) in $className at $filePath',
      );
    }

    // Build field source
    final fieldSource = 'final $fieldType $fieldName;';

    // Field append
    final fieldRequest = AppendRequest.field(
      source: originalSource,
      className: className,
      memberSource: fieldSource,
      force: force,
    );
    final fieldResult = appendExecutor.execute(fieldRequest);
    if (!fieldResult.changed &&
        fieldResult.message == 'Duplicate field with different signature') {
      return RegisterResult(
        success: false,
        files: [],
        message:
            'Duplicate field with different signature exists. Use --force to override.',
      );
    }

    // Skip copyWith update for now (needs method body AST manipulation)
    final modifiedSource = fieldResult.source;

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
        message: 'Would add field $fieldName ($fieldType) to $className',
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
      message: 'Registered field $fieldName ($fieldType) in $className',
    );
  }
}
