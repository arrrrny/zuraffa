import 'dart:io';

import 'package:code_builder/code_builder.dart';

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class RepositoryImplementationGenerator {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;

  RepositoryImplementationGenerator({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
  }) : appendExecutor = appendExecutor ?? AppendExecutor(),
       specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final repoName = '${entityName}Repository';
    final dataRepoName = 'Data${entityName}Repository';

    final dataSourceName = '${entityName}DataSource';
    final localDataSourceName = '${entityName}LocalDataSource';
    final fileName = 'data_${entitySnake}_repository.dart';
    final filePath = '$outputDir/data/repositories/$fileName';

    final importPaths = _buildImportPaths(config, entitySnake);
    final fields = _buildFields(config, dataSourceName, localDataSourceName);
    final constructor = _buildConstructor(config);
    final methods = _buildMethodSpecs(config, entityName, entityCamel);

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [
          Class(
            (b) => b
              ..name = dataRepoName
              ..mixins.addAll([refer('Loggable'), refer('FailureHandler')])
              ..implements.add(refer(repoName))
              ..fields.addAll(fields)
              ..constructors.add(constructor)
              ..methods.addAll(methods),
          ),
        ],
        directives: importPaths.map(Directive.import),
      ),
    );

    if (config.appendToExisting && File(filePath).existsSync()) {
      final existing = await File(filePath).readAsString();
      final importLines = _buildImportLines(importPaths);
      final mergedImports = _mergeImports(existing, importLines);
      final appended = _appendMethods(
        source: mergedImports,
        className: dataRepoName,
        methods: methods.map(_emitMethod).toList(),
      );
      return FileUtils.writeFile(
        filePath,
        appended,
        'data_repository',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'data_repository',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  List<Field> _buildFields(
    GeneratorConfig config,
    String dataSourceName,
    String localDataSourceName,
  ) {
    if (config.generateLocal) {
      return [
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_dataSource',
        ),
      ];
    }
    if (config.enableCache) {
      return [
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(dataSourceName)
            ..name = '_remoteDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(localDataSourceName)
            ..name = '_localDataSource',
        ),
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('CachePolicy')
            ..name = '_cachePolicy',
        ),
      ];
    }
    return [
      Field(
        (f) => f
          ..modifier = FieldModifier.final$
          ..type = refer(dataSourceName)
          ..name = '_dataSource',
      ),
    ];
  }

  Constructor _buildConstructor(GeneratorConfig config) {
    if (config.generateLocal) {
      return Constructor(
        (c) => c
          ..requiredParameters.add(
            Parameter(
              (p) => p
                ..name = '_dataSource'
                ..toThis = true,
            ),
          ),
      );
    }
    if (config.enableCache) {
      return Constructor(
        (c) => c
          ..requiredParameters.addAll([
            Parameter(
              (p) => p
                ..name = '_remoteDataSource'
                ..toThis = true,
            ),
            Parameter(
              (p) => p
                ..name = '_localDataSource'
                ..toThis = true,
            ),
            Parameter(
              (p) => p
                ..name = '_cachePolicy'
                ..toThis = true,
            ),
          ]),
      );
    }
    return Constructor(
      (c) => c
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = '_dataSource'
              ..toThis = true,
          ),
        ),
    );
  }

  List<Method> _buildMethodSpecs(
    GeneratorConfig config,
    String entityName,
    String entityCamel,
  ) {
    final methods = <Method>[];
    if (config.generateInit) {
      final getterTarget = config.enableCache
          ? '_remoteDataSource'
          : '_dataSource';
      methods.add(
        Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..type = MethodType.getter
            ..name = 'isInitialized'
            ..returns = refer('Stream<bool>')
            ..body = Code('return $getterTarget.isInitialized;'),
        ),
      );
      methods.add(
        Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'initialize'
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('InitializationParams'),
              ),
            )
            ..body = Code('return $getterTarget.initialize(params);'),
        ),
      );
    }
    for (final method in config.methods) {
      final spec = _buildMethod(
        config: config,
        method: method,
        entityName: entityName,
        entityCamel: entityCamel,
      );
      if (spec != null) {
        methods.add(spec);
      }
    }
    return methods;
  }

  Method? _buildMethod({
    required GeneratorConfig config,
    required String method,
    required String entityName,
    required String entityCamel,
  }) {
    switch (method) {
      case 'get':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'get'
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..modifier = config.enableCache ? MethodModifier.async : null
            ..body = Code(
              config.enableCache
                  ? '''
if (await _cachePolicy.isValid('${config.nameSnake}_cache')) {
  try {
    return await _localDataSource.get(params);
  } catch (_) {}
}
final data = await _remoteDataSource.get(params);
await _localDataSource.save(data);
await _cachePolicy.markFresh('${config.nameSnake}_cache');
return data;'''
                  : 'return _dataSource.get(params);',
            ),
        );
      case 'getList':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'getList'
            ..returns = refer('Future<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..modifier = config.enableCache ? MethodModifier.async : null
            ..body = Code(
              config.enableCache
                  ? '''
final listCacheKey = '${config.nameSnake}_cache_\${params.hashCode}';
if (await _cachePolicy.isValid(listCacheKey)) {
  try {
    return await _localDataSource.getList(params);
  } catch (_) {}
}
final data = await _remoteDataSource.getList(params);
await _localDataSource.saveAll(data);
await _cachePolicy.markFresh(listCacheKey);
return data;'''
                  : 'return _dataSource.getList(params);',
            ),
        );
      case 'create':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'create'
            ..returns = refer('Future<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = entityCamel
                  ..type = refer(entityName),
              ),
            )
            ..modifier = config.enableCache ? MethodModifier.async : null
            ..body = Code(
              config.enableCache
                  ? '''
final data = await _remoteDataSource.create($entityCamel);
await _localDataSource.save(data);
await _cachePolicy.invalidate('${config.nameSnake}_cache');
return data;'''
                  : 'return _dataSource.create($entityCamel);',
            ),
        );
      case 'update':
        final dataType = config.useZorphy
            ? '${config.name}Patch'
            : 'Partial<${config.name}>';
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'update'
            ..returns = refer('Future<${config.name}>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('UpdateParams<${config.idType}, $dataType>'),
              ),
            )
            ..modifier = config.enableCache ? MethodModifier.async : null
            ..body = Code(
              config.enableCache
                  ? '''
final data = await _remoteDataSource.update(params);
await _localDataSource.save(data);
await _cachePolicy.invalidate('${config.nameSnake}_cache');
return data;'''
                  : 'return _dataSource.update(params);',
            ),
        );
      case 'delete':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'delete'
            ..returns = refer('Future<void>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('DeleteParams<${config.idType}>'),
              ),
            )
            ..modifier = config.enableCache ? MethodModifier.async : null
            ..body = Code(
              config.enableCache
                  ? '''
await _remoteDataSource.delete(params);
await _localDataSource.delete(params);
await _cachePolicy.invalidate('${config.nameSnake}_cache');'''
                  : 'return _dataSource.delete(params);',
            ),
        );
      case 'watch':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'watch'
            ..returns = refer('Stream<$entityName>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('QueryParams<$entityName>'),
              ),
            )
            ..body = Code(
              config.enableCache
                  ? 'return _remoteDataSource.watch(params);'
                  : 'return _dataSource.watch(params);',
            ),
        );
      case 'watchList':
        return Method(
          (b) => b
            ..annotations.add(refer('override'))
            ..name = 'watchList'
            ..returns = refer('Stream<List<$entityName>>')
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'params'
                  ..type = refer('ListQueryParams<$entityName>'),
              ),
            )
            ..body = Code(
              config.enableCache
                  ? 'return _remoteDataSource.watchList(params);'
                  : 'return _dataSource.watchList(params);',
            ),
        );
      default:
        return null;
    }
  }

  List<String> _buildImportPaths(GeneratorConfig config, String entitySnake) {
    final hasWatchMethods = config.methods.any(
      (m) => m == 'watch' || m == 'watchList',
    );
    final asyncImport = config.enableCache && hasWatchMethods
        ? 'dart:async'
        : null;

    final imports = <String>[];
    if (asyncImport != null) {
      imports.add(asyncImport);
    }
    imports.add('package:zuraffa/zuraffa.dart');
    imports.add('../../domain/entities/$entitySnake/$entitySnake.dart');
    imports.add('../../domain/repositories/${entitySnake}_repository.dart');

    if (config.generateLocal) {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
      );
    } else if (config.enableCache) {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
      );
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_local_data_source.dart',
      );
    } else {
      imports.add(
        '../data_sources/$entitySnake/${entitySnake}_data_source.dart',
      );
    }
    return imports;
  }

  List<String> _buildImportLines(List<String> importPaths) {
    return importPaths.map((path) => "import '$path';").toList();
  }

  String _appendMethods({
    required String source,
    required String className,
    required List<String> methods,
  }) {
    var updated = source;
    for (final methodSource in methods) {
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

  String _emitMethod(Method method) {
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    return method.accept(emitter).toString();
  }
}
