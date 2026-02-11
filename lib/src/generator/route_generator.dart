import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import '../core/ast/append_executor.dart';
import '../core/ast/strategies/append_strategy.dart';
import '../core/generation/generation_context.dart';
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../plugins/route/builders/app_routes_builder.dart';
import '../plugins/route/builders/entity_routes_builder.dart';
import '../plugins/route/builders/extension_builder.dart';
import '../utils/file_utils.dart';

/// Generates go_router routing files for VPC views.
/// Similar to DiGenerator, creates route constants and GoRoute configurations
/// with automatic barrel exports.
class RouteGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final AppRoutesBuilder appRoutesBuilder;
  final EntityRoutesBuilder entityRoutesBuilder;
  final AppendExecutor appendExecutor;

  RouteGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    AppRoutesBuilder? appRoutesBuilder,
    EntityRoutesBuilder? entityRoutesBuilder,
    AppendExecutor? appendExecutor,
  }) : appRoutesBuilder = appRoutesBuilder ?? AppRoutesBuilder(),
       entityRoutesBuilder = entityRoutesBuilder ?? EntityRoutesBuilder(),
       appendExecutor = appendExecutor ?? AppendExecutor();

  RouteGenerator.fromContext(GenerationContext context)
    : this(
        config: context.config,
        outputDir: context.outputDir,
        dryRun: context.dryRun,
        force: context.force,
        verbose: context.verbose,
      );

  Future<List<GeneratedFile>> generate() async {
    final files = <GeneratedFile>[];

    // Only generate routes if VPC is enabled
    if (!config.generateVpc && !config.generateView) {
      return files;
    }

    // Generate route constants file
    files.add(await _generateRouteConstants());

    // Generate entity-specific route file
    files.add(await _generateEntityRoutes());

    // Regenerate index file
    await _regenerateIndexFile();

    return files;
  }

  Future<GeneratedFile> _generateRouteConstants() async {
    final routesPath = path.join(outputDir, 'routing', 'app_routes.dart');
    final file = File(routesPath);

    final routeBase = config.nameSnake;
    final routeNameBase = config.nameCamel;
    final entityPascal = _snakeToPascal(config.nameSnake);

    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final hasCreate = config.methods.contains('create');
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    final hasSubRoutes =
        hasCreate || hasUpdate || hasDelete || hasGet || hasWatch;

    final routeConstants = _buildAppRouteConstants(
      routeBase: routeBase,
      routeNameBase: routeNameBase,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    final extensionMethods = _buildAppRouteExtensionMethods(
      entityPascal: entityPascal,
      routeBase: routeBase,
      routeNameBase: routeNameBase,
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

  Future<GeneratedFile> _generateEntityRoutes() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final fileName = '${entitySnake}_routes.dart';

    final String dependencyImportPath;
    final String dependencyParam;
    final String viewParam;

    if (config.isEntityBased) {
      dependencyImportPath =
          '../domain/repositories/${entitySnake}_repository.dart';
      dependencyParam = entityCamel;
      viewParam = '${entityCamel}Repository';
    } else if (config.hasService) {
      // Custom usecase with service
      final serviceName = config.effectiveService!;
      final serviceSnake = config.serviceSnake!;
      dependencyImportPath = '../domain/services/${serviceSnake}_service.dart';
      dependencyParam = _pascalToCamel(serviceName);
      viewParam = dependencyParam;
    } else if (config.hasRepo) {
      // Custom usecase with repository
      final repoName = config.effectiveRepos.first;
      final repoSnake = _camelToSnake(repoName.replaceAll('Repository', ''));
      dependencyImportPath =
          '../domain/repositories/${repoSnake}_repository.dart';
      dependencyParam = _pascalToCamel(repoName);
      viewParam = dependencyParam;
    } else {
      // Fallback to entity pattern
      dependencyImportPath =
          '../domain/repositories/${entitySnake}_repository.dart';
      dependencyParam = entityCamel;
      viewParam = '${entityCamel}Repository';
    }

    final routeBase = entitySnake;
    final routeNameBase = entityCamel;

    final routesPath = path.join(outputDir, 'routing', fileName);

    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final hasCreate = config.methods.contains('create');
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    final hasSubRoutes =
        hasCreate || hasUpdate || hasDelete || hasGet || hasWatch;

    // Determine what parameters the view needs
    final needsIdParam = hasUpdate || hasDelete;
    final needsQueryParam = (hasGet || hasWatch) && !needsIdParam;

    final routeConstants = _buildEntityRouteConstants(
      routeBase: routeBase,
      routeNameBase: routeNameBase,
      hasSubRoutes: hasSubRoutes,
      hasCreate: hasCreate,
      hasUpdate: hasUpdate,
      hasDelete: hasDelete,
      hasGet: hasGet,
      hasWatch: hasWatch,
    );

    final goRoutes = <Expression>[
      _buildListRouteExpr(
        entityName,
        entitySnake,
        entityCamel,
        routeBase,
        routeNameBase,
        needsIdParam,
        needsQueryParam,
        viewParam,
      ),
      if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch))
        _buildDetailRouteExpr(
          entityName,
          entitySnake,
          entityCamel,
          routeBase,
          routeNameBase,
          config.idField,
          needsIdParam,
          needsQueryParam,
          viewParam,
        ),
      if (hasCreate)
        _buildCreateRouteExpr(
          entityName,
          entitySnake,
          entityCamel,
          routeBase,
          routeNameBase,
          needsIdParam,
          needsQueryParam,
          viewParam,
        ),
      if (hasUpdate)
        _buildUpdateRouteExpr(
          entityName,
          entitySnake,
          entityCamel,
          routeBase,
          routeNameBase,
          config.idField,
          needsIdParam,
          needsQueryParam,
          viewParam,
        ),
    ];

    final content = entityRoutesBuilder.buildFile(
      className: '${entityName}Routes',
      routes: routeConstants,
      routesGetterName: 'get${entityName}Routes',
      goRoutes: goRoutes,
      imports: [
        'package:go_router/go_router.dart',
        '../../main.dart',
        '../presentation/pages/$entitySnake/${entitySnake}_view.dart',
        dependencyImportPath,
      ],
    );
    return FileUtils.writeFile(
      routesPath,
      content,
      'entity_routes',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Expression _buildListRouteExpr(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    final pathExpr =
        refer('${entityName}Routes').property('${routeNameBase}List');
    final nameExpr = literalString('${routeBase}_list');
    final builderExpr = CodeExpression(Code(
        '(context, state) => ${entityName}View(${entityCamel}Repository: getIt<${entityName}Repository>(),)'));
    return refer('GoRoute').call(
      [],
      {
        'path': pathExpr,
        'name': nameExpr,
        'builder': builderExpr,
      },
    );
  }

  Expression _buildDetailRouteExpr(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    String idField,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    final pathExpr =
        refer('${entityName}Routes').property('${routeNameBase}Detail');
    final nameExpr = literalString('${routeBase}_detail');
    final builderExpr = CodeExpression(Code(
        '''(context, state) {
      return ${entityName}View(
        ${entityCamel}Repository: getIt<${entityName}Repository>(),
        id: state.pathParameters['id']!,
      );
    }'''));
    return refer('GoRoute').call(
      [],
      {
        'path': pathExpr,
        'name': nameExpr,
        'builder': builderExpr,
      },
    );
  }

  Expression _buildCreateRouteExpr(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    final pathExpr =
        refer('${entityName}Routes').property('${routeNameBase}Create');
    final nameExpr = literalString('${routeBase}_create');
    final builderExpr = CodeExpression(Code(
        '(context, state) => ${entityName}View(${entityCamel}Repository: getIt<${entityName}Repository>(),)'));
    return refer('GoRoute').call(
      [],
      {
        'path': pathExpr,
        'name': nameExpr,
        'builder': builderExpr,
      },
    );
  }

  Expression _buildUpdateRouteExpr(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    String idField,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    final pathExpr =
        refer('${entityName}Routes').property('${routeNameBase}Update');
    final nameExpr = literalString('${routeBase}_update');
    final builderExpr = CodeExpression(Code(
        '''(context, state) {
      return ${entityName}View(
        ${entityCamel}Repository: getIt<${entityName}Repository>(),
        id: state.pathParameters['id']!,
      );
    }'''));
    return refer('GoRoute').call(
      [],
      {
        'path': pathExpr,
        'name': nameExpr,
        'builder': builderExpr,
      },
    );
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
    final routeGetters = <String>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entityName = fileName.replaceAll('_routes.dart', '');
      final entityPascal = _snakeToPascal(entityName);

      exports.add(Directive.export(fileName));
      imports.add(Directive.import(fileName));
      routeGetters.add('  ...get${entityPascal}Routes(),');
    }

    final getAllRoutes = Method(
      (m) => m
        ..name = 'getAllRoutes'
        ..returns = refer('List<GoRoute>')
        ..body = Code('return [\n${routeGetters.join('\n')}\n];'),
    );

    final library = entityRoutesBuilder.specLibrary.library(
      specs: [getAllRoutes],
      directives: [...exports, ...imports],
    );
    final content = entityRoutesBuilder.specLibrary.emitLibrary(library);

    await FileUtils.writeFile(
      indexPath,
      content,
      'routes_index',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _snakeToPascal(String input) {
    if (input.isEmpty) return '';
    return input.split('_').map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1);
    }).join();
  }

  String _pascalToCamel(String input) {
    if (input.isEmpty) return '';
    return input[0].toLowerCase() + input.substring(1);
  }

  String _camelToSnake(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 && char.toUpperCase() == char && char != '_') {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }

  Map<String, String> _buildAppRouteConstants({
    required String routeBase,
    required String routeNameBase,
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
    required String routeBase,
    required String routeNameBase,
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
        body: 'go(AppRoutes.${routeNameBase}List)',
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
          body: "go('$routeBase/\$id')",
        ),
      );
    }
    if (hasCreate) {
      methods.add(
        ExtensionMethodSpec(
          name: 'goTo${entityPascal}Create',
          body: 'go(AppRoutes.${routeNameBase}Create)',
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
          body: "go('$routeBase/\$id/edit')",
        ),
      );
    }
    return methods;
  }

  Map<String, String> _buildEntityRouteConstants({
    required String routeBase,
    required String routeNameBase,
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
