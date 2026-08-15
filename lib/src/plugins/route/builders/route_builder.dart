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
import '../../../utils/entity_field_resolver.dart';
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

    // #341: value objects are embedded composition types — no view, no
    // CRUD surface. Never emit routes for them. If a previous run (from
    // before the entity was re-modeled as a value object) left routes
    // behind, clean them up instead of regenerating references to a
    // `<Entity>View` value objects do not have.
    if (!config.noEntity &&
        !config.isCustomUseCase &&
        await _isValueObject(config)) {
      return _cleanupRoutesForValueObject(config);
    }

    files.add(await _generateRouteConstants(config));
    files.add(await _generateEntityRoutes(config));
    final indexFile = await _regenerateIndexFile(pendingFiles: files);
    if (indexFile != null) {
      files.add(indexFile);
    }

    return files;
  }

  /// Whether the entity backing [config] is a Zorphy value object
  /// (`@ZValueObject` / `kind: ZorphyKind.valueObject`).
  Future<bool> _isValueObject(GeneratorConfig config) async {
    final entityPath = path.join(
      outputDir,
      'domain',
      'entities',
      config.nameSnake,
      '${config.nameSnake}.dart',
    );
    if (!await fileSystem.exists(entityPath)) return false;
    return EntityFieldResolver.detectsValueObject(await fileSystem.read(
      entityPath,
    ));
  }

  /// Removes stale route artifacts for an entity that has since been
  /// re-modeled as a value object: the `<entity>_routes.dart` file, its
  /// constants/extension methods in `app_routes.dart`, and its export in
  /// the regenerated `index.dart`. No-op when nothing stale exists.
  Future<List<GeneratedFile>> _cleanupRoutesForValueObject(
    GeneratorConfig config,
  ) async {
    print(
      'ℹ️  "${config.name}" is a value object — skipping route generation '
      '(no view/CRUD surface for embedded types).',
    );

    final files = <GeneratedFile>[];
    final routesPath = path.join(
      outputDir,
      'routing',
      '${config.nameSnake}_routes.dart',
    );
    if (!await fileSystem.exists(routesPath)) {
      return files;
    }

    final appRoutesPath = path.join(outputDir, 'routing', 'app_routes.dart');
    if (await fileSystem.exists(appRoutesPath)) {
      var content = await fileSystem.read(appRoutesPath);
      final helper = const AstHelper();
      final entityPascal = config.name;

      // Method-agnostic cleanup: remove every AppRoutes constant whose
      // value references `<Entity>Routes.` and every goTo<Entity>* Router
      // extension method, regardless of which methods the original run
      // used (the plain revert path needs the same --methods).
      final fieldPattern = RegExp(
        'static\\s+const\\s+String\\s+(\\w+)\\s*=\\s*'
        '${RegExp.escape(entityPascal)}Routes\\.',
        dotAll: true,
      );
      for (final match in fieldPattern.allMatches(content)) {
        content = helper.removeFieldFromClass(
          source: content,
          className: 'AppRoutes',
          fieldName: match.group(1)!,
        );
      }
      final methodPattern = RegExp(
        'void\\s+(goTo${RegExp.escape(entityPascal)}\\w*)\\s*\\(',
      );
      for (final match in methodPattern.allMatches(content)) {
        content = helper.removeMethodFromExtension(
          source: content,
          extensionName: 'RouterExtension',
          methodName: match.group(1)!,
        );
      }

      files.add(
        await FileUtils.writeFile(
          appRoutesPath,
          content,
          'route_constants',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          revert: false,
          fileSystem: fileSystem,
        ),
      );
    }

    files.add(
      await FileUtils.deleteFile(
        routesPath,
        'entity_routes',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      ),
    );

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
    required String detailViewImport,
    required bool hasDetailView,
    required String entityImport,
    required bool referencesEntity,
    required String routeBase,
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

    // Synchronize the optional detail-view import: when the detail-view
    // file no longer exists, drop its now-stale import instead of keeping
    // a reference to a deleted file (which analyze flags as
    // uri_does_not_exist).
    if (!hasDetailView) {
      content = content.replaceAll(
        RegExp("import\\s+'${RegExp.escape(detailViewImport)}';"),
        '',
      );
    }

    // #341: same sync for the entity import — when no emitted route
    // passes the entity named-param anymore, the entity import would be
    // dead code (unused_import) after the route replacement below. Drop
    // it eagerly; the loop below re-adds imports that are still needed.
    if (!referencesEntity) {
      content = content.replaceAll(
        RegExp("import\\s+'${RegExp.escape(entityImport)}';"),
        '',
      );
    }

    final helper = const AstHelper();

    // #333: When the new run does NOT emit a detail GoRoute (because no
    // `<entity>_detail_view.dart` exists on disk), remove any stale
    // detail route from the existing file. Without this cleanup,
    // re-running with --force over a pre-fix routes file (which
    // referenced <Entity>DetailView) would leave the broken stub in
    // place. The route's stable identity is its `name:` field —
    // `'${routeBase}_detail'`.
    if (!hasDetailView) {
      final detailRouteName = '${routeBase}_detail';
      final detailNamePattern = RegExp(
        "name:\\s*'${RegExp.escape(detailRouteName)}'",
      );
      content = helper.removeElementsFromReturnListInFunctionWhere(
        source: content,
        functionName: routesGetterName,
        matches: (elementSource) =>
            detailNamePattern.hasMatch(elementSource),
      );
    }

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

      // The route source changed (e.g. the view class flipped between
      // <Entity>View and <Entity>DetailView when the detail-view file
      // appeared or disappeared). Replace the existing route by its
      // stable `name:` identity instead of appending a second route for
      // the same path and name.
      final nameMatch = RegExp(r"name:\s*'([^']+)'").firstMatch(routeSource);
      final nameIdentity = nameMatch?.group(1);
      if (nameIdentity != null) {
        final identityPattern = RegExp(
          "name:\\s*'${RegExp.escape(nameIdentity)}'",
        );
        content = helper.removeElementsFromReturnListInFunctionWhere(
          source: content,
          functionName: routesGetterName,
          matches: (elementSource) => identityPattern.hasMatch(elementSource),
        );
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

    // #328: Probe the actual view file on disk instead of deriving from the
    // route's own methods list. `zfa view create` only emits a separate
    // `<entity>_detail_view.dart` when the view was generated with BOTH a
    // list method (getList/watchList) AND a detail method (get/watch). When
    // the view was created with different methods than the route (the common
    // smoke-test case: `zfa view create` defaults to `get,update`, then
    // `zfa route create --methods=get,getList` is run later), the detail view
    // file does not exist, and the route must not reference it. Reading the
    // filesystem aligns the route generator with the view generator's actual
    // output and eliminates the `uri_does_not_exist` analyze errors.
    final detailViewPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
      '${entitySnake}_detail_view.dart',
    );
    final hasDetailView = !isCustom && await fileSystem.exists(detailViewPath);
    final detailViewImport =
        '../presentation/pages/$domainSnake/${entitySnake}_detail_view.dart';

    // #341: shared route/view contract — probe the view files on disk for
    // the named params their constructors actually accept (`this.<param>`),
    // and only pass those from the route builders. This keeps routes
    // aligned with regenerated views regardless of which methods each
    // generator run saw (e.g. `zfa make` regenerates views with an empty
    // methods list, which drops the entity named-param).
    final mainViewPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
      '${entitySnake}_view.dart',
    );
    final mainViewParams = await _viewAcceptedParams(mainViewPath);
    final detailViewParams = hasDetailView
        ? await _viewAcceptedParams(detailViewPath)
        : null;

    bool acceptsEntityParam(Set<String>? viewParams) {
      if (config.noEntity || config.isCustomUseCase) return false;
      return viewParams == null || viewParams.contains(config.nameCamel);
    }

    final referencesEntity =
        acceptsEntityParam(mainViewParams) ||
        (hasDetailView && acceptsEntityParam(detailViewParams));

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
          viewParams: mainViewParams,
        ),
      if (!isCustom && !needsListRoute)
        _buildBaseRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewParams: mainViewParams,
        ),
      // #333: only emit the detail GoRoute when the corresponding
      // `<entity>_detail_view.dart` actually exists on disk. When the
      // detail-view file is absent, omit the detail route entirely
      // instead of emitting a "stub" pointing to the main View. The
      // previous behavior (always emit + flip viewName) produced
      // malformed stubs when re-running with --force over a pre-existing
      // routes file — see issue #333.
      if (needsIdRoute && hasDetailView)
        _buildDetailRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewName: '${entityName}DetailView',
          viewParams: detailViewParams,
        ),
      if (hasCreate)
        _buildCreateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewParams: mainViewParams,
        ),
      if (hasUpdate && allowIdRoutes)
        _buildUpdateRouteExpr(
          entityName: entityName,
          entityCamel: entityCamel,
          routeBase: routeBase,
          routeNameBase: routeNameBase,
          viewParam: dependencyInfo.viewParam,
          config: config,
          viewName: hasDetailView
              ? '${entityName}DetailView'
              : '${entityName}View',
          viewParams: hasDetailView ? detailViewParams : mainViewParams,
        ),
    ];

    final entityImport =
        '../domain/entities/$entitySnake/$entitySnake.dart';
    final imports = [
      'package:go_router/go_router.dart',
      'package:zuraffa/zuraffa.dart',
      '../presentation/pages/$domainSnake/${entitySnake}_view.dart',
      if (hasDetailView) detailViewImport,
      // #341: only import the entity when some emitted route actually
      // references it (the entity named-param). Otherwise the import is
      // dead code and analyze flags it as unused.
      if (!config.noEntity && referencesEntity) entityImport,
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
            detailViewImport: detailViewImport,
            hasDetailView: hasDetailView,
            entityImport: entityImport,
            referencesEntity: referencesEntity,
            routeBase: routeBase,
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

  /// Extracts the constructor named-params a generated view class on disk
  /// actually accepts, i.e. `this.<param>` occurrences in its constructor
  /// (`super.key`/`super.routeObserver` are excluded — routes never pass
  /// them). Returns `null` when the view file does not exist or contains
  /// no class declaration (a stub file carries no signal) — callers then
  /// fall back to the historical contract: pass the entity param and the
  /// id param.
  Future<Set<String>?> _viewAcceptedParams(String viewPath) async {
    if (!await fileSystem.exists(viewPath)) return null;
    final source = await fileSystem.read(viewPath);
    if (!RegExp(r'\bclass\s+\w+').hasMatch(source)) return null;
    final params = <String>{};
    for (final match in RegExp(
      r'this\.\s*([a-zA-Z_][a-zA-Z0-9_]*)',
    ).allMatches(source)) {
      params.add(match.group(1)!);
    }
    return params;
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
    Set<String>? viewParams,
  }) {
    final pathExpr = refer('${entityName}Routes').property(routeNameBase);
    final nameExpr = literalString(routeBase);

    final builderExpr = _buildViewBuilderExpr(
      entityName: entityName,
      viewParam: viewParam,
      withId: false,
      config: config,
      viewParams: viewParams,
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
    Set<String>? viewParams,
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
      viewParams: viewParams,
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
    Set<String>? viewParams,
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
      viewParams: viewParams,
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
    Set<String>? viewParams,
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
      viewParams: viewParams,
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
    Set<String>? viewParams,
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
      viewParams: viewParams,
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
    Set<String>? viewParams,
  }) {
    final viewArgs = <String, Expression>{};
    final effectiveViewName = viewName ?? '${entityName}View';

    if (viewParam.isNotEmpty && !config.generateDi) {
      viewArgs[viewParam] = refer(
        'getIt',
      ).call([], {}, [refer('${entityName}Repository')]);
    }

    if (withId) {
      // #336: go_router path parameters are always String; convert to
      // the view's id type (typed after the entity's actual id field).
      final idValue = refer('state')
          .property('pathParameters')
          .index(literalString('id'))
          .nullChecked;
      viewArgs['id'] = switch (config.idFieldType) {
        'int' => refer('int').property('parse').call([idValue]),
        'double' => refer('double').property('parse').call([idValue]),
        'num' => refer('num').property('parse').call([idValue]),
        _ => idValue,
      };
    }

    // #341: shared route/view contract — only pass named-params the view
    // on disk actually accepts (entity and id alike). When the view file
    // exists and contains a real class, its constructor is authoritative:
    // params it dropped (e.g. after `zfa make` regenerated the view with
    // an empty methods list) must not be passed by the route. When there
    // is no view file yet (or only a signal-less stub), fall back to the
    // historical contract of passing both.
    if (viewParams != null) {
      final entityCamel = StringUtils.pascalToCamel(entityName);
      if (!config.noEntity &&
          !config.isCustomUseCase &&
          viewParams.contains(entityCamel)) {
        viewArgs[entityCamel] = refer(
          'state',
        ).property('extra').asA(refer('$entityName?'));
      }
      if (withId && !viewParams.contains('id')) {
        viewArgs.remove('id');
      }
    } else if (!config.noEntity && !config.isCustomUseCase) {
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

  /// Public entry point for the index regeneration logic.
  ///
  /// Used by the deep-link route capability to refresh `routing/index.dart`
  /// (the `getAllRoutes()` aggregator) after writing a new
  /// `<name>_routes.dart` module so the module is picked up without
  /// requiring a full entity-routes run.
  ///
  /// Mirrors [_regenerateIndexFile] with empty `pendingFiles` — the
  /// regenerator already scans the routing directory for all
  /// `*_routes.dart` files on disk, so the newly written module is
  /// discovered automatically.
  Future<GeneratedFile?> regenerateIndex({
    bool dryRun = false,
    bool verbose = false,
  }) async {
    // Apply dry-run / verbose to this call by re-creating the options
    // (the index regenerator reads `options.dryRun` / `options.verbose`
    // directly).
    if (dryRun || verbose) {
      // No-op: the index regenerator uses the RouteBuilder's options,
      // which were set at construction time. The deep-link capability
      // passes a fresh RouteBuilder (via `plugin.routeBuilder`) that
      // already has the correct options from the plugin instance.
    }
    return _regenerateIndexFile(pendingFiles: const []);
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
        if ((f.endsWith('_routes.dart') || f.endsWith('_shell.dart')) &&
            !f.endsWith('index.dart') &&
            !f.endsWith('app_routes.dart')) {
          existingFiles.add(f);
        }
      }
    }

    final pendingPaths = pendingFiles
        .where(
          (f) =>
              (f.path.endsWith('_routes.dart') ||
                  f.path.endsWith('_shell.dart')) &&
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
      Directive.import('package:go_router/go_router.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
    ];
    final routeElements = <Expression>[];

    // #350: a zfa-only app boots at `/` — when no route module claims the
    // root location, emit a root GoRoute that redirects to the app entry
    // (splash if present, else the first generated route) so GoRouter
    // never throws `no routes for location: /`.
    final rootRoute = await _buildRootRouteExpr(allPaths);
    if (rootRoute != null) {
      routeElements.add(rootRoute);
    }

    for (final filePath in allPaths) {
      final fileName = path.basename(filePath);
      // #359: the routing index now aggregates two module kinds:
      //   - <name>_routes.dart -> exports `<camel>Routes()` (List<GoRoute>)
      //   - <name>_shell.dart  -> exports `<camel>ShellRoute()` (List<RouteBase>)
      // The shell module contains a `StatefulShellRoute.indexedStack`
      // (a `RouteBase`, not a `GoRoute`), so `getAllRoutes()` returns
      // `List<RouteBase>` - Dart list covariance keeps the existing
      // `...entityRoutes()` spreads type-checking against the wider type.
      final String getterName;
      if (fileName.endsWith('_shell.dart')) {
        final entitySnake = fileName.replaceAll('_shell.dart', '');
        final entityPascal = StringUtils.convertToPascalCase(entitySnake);
        getterName = '${StringUtils.pascalToCamel(entityPascal)}ShellRoute';
      } else {
        final entitySnake = fileName.replaceAll('_routes.dart', '');
        final entityPascal = StringUtils.convertToPascalCase(entitySnake);
        getterName = '${StringUtils.pascalToCamel(entityPascal)}Routes';
      }

      exports.add(Directive.export(fileName));
      imports.add(Directive.import(fileName));
      routeElements.add(
        refer(getterName).call([]).spread,
      );
    }

    final getAllRoutes = Method(
      (m) => m
        ..name = 'getAllRoutes'
        ..returns = refer('List<RouteBase>')
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

  /// #350: builds the root `/` GoRoute for the routing index so the app
  /// never boots into `GoException: no routes for location: /`.
  ///
  /// Returns `null` when a route module already claims `/` (the app owns
  /// its root) or when no redirect target can be resolved (nothing was
  /// parsed from the route modules — keep the previous behavior).
  ///
  /// Redirect target priority:
  /// 1. a constant named `splash` in any route module,
  /// 2. the first constant of `splash_routes.dart`,
  /// 3. the first constant of the alphabetically first route module.
  Future<Expression?> _buildRootRouteExpr(List<String> allPaths) async {
    var rootClaimed = false;
    String? splashTarget;
    String? firstSplashFileTarget;
    String? firstTarget;

    final sortedPaths = allPaths.toList()..sort();

    for (final filePath in sortedPaths) {
      if (!await fileSystem.exists(filePath)) continue;
      final fileName = path.basename(filePath);
      final entitySnake = fileName.replaceAll('_routes.dart', '');
      final entityPascal = StringUtils.convertToPascalCase(entitySnake);
      final className = '${entityPascal}Routes';

      final constants = _parseRouteConstants(
        await fileSystem.read(filePath),
      );
      if (constants.isEmpty) continue;

      for (final value in constants.values) {
        if (value == '/') {
          rootClaimed = true;
        }
      }

      final firstConstant = constants.keys.first;
      if (splashTarget == null && constants.containsKey('splash')) {
        splashTarget = '$className.splash';
      }
      firstSplashFileTarget ??= fileName == 'splash_routes.dart'
          ? '$className.$firstConstant'
          : null;
      firstTarget ??= '$className.$firstConstant';
    }

    if (rootClaimed) return null;

    final target = splashTarget ?? firstSplashFileTarget ?? firstTarget;
    if (target == null) return null;

    final targetClass = target.split('.').first;
    final targetConstant = target.split('.').last;

    return refer('GoRoute').call([], {
      'path': literalString('/'),
      'name': literalString('root'),
      'redirect': Method(
        (m) => m
          ..requiredParameters.addAll([
            Parameter((p) => p..name = '_'),
            Parameter((p) => p..name = '__'),
          ])
          ..lambda = true
          ..body = refer(targetClass).property(targetConstant).code,
      ).closure,
    });
  }

  /// Parses the `static const String <name> = '<value>';` route path
  /// constants from a generated `<...>_routes.dart` source, in
  /// declaration order.
  Map<String, String> _parseRouteConstants(String source) {
    final constants = <String, String>{};
    final pattern = RegExp(
      r"static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*'([^']*)'\s*;",
    );
    for (final match in pattern.allMatches(source)) {
      constants[match.group(1)!] = match.group(2)!;
    }
    return constants;
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
    if (!content.contains("import 'package:go_router/go_router.dart';")) {
      content = "import 'package:go_router/go_router.dart';\n$content";
    }
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
