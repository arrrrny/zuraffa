import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/ast_helper.dart';
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
  final AppRoutesBuilder appRoutesBuilder;
  final EntityRoutesBuilder entityRoutesBuilder;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;
  final DartEmitter emitter;

  /// Creates a [RouteBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param appRoutesBuilder Optional app routes builder override.
  /// @param entityRoutesBuilder Optional entity routes builder override.
  /// @param appendExecutor Optional append executor override.
  /// @param specLibrary Optional spec library override.
  /// @param emitter Optional code emitter override.
  RouteBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    AppRoutesBuilder? appRoutesBuilder,
    EntityRoutesBuilder? entityRoutesBuilder,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
    DartEmitter? emitter,
  }) : appRoutesBuilder = appRoutesBuilder ?? AppRoutesBuilder(),
       entityRoutesBuilder = entityRoutesBuilder ?? EntityRoutesBuilder(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       specLibrary = specLibrary ?? const SpecLibrary(),
       emitter =
           emitter ??
           DartEmitter(orderDirectives: true, useNullSafetySyntax: true);

  /// Generates route files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated route files.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    if (!config.generateRoute) {
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

    final isCustom = config.isCustomUseCase;
    final hasGet = !isCustom && config.methods.contains('get');
    final hasWatch = !isCustom && config.methods.contains('watch');
    final hasCreate = !isCustom && config.methods.contains('create');
    final hasUpdate = !isCustom && config.methods.contains('update');
    final hasDelete = !isCustom && config.methods.contains('delete');
    final hasSubRoutes =
        !isCustom &&
        (hasCreate || hasUpdate || hasDelete || hasGet || hasWatch);

    final domainSnake = config.effectiveDomain;
    final domainPascal = StringUtils.convertToPascalCase(domainSnake);

    final routeConstants = _buildAppRouteConstants(
      routeNameBase: routeNameBase,
      routeBase: routeBase,
      isCustom: isCustom,
      domainPascal: domainPascal,
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
      isCustom: isCustom,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    if (config.revert) {
      if (!file.existsSync()) {
        if (options.verbose) {
          print('  ⏭ File does not exist, skipping revert: $routesPath');
        }
        return GeneratedFile(
          path: routesPath,
          type: 'route_constants',
          action: 'skipped',
        );
      }

      var content = await file.readAsString();
      final helper = const AstHelper();

      for (final fieldName in routeConstants.keys) {
        content = helper.removeFieldFromClass(
          source: content,
          className: 'AppRoutes',
          fieldName: fieldName,
        );
      }

      for (final method in extensionMethods) {
        content = helper.removeMethodFromExtension(
          source: content,
          extensionName: 'RouterExtension',
          methodName: method.name,
        );
      }

      return FileUtils.writeFile(
        routesPath,
        content,
        'route_constants',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: false,
      );
    }

    String content;
    if (file.existsSync()) {
      content = _updateAppRoutesFile(
        existingContent: await file.readAsString(),
        newRouteConstants: routeConstants,
        newExtensionMethods: extensionMethods,
        entitySnake: config.nameSnake,
        isCustom: isCustom,
        domainSnake: domainSnake,
        force: config.force,
      );
    } else {
      content = appRoutesBuilder.buildFile(
        routes: routeConstants,
        extensionMethods: extensionMethods,
        entityRouteImport: isCustom
            ? '${domainSnake}_routes.dart'
            : '${config.nameSnake}_routes.dart',
      );
    }

    return FileUtils.writeFile(
      routesPath,
      content,
      'route_constants',
      force: config.force || file.existsSync(),
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: false,
    );
  }

  String _updateEntityRoutesFile(
    String existingContent, {
    required String className,
    required String routesGetterName,
    required Map<String, String> newRouteConstants,
    required List<Expression> newGoRoutes,
    required List<String> imports,
    bool force = false,
  }) {
    var content = existingContent;

    if (content.isEmpty) {
      return entityRoutesBuilder.buildFile(
        className: className,
        routes: newRouteConstants,
        routesGetterName: routesGetterName,
        goRoutes: newGoRoutes,
        imports: imports,
      );
    }

    // Add imports
    for (final import in imports) {
      if (!content.contains("import '$import';")) {
        content = "import '$import';\n$content";
      }
    }

    final helper = const AstHelper();

    // Add route constants
    for (final entry in newRouteConstants.entries) {
      final fieldSource = entityRoutesBuilder.buildFieldSource(
        entry.key,
        entry.value,
      );
      if (content.contains('static const String ${entry.key} =')) {
        if (force) {
          content = helper.replaceFieldInClass(
            source: content,
            className: className,
            fieldName: entry.key,
            fieldSource: fieldSource,
          );
        }
        continue;
      }
      content = helper.addFieldToClass(
        source: content,
        className: className,
        fieldSource: fieldSource,
      );
    }

    // Add go routes
    for (final routeExpr in newGoRoutes) {
      final routeSource = entityRoutesBuilder.buildRouteSource(routeExpr);

      // Basic normalization for duplicate check: remove spaces, newlines, and trailing commas
      String normalize(String s) => s
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r',\s*\)'), ')')
          .replaceAll(RegExp(r',$'), '');

      final normalizedRouteSource = normalize(routeSource);
      final normalizedContent = normalize(content);

      if (normalizedContent.contains(normalizedRouteSource)) {
        continue;
      }

      content = helper.addElementToReturnListInFunction(
        source: content,
        functionName: routesGetterName,
        elementSource: routeSource,
      );
    }

    return content;
  }

  String _updateAppRoutesFile({
    required String existingContent,
    required Map<String, String> newRouteConstants,
    required List<ExtensionMethodSpec> newExtensionMethods,
    required String entitySnake,
    required bool isCustom,
    required String domainSnake,
    bool force = false,
  }) {
    var content = _ensureAppRoutesImports(existingContent);

    final entityRouteImport = isCustom
        ? '${domainSnake}_routes.dart'
        : '${entitySnake}_routes.dart';
    if (!content.contains(entityRouteImport)) {
      final importLine = "import '$entityRouteImport';";
      if (content.contains('import ')) {
        final lastImportEnd = content.lastIndexOf("';") + 2;
        content =
            '${content.substring(0, lastImportEnd)}\n$importLine${content.substring(lastImportEnd)}';
      } else {
        content = '$importLine\n$content';
      }
    }

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
          force: force,
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
          force: force,
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
    final domainSnake = config.effectiveDomain;
    final isCustom = config.isCustomUseCase;

    final fileName = isCustom
        ? '${domainSnake}_routes.dart'
        : '${entitySnake}_routes.dart';
    final domainPascal = StringUtils.convertToPascalCase(domainSnake);
    final className = isCustom
        ? '${domainPascal}Routes'
        : '${entityName}Routes';
    final routesGetterName = isCustom
        ? '${StringUtils.pascalToCamel(domainPascal)}Routes'
        : '${StringUtils.pascalToCamel(entityName)}Routes';

    final dependencyInfo = _resolveDependencyInfo(
      config,
      entitySnake,
      entityCamel,
    );

    final routesPath = path.join(outputDir, 'routing', fileName);
    final file = File(routesPath);

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;

    final hasGet = !isCustom && config.methods.contains('get');
    final hasWatch = !isCustom && config.methods.contains('watch');
    final hasCreate = !isCustom && config.methods.contains('create');
    final hasUpdate = !isCustom && config.methods.contains('update');
    final hasDelete = !isCustom && config.methods.contains('delete');
    final hasSubRoutes =
        !isCustom &&
        (hasCreate || hasUpdate || hasDelete || hasGet || hasWatch);

    final routeConstants = _buildEntityRouteConstants(
      routeNameBase: routeNameBase,
      routeBase: routeBase,
      isCustom: isCustom,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    final needsIdParam =
        !isCustom && (hasUpdate || hasDelete || hasGet || hasWatch);
    final needsQueryParam =
        !isCustom &&
        (config.methods.contains('getList') ||
            config.methods.contains('watchList'));

    final goRoutes = <Expression>[
      if (isCustom)
        _buildCustomRouteExpr(
          className: className,
          entityName: entityName,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
        ),
      if (needsQueryParam)
        _buildListRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
        ),
      if (needsIdParam)
        _buildDetailRouteExpr(
          config: config,
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
        ),
      if (hasCreate)
        _buildCreateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
        ),
      if (hasUpdate)
        _buildUpdateRouteExpr(
          config: config,
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
        ),
    ];

    final imports = [
      'package:go_router/go_router.dart',
      '../presentation/pages/$domainSnake/${entitySnake}_view.dart',
      if (!config.generateDi) '../di/service_locator.dart',
      if (dependencyInfo.importPath.isNotEmpty) dependencyInfo.importPath,
    ];

    final isUpdate = file.existsSync() || config.appendToExisting;
    final content = isUpdate
        ? _updateEntityRoutesFile(
            file.existsSync() ? await file.readAsString() : '',
            className: className,
            routesGetterName: routesGetterName,
            newRouteConstants: routeConstants,
            newGoRoutes: goRoutes,
            imports: imports,
            force: config.force,
          )
        : entityRoutesBuilder.buildFile(
            className: className,
            routes: routeConstants,
            routesGetterName: routesGetterName,
            goRoutes: goRoutes,
            imports: imports,
          );

    return FileUtils.writeFile(
      routesPath,
      content,
      'entity_routes',
      force: config.force || isUpdate,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  _DependencyInfo _resolveDependencyInfo(
    GeneratorConfig config,
    String entitySnake,
    String entityCamel,
  ) {
    if (config.generateDi) {
      return const _DependencyInfo.empty();
    }

    if (config.isEntityBased) {
      return _DependencyInfo(
        importPath: '../domain/repositories/${entitySnake}_repository.dart',
        viewParam: '${entityCamel}Repository',
      );
    }

    if (config.hasService) {
      final serviceName = config.effectiveService;
      final serviceSnake = config.serviceSnake;
      if (serviceName == null || serviceSnake == null) {
        return const _DependencyInfo.empty();
      }
      return _DependencyInfo(
        importPath: '../domain/services/${serviceSnake}_service.dart',
        viewParam: StringUtils.pascalToCamel(serviceName),
      );
    }

    if (config.hasRepo) {
      final repoName = config.effectiveRepos.first;
      final repoSnake = StringUtils.camelToSnake(
        repoName.replaceAll('Repository', ''),
      );
      return _DependencyInfo(
        importPath: '../domain/repositories/${repoSnake}_repository.dart',
        viewParam: StringUtils.pascalToCamel(repoName),
      );
    }

    return const _DependencyInfo.empty();
  }

  Expression _buildCustomRouteExpr({
    required String className,
    required String entityName,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
  }) {
    final pathExpr = refer(className).property(routeNameBase);
    final nameExpr = literalString(routeBase);

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
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

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildDetailRouteExpr({
    required GeneratorConfig config,
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

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: config.idType != 'NoParams',
    );

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

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildUpdateRouteExpr({
    required GeneratorConfig config,
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

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: config.idType != 'NoParams',
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildViewBuilderExpr({
    required String entityName,
    required String viewParam,
    required bool withId,
  }) {
    final viewArgs = <String, Expression>{};

    if (viewParam.isNotEmpty) {
      viewArgs[viewParam] = refer(
        'getIt',
      ).call([], {}, [refer('${entityName}Repository')]);
    }

    if (withId) {
      viewArgs['id'] = refer(
        'state',
      ).property('pathParameters').index(literalString('id')).nullChecked;
    }

    final hasArgs = viewArgs.isNotEmpty;
    final builderMethod = Method(
      (m) => m
        ..requiredParameters.addAll([
          Parameter((p) => p..name = 'context'),
          Parameter((p) => p..name = 'state'),
        ])
        ..lambda = !hasArgs
        ..body = hasArgs
            ? Block(
                (b) => b
                  ..statements.add(
                    refer(
                      '${entityName}View',
                    ).call([], viewArgs).returned.statement,
                  ),
              )
            : refer('${entityName}View').constInstance([]).code,
    );
    return builderMethod.closure;
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
      if (File(indexPath).existsSync()) {
        if (options.dryRun) {
          if (options.verbose) print('  Dry run: Deleting $indexPath');
        } else {
          File(indexPath).deleteSync();
        }
      }
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
      routeElements.add(
        refer(
          '${StringUtils.pascalToCamel(entityPascal)}Routes',
        ).call([]).spread,
      );
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
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }

  Map<String, String> _buildAppRouteConstants({
    required String routeNameBase,
    required String routeBase,
    required bool isCustom,
    required String domainPascal,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    if (isCustom) {
      return {routeNameBase: '${domainPascal}Routes.$routeNameBase'};
    }
    final entityPascal = StringUtils.convertToPascalCase(routeBase);
    final routes = <String, String>{
      '${routeNameBase}List': '${entityPascal}Routes.${routeNameBase}List',
    };

    if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch)) {
      routes['${routeNameBase}Detail'] =
          '${entityPascal}Routes.${routeNameBase}Detail';
    }
    if (hasCreate) {
      routes['${routeNameBase}Create'] =
          '${entityPascal}Routes.${routeNameBase}Create';
    }
    if (hasUpdate) {
      routes['${routeNameBase}Update'] =
          '${entityPascal}Routes.${routeNameBase}Update';
    }
    return routes;
  }

  List<ExtensionMethodSpec> _buildAppRouteExtensionMethods({
    required String entityPascal,
    required String routeNameBase,
    required String routeBase,
    required bool isCustom,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    final methodName = isCustom
        ? 'goTo$entityPascal'
        : 'goTo${entityPascal}List';
    final propertyName = isCustom ? routeNameBase : '${routeNameBase}List';

    final methods = <ExtensionMethodSpec>[
      ExtensionMethodSpec(
        name: methodName,
        body: refer('go').call([refer('AppRoutes').property(propertyName)]),
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
    required bool isCustom,
    required bool hasSubRoutes,
    required bool hasCreate,
    required bool hasUpdate,
    required bool hasDelete,
    required bool hasGet,
    required bool hasWatch,
  }) {
    if (isCustom) {
      return {routeNameBase: '/$routeBase'};
    }
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

class _DependencyInfo {
  final String importPath;
  final String viewParam;

  const _DependencyInfo({required this.importPath, required this.viewParam});

  const _DependencyInfo.empty() : importPath = '', viewParam = '';
}
