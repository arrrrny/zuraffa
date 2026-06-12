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

class RegisterPresenterCapability implements ZuraffaCapability {
  final PresenterPlugin plugin;
  final AppendExecutor appendExecutor;

  RegisterPresenterCapability(this.plugin, {AppendExecutor? appendExecutor})
    : appendExecutor = appendExecutor ?? const AppendExecutor();

  @override
  String get name => 'register';

  @override
  String get description => 'Register a use case in an existing Presenter';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'target': {
        'type': 'string',
        'description':
            'Name of the use case to register (e.g., GetProduct, CreateCustomer)',
      },
      'entity': {
        'type': 'string',
        'description':
            'Entity name (overrides auto-inference from use case name)',
      },
      'domain': {
        'type': 'string',
        'description':
            'Domain folder (overrides auto-inference from filesystem scan)',
      },
      'presenterName': {
        'type': 'string',
        'description':
            'Presenter class name (overrides auto-inference from file)',
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

    final presenterPath = locator.findPresenterFile(entity, domain);
    final presenterFile = File(presenterPath);

    if (!presenterFile.existsSync()) {
      final altPath = await _findPresenterFileByScan(entity, outputDir);
      if (altPath != null) {
        return _processPresenterFile(
          altPath,
          target,
          entity,
          verbPrefix,
          force,
          verbose,
          dryRun,
        );
      }
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
      print('Registering $useCaseName as $className.$fieldName in $filePath');
    }

    final fieldSource = 'late final $useCaseName $fieldName;';
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

    final constructorStatement =
        '$fieldName = registerUseCase(getIt<$useCaseName>());';
    final modifiedWithStatement = insertIntoConstructorBody(
      fieldResult.source,
      className,
      constructorStatement,
    );

    final entitySnake = StringUtils.camelToSnake(entity);
    final importPath =
        "package:your_app/domain/usecases/${StringUtils.camelToSnake(entity)}/${entitySnake}_usecase.dart";
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
            type: 'presenter',
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
      'presenter',
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

  Future<String?> _findPresenterFileByScan(
    String entity,
    String outputDir,
  ) async {
    final pagesDir = Directory(path.join(outputDir, 'presentation', 'pages'));
    if (!pagesDir.existsSync()) return null;
    final entitySnake = StringUtils.camelToSnake(entity);
    for (final domainDir in pagesDir.listSync().whereType<Directory>()) {
      final filePath = path.join(
        domainDir.path,
        '${entitySnake}_presenter.dart',
      );
      if (File(filePath).existsSync()) return filePath;
    }
    return null;
  }
}
