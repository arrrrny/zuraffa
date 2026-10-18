import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../utils/entity_utils.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../datasource_provenance.dart';

/// Generates data source interfaces for domain and data layers.
class DataSourceInterfaceBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final AppendExecutor appendExecutor;
  final FileSystem fileSystem;

  DataSourceInterfaceBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    AppendExecutor? appendExecutor,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       fileSystem = fileSystem ?? FileSystem.create();

  static (String, String?, String?) _parseMethodShape(String token) {
    final colon = token.indexOf(':');
    if (colon == -1) return (token.trim(), null, null);
    var name = token.substring(0, colon).trim();
    var shape = token.substring(colon + 1).trim();
    if (shape.startsWith("'") && shape.endsWith("'") && shape.length >= 2) {
      shape = shape.substring(1, shape.length - 1);
    } else if (shape.startsWith('"') &&
        shape.endsWith('"') &&
        shape.length >= 2) {
      shape = shape.substring(1, shape.length - 1);
    }
    String? params;
    String? returns;
    final arrow = shape.indexOf('->');
    if (arrow == -1) {
      params = shape.trim().isEmpty ? null : shape.trim();
    } else {
      final left = shape.substring(0, arrow).trim();
      final right = shape.substring(arrow + 2).trim();
      params = left.isEmpty ? null : left;
      returns = right.isEmpty ? null : right;
    }
    return (name, params, returns);
  }

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final dataSourceName = '${entityName}DataSource';
    final fileName = '${entitySnake}_datasource.dart';

    final dataSourceDirPath = path.join(
      outputDir,
      'data',
      'datasources',
      entitySnake,
    );
    final filePath = path.join(dataSourceDirPath, fileName);

    final methods = <Method>[];

    if (config.isCustomUseCase && config.appendToExisting) {
      final methodName = config.getRepoMethodName();
      var returnType = config.returnsType ?? 'void';
      final paramsType = config.paramsType ?? 'NoParams';

      // Wrap in Future/Stream if not already
      if (config.useCaseType == 'stream' ||
          config.useCaseType == 'streamusecase') {
        if (!returnType.startsWith('Stream<')) {
          returnType = 'Stream<$returnType>';
        }
      } else if (config.useCaseType != 'sync' &&
          config.useCaseType != 'syncusecase') {
        if (!returnType.startsWith('Future<')) {
          returnType = 'Future<$returnType>';
        }
      }

      methods.add(
        Method(
          (m) => m
            ..name = methodName
            ..returns = refer(returnType)
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer(paramsType),
              ),
            ),
        ),
      );
    }

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
      methods.add(
        Method(
          (m) => m
            ..name = 'dispose'
            ..returns = refer('Future<void>'),
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
        // #406: `list` mirrors the repository interface so the generated
        // `DataXRepository.list(NoParams)` delegation to `_dataSource.list`
        // resolves against a real abstract member (otherwise
        // undefined_class / method_not_found on the data source).
        case 'list':
          methods.add(
            Method(
              (m) => m
                ..name = 'list'
                ..returns = refer('Future<List<$entityName>>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer('NoParams'),
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
          // Use Patch for entity-based updates by default
          final dataType = '${config.name}Patch';
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
                        'UpdateParams<${config.idFieldType}, $dataType>',
                      ),
                  ),
                ),
            ),
          );
          break;
        case 'toggle':
          final fieldEnum = 'Field<${config.name}, dynamic>';
          methods.add(
            Method(
              (m) => m
                ..name = 'toggle'
                ..returns = refer('Future<${config.name}>')
                ..requiredParameters.add(
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(
                        'ToggleParams<${config.idFieldType}, $fieldEnum>',
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
                      ..type = refer('DeleteParams<${config.idFieldType}>'),
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
          // Issue #1823 / #1850: allow arbitrary (non-CRUD) verbs as
          // declared data source members. A method token may carry its own
          // shape as `name:params->returns` (issue #1850 "named members"),
          // so a single call can declare a seam whose members take
          // different params and return different types. Tokens without a
          // shape fall back to the call-wide --params/--returns.
          {
            final parsed = _parseMethodShape(method);
            final methodName = parsed.$1;
            final methodParams = parsed.$2 ?? config.paramsType;
            final methodReturns = parsed.$3 ?? config.returnsType;
            final returnType =
                (methodReturns != null && methodReturns.isNotEmpty)
                ? (methodReturns.startsWith('Future<') ||
                          methodReturns.startsWith('Stream<')
                      ? methodReturns
                      : 'Future<$methodReturns>')
                : 'Future<void>';
            final paramsType = (methodParams != null && methodParams.isNotEmpty)
                ? methodParams
                : 'NoParams';
            final m = Method(
              (mm) => mm
                ..name = methodName
                ..returns = refer(returnType)
                ..requiredParameters.addAll(
                  paramsType == 'NoParams'
                      ? const <Parameter>[]
                      : [
                          Parameter(
                            (pp) => pp
                              ..name = 'params'
                              ..type = refer(paramsType),
                          ),
                        ],
                ),
            );
            methods.add(m);
          }
          break;
      }
    }

    // Issue #942: the datasource imports the entity file AND the
    // framework barrel unprefixed. When the entity's name matches a
    // zuraffa core export, the two symbols collide and the generated file
    // fails with `ambiguous_import` errors. The generator knows the
    // entity's own symbols, so the barrel import hides exactly those
    // symbols and the entity's own definitions win resolution. With no
    // locally-imported entity types the hide list stays empty and the
    // import is emitted unchanged.
    final allReturnsTypes = <String>{
      if (config.returnsType != null && config.returnsType!.isNotEmpty)
        config.returnsType!,
      for (final m in config.methods)
        if (_parseMethodShape(m).$3 != null &&
            _parseMethodShape(m).$3!.isNotEmpty)
          _parseMethodShape(m).$3!,
    };
    final barrelHide = <String>{
      if (config.repo == null &&
          fileSystem.existsSync(
            path.join(
              outputDir,
              'domain',
              'entities',
              entitySnake,
              '$entitySnake.dart',
            ),
          ))
        ...EntityUtils.barrelHideNames(entityName),
      for (final rt in allReturnsTypes)
        for (final type in EntityUtils.extractEntityTypes(rt))
          ...EntityUtils.barrelHideNames(type),
    }.toList();

    final directives = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart', hide: barrelHide),
      if (config.repo == null &&
          fileSystem.existsSync(
            path.join(
              outputDir,
              'domain',
              'entities',
              entitySnake,
              '$entitySnake.dart',
            ),
          ))
        Directive.import(
          '../../../domain/entities/$entitySnake/$entitySnake.dart',
        ),
      for (final rt in allReturnsTypes)
        ...EntityUtils.extractEntityTypes(rt).map((type) {
          final snake = StringUtils.camelToSnake(type);
          return Directive.import(
            '../../../domain/entities/$snake/$snake.dart',
          );
        }),
    ];
    final clazz = Class(
      (c) => c
        ..name = dataSourceName
        ..abstract = true
        ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
        ..methods.addAll(methods),
    );

    if (await fileSystem.exists(filePath) &&
        (config.appendToExisting || !config.force)) {
      if (config.revert) {
        if (!config.appendToExisting) {
          return FileUtils.deleteFile(
            filePath,
            'datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        var source = await fileSystem.read(filePath);
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Remove methods directly from host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          final request = AppendRequest.method(
            source: source,
            className: dataSourceName,
            memberSource: methodSource,
          );
          source = appendExecutor.undo(request).source;
        }

        if (const AstHelper().isClassEmpty(source, dataSourceName)) {
          return FileUtils.deleteFile(
            filePath,
            'datasource',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          );
        }

        return FileUtils.writeFile(
          filePath,
          source,
          'datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
          fileSystem: fileSystem,
        );
      }

      if (config.appendToExisting) {
        var source = await fileSystem.read(filePath);
        final emitter = DartEmitter(useNullSafetySyntax: true);

        // 1. Add missing imports
        final importPaths = directives
            .map((d) => (d as dynamic).url as String)
            .toList();
        for (final importPath in importPaths) {
          source = const AstHelper().addImport(
            source: source,
            importPath: importPath,
          );
        }

        // 2. Add methods directly to host file
        for (final method in methods) {
          final methodSource = method.accept(emitter).toString();
          final request = AppendRequest.method(
            source: source,
            className: dataSourceName,
            memberSource: methodSource,
          );
          source = appendExecutor.execute(request).source;
        }

        await FileUtils.writeFile(
          filePath,
          source,
          'datasource',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );

        return GeneratedFile(
          path: filePath,
          type: 'datasource',
          action: 'updated',
        );
      }
    }

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [clazz], directives: directives),
    );

    // Spec #1131 (order 5): the GENERATED provenance header rides ABOVE
    // the emitted library (before the imports); dart_style keeps it in
    // place through FileUtils.writeFile's format pass.
    final withHeader =
        '${DatasourceProvenance.headerFor(entityName, 'datasource interface')}'
        '$content';

    return FileUtils.writeFile(
      filePath,
      withHeader,
      'datasource',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
