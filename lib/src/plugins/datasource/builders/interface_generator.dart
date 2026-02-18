import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/plugin_system/plugin_action.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class DataSourceInterfaceBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;

  DataSourceInterfaceBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final dataSourceName = '${entityName}DataSource';
    final fileName = '${entitySnake}_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = _buildMethods(config);
    final importPaths = _buildImportPaths(config);

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [
          Class(
            (c) => c
              ..name = dataSourceName
              ..abstract = true
              ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
              ..methods.addAll(methods),
          ),
        ],
        directives: importPaths.map(Directive.import),
      ),
    );

    if (config.verbose) {
      print('Generating datasource interface for ${config.name} at $filePath');
      print('Action: ${config.action}');
    }

    if (config.action == PluginAction.delete) {
      return FileUtils.deleteFile(
        filePath,
        'datasource_interface',
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    if (File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();

      if (config.action == PluginAction.remove) {
        final reverted = _removeMethods(
          source: existing,
          className: dataSourceName,
          methods: methods,
        );
        return FileUtils.writeFile(
          filePath,
          reverted,
          'datasource_interface',
          force: true,
          dryRun: dryRun,
          verbose: verbose,
          revert: false,
        );
      }

      if (config.action == PluginAction.add ||
          config.action == PluginAction.create) {
        if (config.action == PluginAction.create && force) {
          // Fall through to write new file logic
        } else {
          final importLines = _buildImportLines(importPaths);
          final mergedImports = _mergeImports(existing, importLines);
          final appended = _appendMethods(
            source: mergedImports,
            className: dataSourceName,
            methods: methods,
          );
          return FileUtils.writeFile(
            filePath,
            appended,
            'datasource_interface',
            force: true,
            dryRun: dryRun,
            verbose: verbose,
            revert: false,
          );
        }
      }
    }

    if (config.action == PluginAction.remove) {
      return GeneratedFile(path: filePath, type: 'datasource_interface', action: 'skipped');
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'datasource_interface',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      revert: config.revert,
    );
  }

  String _removeMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    final helper = const AstHelper();
    for (final method in methods) {
      final methodName = method.name!;
      updated = helper.removeMethodFromClass(
        source: updated,
        className: className,
        methodName: methodName,
      );
    }
    return updated;
  }

  String _appendMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    for (final method in methods) {
      final methodSource = _emitMethod(method);
      final result = appendExecutor.execute(
        AppendRequest.method(
          source: updated,
          className: className,
          memberSource: methodSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _mergeImports(String source, List<String> imports) {
    var updated = source;
    for (final importLine in imports) {
      if (!updated.contains(importLine)) {
        updated = '$importLine\n$updated';
      }
    }
    return updated;
  }

  List<String> _buildImportLines(List<String> importPaths) {
    return importPaths.map((path) => "import '$path';").toList();
  }

  String _emitMethod(Method method) {
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    return method.accept(emitter).toString();
  }

  List<String> _buildImportPaths(GeneratorConfig config) {
    final entitySnake = config.nameSnake;
    return [
      'package:zuraffa/zuraffa.dart',
      '../../../domain/entities/$entitySnake/$entitySnake.dart',
    ];
  }

  List<Method> _buildMethods(GeneratorConfig config) {
    final methods = <Method>[];
    final entityName = config.name;
    final entityCamel = config.nameCamel;

    if (config.generateInit) {
      methods.add(
        Method(
          (m) => m
            ..name = 'isInitialized'
            ..type = MethodType.getter
            ..returns = refer('Stream<bool>'),
        ),
      );
      methods.add(
        Method(
          (m) => m
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            ),
        ),
      );
    }

    for (final method in config.methods) {
      switch (method) {
        case 'get':
          methods.add(
            Method(
              (m) => m
                ..name = 'get'
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'getList':
          methods.add(
            Method(
              (m) => m
                ..name = 'getList'
                ..returns = refer('Future<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'create':
          methods.add(
            Method(
              (m) => m
                ..name = 'create'
                ..returns = refer('Future<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = entityCamel
                      ..type = refer(entityName),
                  ),
                ),
            ),
          );
          break;
        case 'update':
          final dataType = config.useZorphy
              ? '${config.name}Patch'
              : 'Partial<${config.name}>';
          methods.add(
            Method(
              (m) => m
                ..name = 'update'
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'UpdateParams<${config.idType}, $dataType>',
                      ),
                  ),
                ),
            ),
          );
          break;
        case 'delete':
          methods.add(
            Method(
              (m) => m
                ..name = 'delete'
                ..returns = refer('Future<void>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('DeleteParams<${config.idType}>'),
                  ),
                ),
            ),
          );
          break;
        case 'watch':
          methods.add(
            Method(
              (m) => m
                ..name = 'watch'
                ..returns = refer('Stream<$entityName>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('QueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        case 'watchList':
          methods.add(
            Method(
              (m) => m
                ..name = 'watchList'
                ..returns = refer('Stream<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('ListQueryParams<$entityName>'),
                  ),
                ),
            ),
          );
          break;
        default:
          methods.add(
            Method(
              (m) => m
                ..name = method
                ..returns = refer('Future<void>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('dynamic'),
                  ),
                ),
            ),
          );
      }
    }
    return methods;
  }
}
