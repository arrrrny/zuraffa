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
import '../controller_plugin.dart';

class RegisterControllerCapability implements ZuraffaCapability {
  final ControllerPlugin plugin;
  final AppendExecutor appendExecutor;

  RegisterControllerCapability(this.plugin, {AppendExecutor? appendExecutor})
    : appendExecutor = appendExecutor ?? const AppendExecutor();

  @override
  String get name => 'register';

  @override
  String get description => 'Register a use case in an existing Controller';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description': 'Name of the use case to register',
      },
      'entity': {'type': 'string', 'description': 'Entity name'},
      'domain': {'type': 'string', 'description': 'Domain folder'},
      'controllerName': {
        'type': 'string',
        'description': 'Controller class name',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Verbose logging',
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
    final outputDir = plugin.outputDir;
    final force = args['force'] as bool? ?? false;
    final verbose = args['verbose'] as bool? ?? false;
    final resolved = UseCaseNameResolver.resolve(target);
    final entity = (args['entity'] as String?) ?? resolved.entityName;
    final verbPrefix = resolved.verbPrefix ?? 'Get';
    final locator = RegisterFileLocator(outputDir: outputDir);
    var domain = args['domain'] as String?;
    domain ??= locator.inferDomain(target) ?? StringUtils.camelToSnake(entity);

    final controllerPath = locator.findControllerFile(entity, domain);
    if (!File(controllerPath).existsSync()) {
      return RegisterResult(
        success: false,
        files: [],
        message: 'Controller file not found',
      );
    }
    return _processControllerFile(
      controllerPath,
      target,
      entity,
      verbPrefix,
      force,
      verbose,
      dryRun,
    );
  }

  Future<RegisterResult> _processControllerFile(
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
      path.basenameWithoutExtension(filePath).replaceAll('_controller', ''),
    );
    final className = '${defaultClassName}Controller';
    final useCaseName = UseCaseNameResolver.buildUseCaseClassName(
      verbPrefix,
      entity,
    );
    final fieldName = UseCaseNameResolver.buildFieldName(verbPrefix, entity);

    final fieldSource = 'late final $useCaseName $fieldName;';
    final fieldRequest = AppendRequest.field(
      source: originalSource,
      className: className,
      memberSource: fieldSource,
      force: force,
    );
    final fieldResult = appendExecutor.execute(fieldRequest);

    final constructorStatement =
        '$fieldName = registerUseCase(getIt<$useCaseName>());';
    final modifiedWithStatement = insertIntoConstructorBody(
      fieldResult.source,
      className,
      constructorStatement,
    );

    final entitySnake = StringUtils.camelToSnake(entity);
    final importPath =
        "package:your_app/domain/usecases/$entitySnake/${entitySnake}_usecase.dart";
    final importRequest = AppendRequest.import(
      source: modifiedWithStatement,
      importPath: importPath,
    );
    final importResult = appendExecutor.execute(importRequest);
    final modifiedSource = importResult.source;

    if (dryRun) {
      return RegisterResult(
        success: true,
        files: [
          GeneratedFile(
            path: filePath,
            type: 'controller',
            action: 'modified',
            content: modifiedSource,
          ),
        ],
        message: 'Would add $useCaseName to $className',
      );
    }
    final writtenFile = await FileUtils.writeFile(
      filePath,
      modifiedSource,
      'controller',
      force: true,
      dryRun: false,
      verbose: verbose,
    );
    return RegisterResult(
      success: true,
      files: [writtenFile],
      message: 'Registered $useCaseName in $className',
    );
  }
}
