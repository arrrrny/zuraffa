import 'dart:io';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/use_case_name_resolver.dart';
import '../../../utils/register_file_locator.dart';
import '../presenter_plugin.dart';

/// Capability to unregister (remove) a use case from an existing Presenter.
class UnregisterPresenterCapability implements ZuraffaCapability {
  final PresenterPlugin plugin;
  final AppendExecutor appendExecutor;

  UnregisterPresenterCapability(this.plugin, {AppendExecutor? appendExecutor})
    : appendExecutor = appendExecutor ?? const AppendExecutor();

  @override
  String get name => 'unregister';

  @override
  String get description => 'Unregister a use case from an existing Presenter';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description':
            'Name of the use case to unregister (e.g., DeleteProduct)',
      },
      'entity': {
        'type': 'string',
        'description':
            'Entity name (overrides auto-inference from use case name)',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder (overrides auto-inference)',
      },
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

    final resolved = UseCaseNameResolver.resolve(target);
    final entity = (args['entity'] as String?) ?? resolved.entityName;
    final verbPrefix = resolved.verbPrefix ?? 'Get';

    final locator = RegisterFileLocator(outputDir: outputDir);
    var domain = args['domain'] as String?;
    domain ??= locator.inferDomain(target) ?? StringUtils.camelToSnake(entity);

    final presenterPath = locator.findPresenterFile(entity, domain);
    final presenterFile = File(presenterPath);

    if (!presenterFile.existsSync()) {
      return RegisterResult(
        success: false,
        files: [],
        message:
            'Presenter file not found for entity "$entity" in domain "$domain"',
      );
    }

    return _processPresenterFile(
      presenterPath,
      target,
      entity,
      verbPrefix,
      force,
      verbose,
      dryRun,
    );
  }

  Future<RegisterResult> _processPresenterFile(
    String filePath,
    String target,
    String entity,
    String verbPrefix,
    bool force,
    bool verbose,
    bool dryRun,
  ) async {
    final file = File(filePath);
    final originalSource = file.readAsStringSync();

    final defaultClassName = StringUtils.convertToPascalCase(
      path.basenameWithoutExtension(filePath).replaceAll('_presenter', ''),
    );
    final className = '${defaultClassName}Presenter';

    final useCaseName = UseCaseNameResolver.buildUseCaseClassName(
      verbPrefix,
      entity,
    );
    final fieldName = UseCaseNameResolver.buildFieldName(verbPrefix, entity);

    if (verbose) {
      print('Unregistering $useCaseName from $className in $filePath');
    }

    final fieldSource = 'late final $useCaseName $fieldName;';
    final constructorStatement =
        '$fieldName = registerUseCase(getIt<$useCaseName>());';
    final entitySnake = StringUtils.camelToSnake(entity);
    final importPath =
        "package:your_app/domain/usecases/$entitySnake/${entitySnake}_usecase.dart";

    // 1. Remove constructor registration statement (string-based removal)
    var modifiedSource = _removeLineContaining(
      originalSource,
      constructorStatement,
    );

    // 2. Remove field using undo
    final fieldRequest = AppendRequest.field(
      source: modifiedSource,
      className: className,
      memberSource: fieldSource,
      force: force,
    );
    final fieldResult = appendExecutor.undo(fieldRequest);
    modifiedSource = fieldResult.source;

    // 3. Remove import using undo
    final importRequest = AppendRequest.import(
      source: modifiedSource,
      importPath: importPath,
    );
    final importResult = appendExecutor.undo(importRequest);
    modifiedSource = importResult.source;

    if (dryRun) {
      return RegisterResult(
        success: true,
        files: [
          GeneratedFile(
            path: filePath,
            type: 'presenter',
            action: 'modified',
            content: modifiedSource,
          ),
        ],
        message: 'Would remove $useCaseName from $className',
      );
    }

    final writtenFile = await FileUtils.writeFile(
      filePath,
      modifiedSource,
      'presenter',
      force: true,
      dryRun: false,
      verbose: verbose,
    );

    return RegisterResult(
      success: true,
      files: [writtenFile],
      message: 'Unregistered $useCaseName from $className',
    );
  }

  String _removeLineContaining(String source, String content) {
    final lines = source.split('\n');
    final result = <String>[];
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (!trimmed.startsWith(content.substring(0, content.indexOf('('))) &&
          !trimmed.startsWith(
            content.substring(0, content.indexOf('=')).trim(),
          ) &&
          !trimmed.contains(content.trim())) {
        result.add(line);
      }
    }
    return result.join('\n');
  }
}
