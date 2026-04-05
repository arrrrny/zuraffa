import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/ast/append_executor.dart';
import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/strategies/append_strategy.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import 'app_routes_builder.dart';
import 'entity_routes_builder.dart';
import 'extension_builder.dart';

/// Generates application routes and entity route definitions.
class RouteBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final AppRoutesBuilder appRoutesBuilder;
  final EntityRoutesBuilder entityRoutesBuilder;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;
  final DartEmitter emitter;
  final FileSystem fileSystem;
  final DiscoveryEngine? discovery;

  /// Creates a [RouteBuilder].
  RouteBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    AppRoutesBuilder? appRoutesBuilder,
    EntityRoutesBuilder? entityRoutesBuilder,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
    DartEmitter? emitter,
    FileSystem? fileSystem,
    this.discovery,
  }) : appRoutesBuilder = appRoutesBuilder ?? AppRoutesBuilder(),
       entityRoutesBuilder = entityRoutesBuilder ?? EntityRoutesBuilder(),
       appendExecutor = appendExecutor ?? AppendExecutor(),
       specLibrary = specLibrary ?? const SpecLibrary(),
       emitter =
           emitter ??
           DartEmitter(orderDirectives: true, useNullSafetySyntax: true),
       fileSystem = fileSystem ?? FileSystem.create();

  /// Generates route files for the given [config].
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];

    if (!config.generateRoute) {
      return files;
    }

    files.add(await _generateRouteConstants(config));
    files.add(await _generateEntityRoutes(config));
    final indexFile = await _regenerateIndexFile(pendingFiles: files);
    if (indexFile != null) {
      files.add(indexFile);
    }

    return files;
  }

  Future<GeneratedFile> _generateRouteConstants(GeneratorConfig config) async {
    final routesPath = path.join(outputDir, 'routing', 'app_routes.dart');

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;
    final entityPascal = config.name;

    final isCustom = config.isCustomUseCase;
    final hasGet = !isCustom && config.methods.contains('get');
    final hasWatch = !isCustom && config.methods.contains('watch');
    final hasCreate = !isCustom && config.methods.contains('create');
    final hasUpdate = !isCustom && config.methods.contains('update');
    final hasDelete = !isCustom && config.methods.contains('delete');
    final hasGetList = !isCustom && config.methods.contains('getList');
    final hasWatchList = !isCustom && config.methods.contains('watchList');
    final allowIdRoutes = config.idFieldType != 'NoParams';
    final hasSubRoutes =
        !isCustom &&
        allowIdRoutes &&
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
      hasGetList: hasGetList,
      hasWatchList: hasWatchList,
      allowIdRoutes: allowIdRoutes,
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
      hasGetList: hasGetList,
      hasWatchList: hasWatchList,
      allowIdRoutes: allowIdRoutes,
    );

    if (config.revert) {
      if (!await fileSystem.exists(routesPath)) {
        if (options.verbose) {
          print('  ⏭ File does not exist, skipping revert: $routesPath');
        }
        return GeneratedFile(
          path: routesPath,
          type: 'route_constants',
          action: 'skipped',
        );
      }

      var content = await fileSystem.read(routesPath);
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
        fileSystem: fileSystem,
      );
    }

    String content;
    final exists = await fileSystem.exists(routesPath);
    if (exists) {
      content = _updateAppRoutesFile(
        existingContent: await fileSystem.read(routesPath),
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
        entityRouteImport: './index.dart',
        leadingComment: '// Generated by zfa',
      );
    }

    return FileUtils.writeFile(
      routesPath,
      content,
      'route_constants',
      force: config.force || exists,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: false,
      fileSystem: fileSystem,
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

    final entityRouteImport = './index.dart';

    if (content.contains(entityRouteImport)) {
      content = content.replaceAll(RegExp(r"import '\w+_routes\.dart';\n"), '');
      content = content.replaceAll(RegExp(r'\n\s*\n'), '\n');
    }

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
        entityRouteImport: './index.dart',
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

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;

    final hasGet = !isCustom && config.methods.contains('get');
    final hasWatch = !isCustom && config.methods.contains('watch');
    final hasCreate = !isCustom && config.methods.contains('create');
    final hasUpdate = !isCustom && config.methods.contains('update');
    final hasDelete = !isCustom && config.methods.contains('delete');
    final hasGetList = !isCustom && config.methods.contains('getList');
    final hasWatchList = !isCustom && config.methods.contains('watchList');
    final allowIdRoutes = config.idFieldType != 'NoParams';
    final hasSubRoutes =
        !isCustom &&
        allowIdRoutes &&
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
      hasGetList: hasGetList,
      hasWatchList: hasWatchList,
      allowIdRoutes: allowIdRoutes,
    );

    final needsIdRoute =
        !isCustom &&
        allowIdRoutes &&
        (hasUpdate || hasDelete || hasGet || hasWatch);
    final needsListRoute =
        !isCustom &&
        (config.methods.contains('getList') ||
            config.methods.contains('watchList'));

    final hasDetailView =
        !isCustom &&
        (config.methods.contains('get') || config.methods.contains('watch'));
    final hasListView =
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
          config: config,
        ),
      if (needsListRoute)
        _buildListRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
        ),
      if (!isCustom && !needsListRoute)
        _buildBaseRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
        ),
      if (needsIdRoute)
        _buildDetailRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewName: (hasListView && hasDetailView)
              ? '${entityName}DetailView'
              : '${entityName}View',
        ),
      if (hasCreate)
        _buildCreateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
        ),
      if (hasUpdate && allowIdRoutes)
        _buildUpdateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewName: (hasListView && hasDetailView)
              ? '${entityName}DetailView'
              : '${entityName}View',
        ),
    ];

    final imports = [
      'package:zuraffa/zuraffa.dart',
      '../presentation/pages/$domainSnake/${entitySnake}_view.dart',
      if (hasListView && hasDetailView)
        '../presentation/pages/$domainSnake/${entitySnake}_detail_view.dart',
      if (!config.noEntity) '../domain/entities/$entitySnake/$entitySnake.dart',
      if (dependencyInfo.importPath.isNotEmpty) dependencyInfo.importPath,
    ];

    if (config.revert) {
      if (!await fileSystem.exists(routesPath)) {
        if (options.verbose) {
          print('  ⏭ File does not exist, skipping revert: $routesPath');
        }
        return GeneratedFile(
          path: routesPath,
          type: 'entity_routes',
          action: 'skipped',
        );
      }

      var content = await fileSystem.read(routesPath);
      final helper = const AstHelper();

      for (final fieldName in routeConstants.keys) {
        content = helper.removeFieldFromClass(
          source: content,
          className: className,
          fieldName: fieldName,
        );
      }

      for (final routeExpr in goRoutes) {
        final routeSource = entityRoutesBuilder.buildRouteSource(routeExpr);
        content = helper.removeElementFromReturnListInFunction(
          source: content,
          functionName: routesGetterName,
          elementSource: routeSource,
        );
      }

      if (helper.isClassEmpty(content, className)) {
        return FileUtils.deleteFile(
          routesPath,
          'entity_routes',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      return FileUtils.writeFile(
        routesPath,
        content,
        'entity_routes',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: false,
        fileSystem: fileSystem,
      );
    }

    final exists = await fileSystem.exists(routesPath);
    final isUpdate = exists || config.appendToExisting;
    final leadingComment = '// Generated by zfa for: ${config.name}';

    final content = isUpdate
        ? _updateEntityRoutesFile(
            exists ? await fileSystem.read(routesPath) : '',
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
            leadingComment: leadingComment,
          );

    return FileUtils.writeFile(
      routesPath,
      content,
      'entity_routes',
      force: config.force || isUpdate,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fileSystem,
    );
  }

  _DependencyInfo _resolveDependencyInfo(
    GeneratorConfig config,
    String entitySnake,
    String entityCamel,
  ) {
    return const _DependencyInfo.empty();
  }

  Expression _buildCustomRouteExpr({
    required String className,
    required String entityName,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
    required GeneratorConfig config,
  }) {
    final pathExpr = refer(className).property(routeNameBase);
    final nameExpr = literalString(routeBase);

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
      config: config,
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildBaseRouteExpr({
    required String entityName,
    required String entityCamel,
    required String routeBase,
    required String routeNameBase,
    required String viewParam,
    required GeneratorConfig config,
  }) {
    final pathExpr = refer('${entityName}Routes').property(routeNameBase);
    final nameExpr = literalString(routeBase);

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
      config: config,
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
    required GeneratorConfig config,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}List');
    final nameExpr = literalString('${routeBase}_list');

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
      config: config,
    );

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
    required GeneratorConfig config,
    String? viewName,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Detail');
    final nameExpr = literalString('${routeBase}_detail');

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: config.idFieldType != 'NoParams',
      config: config,
      viewName: viewName,
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
    required GeneratorConfig config,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Create');
    final nameExpr = literalString('${routeBase}_create');

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
      config: config,
    );

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
    required GeneratorConfig config,
    String? viewName,
  }) {
    final pathExpr = refer(
      '${entityName}Routes',
    ).property('${routeNameBase}Update');
    final nameExpr = literalString('${routeBase}_update');

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: config.idFieldType != 'NoParams',
      config: config,
      viewName: viewName,
    );

    return refer(
      'GoRoute',
    ).call([], {'path': pathExpr, 'name': nameExpr, 'builder': builderExpr});
  }

  Expression _buildViewBuilderExpr({
    required String entityName,
    required String viewParam,
    required bool withId,
    required GeneratorConfig config,
    String? viewName,
  }) {
    final viewArgs = <String, Expression>{};
    final effectiveViewName = viewName ?? '${entityName}View';

    if (viewParam.isNotEmpty && !config.generateDi) {
      viewArgs[viewParam] = refer(
        'getIt',
      ).call([], {}, [refer('${entityName}Repository')]);
    }

    if (withId) {
      viewArgs['id'] = refer(
        'state',
      ).property('pathParameters').index(literalString('id')).nullChecked;
    }

    if (!config.noEntity && !config.isCustomUseCase) {
      final entityCamel = StringUtils.pascalToCamel(entityName);
      viewArgs[entityCamel] = refer(
        'state',
      ).property('extra').asA(refer('$entityName?'));
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
                      effectiveViewName,
                    ).call([], viewArgs).returned.statement,
                  ),
              )
            : refer(effectiveViewName).constInstance([]).code,
    );
    return builderMethod.closure;
  }

  Future<GeneratedFile?> _regenerateIndexFile({
    List<GeneratedFile> pendingFiles = const [],
  }) async {
    final dirPath = path.join(outputDir, 'routing');
    final indexPath = path.join(dirPath, 'index.dart');

    if (!await fileSystem.exists(dirPath)) {
      return null;
    }

    final dirs = await fileSystem.list(dirPath);
    final existingFiles = <String>[];
    for (final f in dirs) {
      if (!await fileSystem.isDirectory(f)) {
        if (f.endsWith('_routes.dart') &&
            !f.endsWith('index.dart') &&
            !f.endsWith('app_routes.dart')) {
          existingFiles.add(f);
        }
      }
    }

    final pendingPaths = pendingFiles
        .where(
          (f) =>
              f.path.endsWith('_routes.dart') &&
              !f.path.endsWith('index.dart') &&
              !f.path.endsWith('app_routes.dart') &&
              f.action != 'deleted',
        )
        .map((f) => f.path)
        .toList();

    final deletedPaths = pendingFiles
        .where((f) => f.action == 'deleted')
        .map((f) => path.canonicalize(f.path))
        .toSet();

    final allPaths = {...existingFiles, ...pendingPaths}
        .map((p) => path.canonicalize(p))
        .toSet()
        .where((p) => !deletedPaths.contains(p))
        .toList();

    if (allPaths.isEmpty) {
      if (await fileSystem.exists(indexPath)) {
        if (options.dryRun) {
          if (options.verbose) print('  Dry run: Deleting $indexPath');
        } else {
          await fileSystem.delete(indexPath);
        }
      }
      return null;
    }

    final exports = <Directive>[Directive.export('app_routes.dart')];
    final imports = <Directive>[
      Directive.import('package:zuraffa/zuraffa.dart'),
    ];
    final routeElements = <Expression>[];

    for (final filePath in allPaths) {
      final fileName = path.basename(filePath);
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
    final content = specLibrary.emitLibrary(
      library,
      leadingComment: '// Generated by zfa',
    );

    return await FileUtils.writeFile(
      indexPath,
      content,
      'routes_index',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
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
    required bool hasGetList,
    required bool hasWatchList,
    required bool allowIdRoutes,
  }) {
    if (isCustom) {
      return {routeNameBase: '${domainPascal}Routes.$routeNameBase'};
    }
    final entityPascal = StringUtils.convertToPascalCase(routeBase);
    final hasList = hasGetList || hasWatchList;

    final routes = <String, String>{};

    if (hasList) {
      routes['${routeNameBase}List'] =
          '${entityPascal}Routes.${routeNameBase}List';
    } else {
      routes[routeNameBase] = '${entityPascal}Routes.$routeNameBase';
    }

    if (allowIdRoutes &&
        hasSubRoutes &&
        (hasUpdate || hasDelete || hasGet || hasWatch)) {
      routes['${routeNameBase}Detail'] =
          '${entityPascal}Routes.${routeNameBase}Detail';
    }
    if (hasCreate) {
      routes['${routeNameBase}Create'] =
          '${entityPascal}Routes.${routeNameBase}Create';
    }
    if (allowIdRoutes && hasUpdate) {
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
    required bool hasGetList,
    required bool hasWatchList,
    required bool allowIdRoutes,
  }) {
    final hasList = hasGetList || hasWatchList;
    final methodName = isCustom
        ? 'goTo$entityPascal'
        : hasList
        ? 'goTo${entityPascal}List'
        : 'goTo$entityPascal';
    final propertyName = isCustom
        ? routeNameBase
        : hasList
        ? '${routeNameBase}List'
        : routeNameBase;

    final methods = <ExtensionMethodSpec>[
      ExtensionMethodSpec(
        name: methodName,
        body: refer('go').call([refer('AppRoutes').property(propertyName)]),
      ),
    ];

    if (allowIdRoutes &&
        hasSubRoutes &&
        (hasUpdate || hasDelete || hasGet || hasWatch)) {
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
          body: refer('go').call([literalString('/$routeBase/\$id')]),
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
    if (allowIdRoutes && hasUpdate) {
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
          body: refer('go').call([literalString('/$routeBase/\$id/edit')]),
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
    required bool hasGetList,
    required bool hasWatchList,
    required bool allowIdRoutes,
  }) {
    if (isCustom) {
      return {routeNameBase: '/$routeBase'};
    }
    final hasList = hasGetList || hasWatchList;
    final routes = <String, String>{};

    if (hasList) {
      routes['${routeNameBase}List'] = '/$routeBase';
    } else {
      routes[routeNameBase] = '/$routeBase';
    }

    if (allowIdRoutes &&
        hasSubRoutes &&
        (hasUpdate || hasDelete || hasGet || hasWatch)) {
      routes['${routeNameBase}Detail'] = '/$routeBase/:id';
    }
    if (hasCreate) {
      routes['${routeNameBase}Create'] = '/$routeBase/create';
    }
    if (allowIdRoutes && hasUpdate) {
      routes['${routeNameBase}Update'] = '/$routeBase/:id/edit';
    }
    return routes;
  }

  String _ensureAppRoutesImports(String source) {
    var content = source;
    if (!content.contains("import 'package:flutter/material.dart';")) {
      content = "import 'package:flutter/material.dart';\n$content";
    }
    if (!content.contains("import 'package:zuraffa/zuraffa.dart';")) {
      content = "import 'package:zuraffa/zuraffa.dart';\n$content";
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
