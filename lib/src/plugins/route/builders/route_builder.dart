import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import 'app_routes_builder.dart';
import 'entity_routes_builder.dart';
import 'extension_builder.dart';

/// Generates application routes and entity route definitions.
///
/// Produces app-level route constants and entity-specific route builders,
/// updating index files when needed.
///
/// Example:
/// ```dart
/// final builder = RouteBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class RouteBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppRoutesBuilder appRoutesBuilder;
  final EntityRoutesBuilder entityRoutesBuilder;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;

  /// Creates a [RouteBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param appRoutesBuilder Optional app routes builder override.
  /// @param entityRoutesBuilder Optional entity routes builder override.
  /// @param appendExecutor Optional append executor override.
  /// @param specLibrary Optional spec library override.
  RouteBuilder({
    required this.outputDir,
    GeneratorOptions options = const GeneratorOptions(),
    @Deprecated('Use options.dryRun') bool? dryRun,
    @Deprecated('Use options.force') bool? force,
    @Deprecated('Use options.verbose') bool? verbose,
    AppRoutesBuilder? appRoutesBuilder,
    EntityRoutesBuilder? entityRoutesBuilder,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
  })  : options = options.copyWith(
          dryRun: dryRun ?? options.dryRun,
          force: force ?? options.force,
          verbose: verbose ?? options.verbose,
        ),
        dryRun = dryRun ?? options.dryRun,
        force = force ?? options.force,
        verbose = verbose ?? options.verbose,
        appRoutesBuilder = appRoutesBuilder ?? AppRoutesBuilder(),
        entityRoutesBuilder = entityRoutesBuilder ?? EntityRoutesBuilder(),
        appendExecutor = appendExecutor ?? AppendExecutor(),
        specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates route files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated route files.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    if (!config.generateVpc && !config.generateView) {
      return files;
    }

    files.add(await _generateRouteConstants(config));
    files.add(await _generateEntityRoutes(config));
    await _regenerateIndexFile();

    return files;
  }

  Future<GeneratedFile> _generateRouteConstants(GeneratorConfig config) async {
    final routesPath = path.join(outputDir, 'routing', 'app_routes.dart');
    final file = File(routesPath);

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;
    final entityPascal = config.name;

    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final hasCreate = config.methods.contains('create');
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    final hasSubRoutes =
        hasCreate || hasUpdate || hasDelete || hasGet || hasWatch;

    final routeConstants = _buildAppRouteConstants(
      routeNameBase: routeNameBase,
      routeBase: routeBase,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    final extensionMethods = _buildAppRouteExtensionMethods(
      entityPascal: entityPascal,
      routeNameBase: routeNameBase,
      routeBase: routeBase,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    String content;
    if (file.existsSync() && !force) {
      final existingContent = file.readAsStringSync();
      content = _updateAppRoutesFile(
        existingContent,
        routeConstants,
        extensionMethods,
      );
    } else {
      content = appRoutesBuilder.buildFile(
        routes: routeConstants,
        extensionMethods: extensionMethods,
      );
    }

    return FileUtils.writeFile(
      routesPath,
      content,
      'route_constants',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _updateAppRoutesFile(
    String existingContent,
    Map<String, String> newRouteConstants,
    List<ExtensionMethodSpec> newExtensionMethods,
  ) {
    var content = _ensureAppRoutesImports(existingContent);

    if (!content.contains('class AppRoutes') ||
        !content.contains('extension RouterExtension')) {
      return appRoutesBuilder.buildFile(
        routes: newRouteConstants,
        extensionMethods: newExtensionMethods,
      );
    }

    for (final entry in newRouteConstants.entries) {
      final fieldSource = appRoutesBuilder.buildFieldSource(
        entry.key,
        entry.value,
      );
      final result = appendExecutor.execute(
        AppendRequest.field(
          source: content,
          className: 'AppRoutes',
          memberSource: fieldSource,
        ),
      );
      content = result.source;
    }

    for (final method in newExtensionMethods) {
      final methodSource = appRoutesBuilder.buildMethodSource(method);
      final result = appendExecutor.execute(
        AppendRequest.extensionMethod(
          source: content,
          className: 'RouterExtension',
          memberSource: methodSource,
        ),
      );
      content = result.source;
    }

    return content;
  }

  Future<GeneratedFile> _generateEntityRoutes(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final fileName = '${entitySnake}_routes.dart';

    final String dependencyImportPath;
    final String viewParam;

    if (config.isEntityBased) {
      dependencyImportPath =
          '../domain/repositories/${entitySnake}_repository.dart';
      viewParam = '${entityCamel}Repository';
    } else if (config.hasService) {
      final serviceName = config.effectiveService;
      final serviceSnake = config.serviceSnake;
      if (serviceName == null || serviceSnake == null) {
        dependencyImportPath = '';
        viewParam = '';
      } else {
        dependencyImportPath =
            '../domain/services/${serviceSnake}_service.dart';
        viewParam = StringUtils.pascalToCamel(serviceName);
      }
    } else if (config.hasRepo) {
      final repoName = config.effectiveRepos.first;
      final repoSnake = StringUtils.camelToSnake(
        repoName.replaceAll('Repository', ''),
      );
      dependencyImportPath =
          '../domain/repositories/${repoSnake}_repository.dart';
      viewParam = StringUtils.pascalToCamel(repoName);
    } else {
      dependencyImportPath = '';
      viewParam = '';
    }

    final routesPath = path.join(outputDir, 'routing', fileName);

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;

    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final hasCreate = config.methods.contains('create');
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    final hasSubRoutes =
        hasCreate || hasUpdate || hasDelete || hasGet || hasWatch;

    final routeConstants = _buildEntityRouteConstants(
      routeNameBase: routeNameBase,
      routeBase: routeBase,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    final needsIdParam = hasUpdate || hasDelete || hasGet || hasWatch;
    final needsQueryParam =
        config.methods.contains('getList') ||
        config.methods.contains('watchList');

    final goRoutes = <Expression>[
      if (needsQueryParam)
        _buildListRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: viewParam,
        ),
      if (needsIdParam)
        _buildDetailRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: viewParam,
        ),
      if (hasCreate)
        _buildCreateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: viewParam,
        ),
      if (hasUpdate)
        _buildUpdateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: viewParam,
        ),
    ];

    final imports = [
      'package:go_router/go_router.dart',
      '../../main.dart',
      '../presentation/pages/$entitySnake/${entitySnake}_view.dart',
      if (dependencyImportPath.isNotEmpty) dependencyImportPath,
    ];

    final content = entityRoutesBuilder.buildFile(
      className: '${entityName}Routes',
      routes: routeConstants,
      routesGetterName: 'get${entityName}Routes',
      goRoutes: goRoutes,
      imports: imports,
    );

    return FileUtils.writeFile(
      routesPath,
      content,
      'entity_routes',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Expression _buildListRouteExpr({
    required String entityName,
    required String entityCamel,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}List');
    final nameExpr = literalString('${routeBase}_list');

    final builderExpr = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'state'),
        ])
        ..lambda = true
        ..body = refer('${entityName}View').call([], {
          viewParam: refer(
            'getIt',
          ).call([], {}, [refer('${entityName}Repository')]),
        }).code,
    ).closure;

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildDetailRouteExpr({
    required String entityName,
    required String entityCamel,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Detail');
    final nameExpr = literalString('${routeBase}_detail');

    final builderExpr = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'state'),
        ])
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('${entityName}View')
                  .call([], {
                    viewParam: refer(
                      'getIt',
                    ).call([], {}, [refer('${entityName}Repository')]),
                    'id': refer('state')
                        .property('pathParameters')
                        .index(literalString('id'))
                        .nullChecked,
                  })
                  .returned
                  .statement,
            ),
        ),
    ).closure;

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildCreateRouteExpr({
    required String entityName,
    required String entityCamel,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Create');
    final nameExpr = literalString('${routeBase}_create');

    final builderExpr = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'state'),
        ])
        ..lambda = true
        ..body = refer('${entityName}View').call([], {
          viewParam: refer(
            'getIt',
          ).call([], {}, [refer('${entityName}Repository')]),
        }).code,
    ).closure;

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildUpdateRouteExpr({
    required String entityName,
    required String entityCamel,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Update');
    final nameExpr = literalString('${routeBase}_update');

    final builderExpr = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'state'),
        ])
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('${entityName}View')
                  .call([], {
                    viewParam: refer(
                      'getIt',
                    ).call([], {}, [refer('${entityName}Repository')]),
                    'id': refer('state')
                        .property('pathParameters')
                        .index(literalString('id'))
                        .nullChecked,
                  })
                  .returned
                  .statement,
            ),
        ),
    ).closure;

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Future<void> _regenerateIndexFile() async {
    final dirPath = path.join(outputDir, 'routing');
    final indexPath = path.join(dirPath, 'index.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('_routes.dart') &&
              !f.path.endsWith('index.dart') &&
              !f.path.endsWith('app_routes.dart'),
        )
        .toList();

    if (files.isEmpty) {
      return;
    }

    final exports = <Directive>[Directive.export('app_routes.dart')];
    final imports = <Directive>[
      Directive.import('package:go_router/go_router.dart'),
    ];
    final routeElements = <Expression>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entitySnake = fileName.replaceAll('_routes.dart', '');
      final entityPascal = StringUtils.convertToPascalCase(entitySnake);

      exports.add(Directive.export(fileName));
      imports.add(Directive.import(fileName));
      routeElements.add(refer('get${entityPascal}Routes').call([]).spread);
    }

    final getAllRoutes = Method(
      (m) => m
        ..name = 'getAllRoutes'
        ..returns = refer('List<GoRoute>')
        ..body = literalList(routeElements).returned.statement,
    );

    final library = specLibrary.library(
      specs: [getAllRoutes],
      directives: [...exports, ...imports],
    );
    final content = specLibrary.emitLibrary(library);

    await FileUtils.writeFile(
      indexPath,
      content,
      'routes_index',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Map<String, String> _buildAppRouteConstants({
    required String routeNameBase,
    required String routeBase,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    final routes = <String, String>{'${routeNameBase}List': '/$routeBase'};

    if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch)) {
      routes['${routeNameBase}Detail'] = '\$${routeNameBase}List/:id';
    }
    if (hasCreate) {
      routes['${routeNameBase}Create'] = '\$${routeNameBase}List/create';
    }
    if (hasUpdate) {
      routes['${routeNameBase}Update'] = '\$${routeNameBase}List/:id/edit';
    }
    return routes;
  }

  List<ExtensionMethodSpec> _buildAppRouteExtensionMethods({
    required String entityPascal,
    required String routeNameBase,
    required String routeBase,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    final methods = <ExtensionMethodSpec>[
      ExtensionMethodSpec(
        name: 'goTo${entityPascal}List',
        body: refer(
          'go',
        ).call([refer('AppRoutes').property('${routeNameBase}List')]),
      ),
    ];

    if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch)) {
      methods.add(
        ExtensionMethodSpec(
          name: 'goTo${entityPascal}Detail',
          parameters: [
            Parameter(
              (p) => p
                ..name = 'id'
                ..type = refer('String'),
            ),
          ],
          body: refer('go').call([literalString('$routeBase/\$id')]),
        ),
      );
    }
    if (hasCreate) {
      methods.add(
        ExtensionMethodSpec(
          name: 'goTo${entityPascal}Create',
          body: refer(
            'go',
          ).call([refer('AppRoutes').property('${routeNameBase}Create')]),
        ),
      );
    }
    if (hasUpdate) {
      methods.add(
        ExtensionMethodSpec(
          name: 'goTo${entityPascal}Update',
          parameters: [
            Parameter(
              (p) => p
                ..name = 'id'
                ..type = refer('String'),
            ),
          ],
          body: refer('go').call([literalString('$routeBase/\$id/edit')]),
        ),
      );
    }
    return methods;
  }

  Map<String, String> _buildEntityRouteConstants({
    required String routeNameBase,
    required String routeBase,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    final routes = <String, String>{'${routeNameBase}List': '/$routeBase'};

    if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch)) {
      routes['${routeNameBase}Detail'] = '/$routeBase/:id';
    }
    if (hasCreate) {
      routes['${routeNameBase}Create'] = '/$routeBase/create';
    }
    if (hasUpdate) {
      routes['${routeNameBase}Update'] = '/$routeBase/:id/edit';
    }
    return routes;
  }

  String _ensureAppRoutesImports(String source) {
    var content = source;
    if (!content.contains("import 'package:flutter/material.dart';")) {
      content = "import 'package:flutter/material.dart';\n$content";
    }
    if (!content.contains("import 'package:go_router/go_router.dart';")) {
      content = "import 'package:go_router/go_router.dart';\n$content";
    }
    return content;
  }
}
