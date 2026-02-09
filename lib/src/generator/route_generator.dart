import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
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

  RouteGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

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

    // Determine route info for current entity (use entity name for all cases)
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

    // Build new route constants for this entity
    final newRouteConstants = <String>[
      "  static const String ${routeNameBase}List = '/$routeBase';",
      if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch))
        "  static const String ${routeNameBase}Detail = '\$${routeNameBase}List/:id';",
      if (hasCreate)
        "  static const String ${routeNameBase}Create = '\$${routeNameBase}List/create';",
      if (hasUpdate)
        "  static const String ${routeNameBase}Update = '\$${routeNameBase}List/:id/edit';",
    ];

    // Build extension methods for this entity
    final newExtensionMethods = <String>[
      "  void goTo${entityPascal}List() => go(AppRoutes.${routeNameBase}List);",
      if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch))
        "  void goTo${entityPascal}Detail(String id) => go('${routeBase}/\$id');",
      if (hasCreate)
        "  void goTo${entityPascal}Create() => go(AppRoutes.${routeNameBase}Create);",
      if (hasUpdate)
        "  void goTo${entityPascal}Update(String id) => go('${routeBase}/\$id/edit');",
    ];

    String content;
    if (file.existsSync() && !force) {
      // Update existing file
      final existingContent = file.readAsStringSync();
      content = _updateAppRoutesFile(
        existingContent,
        newRouteConstants,
        newExtensionMethods,
      );
    } else {
      // Create new file
      content = _createAppRoutesFile(newRouteConstants, newExtensionMethods);
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

  String _createAppRoutesFile(
    List<String> routeConstants,
    List<String> extensionMethods,
  ) {
    return '''// Auto-generated route constants
// This file is automatically updated when using --route flag
// Add your custom routes here or modify the generated ones

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract class AppRoutes {
  // Auto-generated routes
${routeConstants.join('\n')}
}

/// Navigation extension methods for BuildContext
extension RouterExtension on BuildContext {
${extensionMethods.join('\n')}
}
''';
  }

  String _updateAppRoutesFile(
    String existingContent,
    List<String> newRouteConstants,
    List<String> newExtensionMethods,
  ) {
    var content = existingContent;

    // Check and add imports if missing
    if (!content.contains("import 'package:flutter/material.dart';")) {
      content = "import 'package:flutter/material.dart';\n" + content;
    }
    if (!content.contains("import 'package:go_router/go_router.dart';")) {
      content = "import 'package:go_router/go_router.dart';\n" + content;
    }

    // Add new route constants before the closing brace of AppRoutes
    final appRoutesEnd = content.lastIndexOf(
      '}',
      content.indexOf('extension RouterExtension'),
    );
    if (appRoutesEnd != -1) {
      final newRoutesBlock = '\n' + newRouteConstants.join('\n');
      content =
          content.substring(0, appRoutesEnd) +
          newRoutesBlock +
          '\n' +
          content.substring(appRoutesEnd);
    }

    // Add new extension methods before the closing brace of RouterExtension
    final extStart = content.indexOf(
      'extension RouterExtension on BuildContext {',
    );
    if (extStart != -1) {
      // Find the matching closing brace
      var braceCount = 1;
      var extEnd =
          extStart + 'extension RouterExtension on BuildContext {'.length;
      while (braceCount > 0 && extEnd < content.length) {
        if (content[extEnd] == '{') braceCount++;
        if (content[extEnd] == '}') braceCount--;
        extEnd++;
      }

      if (braceCount == 0) {
        final newMethodsBlock = '\n' + newExtensionMethods.join('\n');
        content =
            content.substring(0, extEnd - 1) +
            newMethodsBlock +
            '\n' +
            content.substring(extEnd - 1);
      }
    }

    return content;
  }

  Future<GeneratedFile> _generateEntityRoutes() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final entityCamel = config.nameCamel;
    final fileName = '${entitySnake}_routes.dart';

    // Determine import and dependency info first
    final String dependencyImport;
    final String dependencyParam;
    final String viewParam;

    if (config.isEntityBased) {
      dependencyImport =
          "import '../domain/repositories/${entitySnake}_repository.dart';";
      dependencyParam = entityCamel;
      viewParam = '${entityCamel}Repository';
    } else if (config.hasService) {
      // Custom usecase with service
      final serviceName = config.effectiveService!;
      final serviceSnake = config.serviceSnake!;
      dependencyImport =
          "import '../domain/services/${serviceSnake}_service.dart';";
      dependencyParam = _pascalToCamel(serviceName);
      viewParam = dependencyParam;
    } else if (config.hasRepo) {
      // Custom usecase with repository
      final repoName = config.effectiveRepos.first;
      final repoSnake = _camelToSnake(repoName.replaceAll('Repository', ''));
      dependencyImport =
          "import '../domain/repositories/${repoSnake}_repository.dart';";
      dependencyParam = _pascalToCamel(repoName);
      viewParam = dependencyParam;
    } else {
      // Fallback to entity pattern
      dependencyImport =
          "import '../domain/repositories/${entitySnake}_repository.dart';";
      dependencyParam = entityCamel;
      viewParam = '${entityCamel}Repository';
    }

    // Use entity name as route base (e.g., 'product', 'payment_process')
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

    // Build route constants
    final routeConstants = <String>[
      "  static const String ${routeNameBase}List = '/$routeBase';",
      if (hasSubRoutes && (hasUpdate || hasDelete || hasGet || hasWatch))
        "  static const String ${routeNameBase}Detail = '/$routeBase/:id';",
      if (hasCreate)
        "  static const String ${routeNameBase}Create = '/$routeBase/create';",
      if (hasUpdate)
        "  static const String ${routeNameBase}Update = '/$routeBase/:id/edit';",
    ];

    // Build GoRoute entries
    final goRoutes = <String>[
      _buildListRoute(
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
        _buildDetailRoute(
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
        _buildCreateRoute(
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
        _buildUpdateRoute(
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

    final content =
        '''
// Auto-generated routing for $entityName
// Generated by: zfa generate $entityName --vpc${config.generateRoute ? ' --route' : ''}

import 'package:go_router/go_router.dart';
import '../../main.dart';
import '../presentation/pages/$entitySnake/${entitySnake}_view.dart';
$dependencyImport

/// Route paths for $entityName
abstract class ${entityName}Routes {
${routeConstants.join('\n')}
}

/// GoRoute configurations for $entityName
List<GoRoute> get${entityName}Routes() {
  return [
${goRoutes.join(',\n')},
  ];
}
''';
    return FileUtils.writeFile(
      routesPath,
      content,
      'entity_routes',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  String _buildListRoute(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    return '''    GoRoute(
      path: ${entityName}Routes.${routeNameBase}List,
      name: '${routeBase}_list',
      builder: (context, state) => ${entityName}View(
        ${entityCamel}Repository: getIt<${entityName}Repository>(),
      ),
    )''';
  }

  String _buildDetailRoute(
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
    return '''    GoRoute(
      path: ${entityName}Routes.${routeNameBase}Detail,
      name: '${routeBase}_detail',
      builder: (context, state) {
        return ${entityName}View(
          ${entityCamel}Repository: getIt<${entityName}Repository>(),
          id: state.pathParameters['id']!,
        );
      },
    )''';
  }

  String _buildCreateRoute(
    String entityName,
    String entitySnake,
    String entityCamel,
    String routeBase,
    String routeNameBase,
    bool needsIdParam,
    bool needsQueryParam,
    String viewParam,
  ) {
    return '''    GoRoute(
      path: ${entityName}Routes.${routeNameBase}Create,
      name: '${routeBase}_create',
      builder: (context, state) => ${entityName}View(
        ${entityCamel}Repository: getIt<${entityName}Repository>(),
      ),
    )''';
  }

  String _buildUpdateRoute(
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
    return '''    GoRoute(
      path: ${entityName}Routes.${routeNameBase}Update,
      name: '${routeBase}_update',
      builder: (context, state) {
        return ${entityName}View(
          ${entityCamel}Repository: getIt<${entityName}Repository>(),
          id: state.pathParameters['id']!,
        );
      },
    )''';
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

    final exports = <String>["export 'app_routes.dart';"];
    final imports = <String>[];
    final routeGetters = <String>[];

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entityName = fileName.replaceAll('_routes.dart', '');
      final entityPascal = _snakeToPascal(entityName);

      exports.add("export '$fileName';");
      imports.add("import '$fileName';");
      routeGetters.add('  ...get${entityPascal}Routes(),');
    }

    final content =
        '''
// Auto-generated - DO NOT EDIT
${exports.join('\n')}

import 'package:go_router/go_router.dart';
${imports.join('\n')}

/// Get all routes
///
/// Usage:
/// ```dart
/// final router = GoRouter(
///   routes: [
///     ...getAllRoutes(),
///   ],
/// );
/// ```
List<GoRoute> getAllRoutes() {
  return [
${routeGetters.join('\n')}
  ];
}
''';

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
}
