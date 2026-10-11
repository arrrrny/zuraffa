// MCP Server 2.0 — arch.inspect and arch.refactor capabilities.

import 'dart:io';

import 'package:path/path.dart' as p;

class ArchEntity {
  final String name;
  final String path;
  final List<ArchField> fields;
  final bool hasJson;
  final bool isSealed;
  final String? superClass;

  const ArchEntity({
    required this.name,
    required this.path,
    this.fields = const [],
    this.hasJson = false,
    this.isSealed = false,
    this.superClass,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'fields': fields.map((f) => f.toJson()).toList(),
    'hasJson': hasJson,
    'isSealed': isSealed,
    if (superClass != null) 'extends': superClass,
  };
}

class ArchField {
  final String name;
  final String type;
  final bool isNullable;

  const ArchField({
    required this.name,
    required this.type,
    this.isNullable = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'nullable': isNullable,
  };
}

class ArchUseCase {
  final String name;
  final String path;
  final String entity;
  final String? returnType;
  final String? paramsType;

  const ArchUseCase({
    required this.name,
    required this.path,
    required this.entity,
    this.returnType,
    this.paramsType,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'entity': entity,
    if (returnType != null) 'returns': returnType,
    if (paramsType != null) 'params': paramsType,
  };
}

class ArchRepository {
  final String name;
  final String path;
  final String entity;
  final bool hasDataImpl;

  const ArchRepository({
    required this.name,
    required this.path,
    required this.entity,
    this.hasDataImpl = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'entity': entity,
    'hasDataImpl': hasDataImpl,
  };
}

class ArchDataSource {
  final String name;
  final String path;
  final String entity;
  final bool isRemote;
  final bool isLocal;

  const ArchDataSource({
    required this.name,
    required this.path,
    required this.entity,
    this.isRemote = false,
    this.isLocal = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'entity': entity,
    'isRemote': isRemote,
    'isLocal': isLocal,
  };
}

class ArchPresentation {
  final String name;
  final String path;
  final String entity;
  final String type;

  const ArchPresentation({
    required this.name,
    required this.path,
    required this.entity,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'entity': entity,
    'type': type,
  };
}

class ArchitectureModel {
  final String projectRoot;
  final List<ArchEntity> entities;
  final List<ArchUseCase> useCases;
  final List<ArchRepository> repositories;
  final List<ArchDataSource> dataSources;
  final List<ArchPresentation> presentation;
  final List<Map<String, dynamic>> diRegistrations;
  final List<Map<String, dynamic>> routes;

  const ArchitectureModel({
    required this.projectRoot,
    this.entities = const [],
    this.useCases = const [],
    this.repositories = const [],
    this.dataSources = const [],
    this.presentation = const [],
    this.diRegistrations = const [],
    this.routes = const [],
  });

  Map<String, dynamic> toJson() => {
    'projectRoot': projectRoot,
    'entities': entities.map((e) => e.toJson()).toList(),
    'useCases': useCases.map((u) => u.toJson()).toList(),
    'repositories': repositories.map((r) => r.toJson()).toList(),
    'dataSources': dataSources.map((d) => d.toJson()).toList(),
    'presentation': presentation.map((pr) => pr.toJson()).toList(),
    'diRegistrations': diRegistrations,
    'routes': routes,
    'stats': {
      'entityCount': entities.length,
      'useCaseCount': useCases.length,
      'repositoryCount': repositories.length,
      'dataSourceCount': dataSources.length,
      'presentationCount': presentation.length,
    },
  };
}

/// Scans a zuraffa project and returns the full architecture model.
class ArchInspector {
  final String projectRoot;

  ArchInspector({required this.projectRoot});

  Future<ArchitectureModel> inspect() async {
    return ArchitectureModel(
      projectRoot: projectRoot,
      entities: await _scanEntities(),
      useCases: await _scanUseCases(),
      repositories: await _scanRepositories(),
      dataSources: await _scanDataSources(),
      presentation: await _scanPresentation(),
      diRegistrations: await _scanDI(),
      routes: await _scanRoutes(),
    );
  }

  /// List .dart files recursively under [dirPath].
  Future<List<File>> _listDartFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
    return files;
  }

  Future<List<ArchEntity>> _scanEntities() async {
    final results = <ArchEntity>[];
    final entityBase = p.join(projectRoot, 'lib', 'src', 'domain', 'entities');
    final dir = Directory(entityBase);
    if (!await dir.exists()) return results;

    await for (final subdir in dir.list()) {
      if (subdir is! Directory) continue;
      final name = p.basename(subdir.path);
      final entityFile = File(p.join(subdir.path, '$name.dart'));
      if (!await entityFile.exists()) continue;

      final content = await entityFile.readAsString();
      final fields = _extractFields(content);
      final hasJson =
          content.contains('fromJson') || content.contains('toJson');
      final isSealed =
          content.contains('sealed class') || content.contains('sealed mixin');
      final extendsMatch = RegExp(
        r'class\s+\w+\s+extends\s+(\w+)',
      ).firstMatch(content);

      results.add(
        ArchEntity(
          name: _toPascalCase(name),
          path: p.relative(entityFile.path, from: projectRoot),
          fields: fields,
          hasJson: hasJson,
          isSealed: isSealed,
          superClass: extendsMatch?.group(1),
        ),
      );
    }
    return results;
  }

  List<ArchField> _extractFields(String content) {
    final fields = <ArchField>[];
    final fieldRegex = RegExp(r'final\s+(\w+)(\?)?\s+(\w+)\s*;');
    const skipNames = {'hashCode', 'runtimeType', 'props'};
    final classMatch = RegExp(r'class\s+\$?(\w+)').firstMatch(content);
    if (classMatch == null) return fields;
    final classBody = content.substring(classMatch.end);
    for (final match in fieldRegex.allMatches(classBody)) {
      final name = match.group(3)!;
      if (skipNames.contains(name) || name.startsWith('_')) continue;
      fields.add(
        ArchField(
          name: name,
          type: match.group(1)!,
          isNullable: match.group(2) != null,
        ),
      );
    }
    return fields;
  }

  Future<List<ArchUseCase>> _scanUseCases() async {
    final results = <ArchUseCase>[];
    for (final file in await _listDartFiles(
      p.join(projectRoot, 'lib', 'src', 'domain', 'usecases'),
    )) {
      final content = await file.readAsString();
      final classMatch = RegExp(r'class\s+(\w+UseCase)').firstMatch(content);
      if (classMatch == null) continue;
      final name = classMatch.group(1)!;
      final returnMatch = RegExp(r'Future<(\w+)').firstMatch(content);
      final paramsMatch = RegExp(r'call\((\w+)').firstMatch(content);
      results.add(
        ArchUseCase(
          name: name,
          path: p.relative(file.path, from: projectRoot),
          entity: _extractEntityFromUseCase(name),
          returnType: returnMatch?.group(1),
          paramsType: paramsMatch?.group(1),
        ),
      );
    }
    return results;
  }

  String _extractEntityFromUseCase(String useCaseName) {
    const prefixes = [
      'Get',
      'Create',
      'Update',
      'Delete',
      'Remove',
      'Watch',
      'GetAll',
      'GetList',
      'WatchList',
    ];
    var stripped = useCaseName;
    if (stripped.endsWith('UseCase')) {
      stripped = stripped.substring(0, stripped.length - 7);
    }
    for (final prefix in prefixes) {
      if (stripped.startsWith(prefix)) return stripped.substring(prefix.length);
    }
    return stripped;
  }

  Future<List<ArchRepository>> _scanRepositories() async {
    final results = <ArchRepository>[];
    for (final file in await _listDartFiles(
      p.join(projectRoot, 'lib', 'src', 'domain', 'repositories'),
    )) {
      final content = await file.readAsString();
      final classMatch = RegExp(
        r'(?:abstract\s+)?class\s+(\w+(?:Repository)?)',
      ).firstMatch(content);
      if (classMatch == null) continue;
      final name = classMatch.group(1)!;
      final entityName = _extractEntityFromName(name);
      final dataRepoPath = p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'repositories',
        '${_toSnakeCase(name)}.dart',
      );
      results.add(
        ArchRepository(
          name: name,
          path: p.relative(file.path, from: projectRoot),
          entity: entityName,
          hasDataImpl: await File(dataRepoPath).exists(),
        ),
      );
    }
    return results;
  }

  Future<List<ArchDataSource>> _scanDataSources() async {
    final results = <ArchDataSource>[];
    for (final file in await _listDartFiles(
      p.join(projectRoot, 'lib', 'src', 'data', 'datasources'),
    )) {
      final content = await file.readAsString();
      final classMatch = RegExp(
        r'class\s+(\w+(?:DataSource|Datasource)?)',
      ).firstMatch(content);
      if (classMatch == null) continue;
      final name = classMatch.group(1)!;
      final lower = content.toLowerCase();
      results.add(
        ArchDataSource(
          name: name,
          path: p.relative(file.path, from: projectRoot),
          entity: _extractEntityFromName(name),
          isRemote:
              lower.contains('graphql') ||
              lower.contains('http') ||
              lower.contains('rest') ||
              lower.contains('remote'),
          isLocal:
              lower.contains('hive') ||
              lower.contains('sqlite') ||
              lower.contains('local'),
        ),
      );
    }
    return results;
  }

  Future<List<ArchPresentation>> _scanPresentation() async {
    final results = <ArchPresentation>[];
    for (final file in await _listDartFiles(
      p.join(projectRoot, 'lib', 'src', 'presentation'),
    )) {
      final fileName = p.basenameWithoutExtension(file.path);
      String? type;

      // Check PascalCase suffixes
      if (fileName.endsWith('View') || fileName.endsWith('Page')) {
        type = 'view';
      } else if (fileName.endsWith('Presenter')) {
        type = 'presenter';
      } else if (fileName.endsWith('Controller')) {
        type = 'controller';
      } else if (fileName.endsWith('State')) {
        type = 'state';
      }

      // Check snake_case suffixes (generated file naming)
      if (type == null) {
        if (fileName.endsWith('_view') || fileName.endsWith('_page')) {
          type = 'view';
        } else if (fileName.endsWith('_presenter')) {
          type = 'presenter';
        } else if (fileName.endsWith('_controller')) {
          type = 'controller';
        } else if (fileName.endsWith('_state')) {
          type = 'state';
        }
      }

      if (type != null) {
        results.add(
          ArchPresentation(
            name: fileName,
            path: p.relative(file.path, from: projectRoot),
            entity: _extractEntityFromName(fileName),
            type: type,
          ),
        );
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _scanDI() async {
    final results = <Map<String, dynamic>>[];
    final candidates = [
      p.join(projectRoot, 'lib', 'src', 'domain', 'services'),
      p.join(projectRoot, 'lib', 'src', 'core', 'di'),
      p.join(projectRoot, 'lib', 'src', 'presentation', 'shells'),
    ];
    for (final dirPath in candidates) {
      for (final file in await _listDartFiles(dirPath)) {
        final content = await file.readAsString();
        for (final match in RegExp(
          r'(?:getIt|locator|sl)\.(register(?:Lazy|Singleton|Factory))',
        ).allMatches(content)) {
          results.add({
            'type': match.group(1),
            'file': p.relative(file.path, from: projectRoot),
          });
        }
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _scanRoutes() async {
    final results = <Map<String, dynamic>>[];
    final routeFiles = [
      p.join(projectRoot, 'lib', 'src', 'presentation', 'shells'),
      p.join(projectRoot, 'lib', 'src', 'routes'),
      p.join(projectRoot, 'lib', 'src', 'app'),
    ];
    for (final dirPath in routeFiles) {
      for (final file in await _listDartFiles(dirPath)) {
        final content = await file.readAsString();
        // Match GoRoute(path: '/something') patterns
        final pathRegex = RegExp(r"path\s*:\s*'([^']+)'");
        for (final match in pathRegex.allMatches(content)) {
          results.add({
            'path': match.group(1),
            'file': p.relative(file.path, from: projectRoot),
          });
        }
      }
    }
    return results;
  }

  // ------------------------------------------------------------------
  // arch.refactor
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> refactor({
    required String operation,
    required Map<String, dynamic> args,
  }) async {
    switch (operation) {
      case 'rename-entity-field':
        return _renameEntityField(
          entityName: args['entity'] as String,
          oldName: args['oldField'] as String,
          newName: args['newField'] as String,
        );
      case 'add-entity-method':
        return _addEntityMethod(
          entityName: args['entity'] as String,
          methodCode: args['method'] as String,
        );
      default:
        return {
          'success': false,
          'affectedFiles': <String>[],
          'message': 'Unknown refactor operation: $operation',
        };
    }
  }

  Future<Map<String, dynamic>> _renameEntityField({
    required String entityName,
    required String oldName,
    required String newName,
  }) async {
    final affectedFiles = <String>[];
    final snake = _toSnakeCase(entityName);
    final entityFile = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        snake,
        '$snake.dart',
      ),
    );
    if (!await entityFile.exists()) {
      return {
        'success': false,
        'affectedFiles': affectedFiles,
        'message': 'Entity not found: $entityName',
      };
    }
    var content = await entityFile.readAsString();
    // Replace field declaration using word boundaries to avoid partial matches
    content = _replaceIdentifier(content, oldName, newName);
    await entityFile.writeAsString(content);
    affectedFiles.add(p.relative(entityFile.path, from: projectRoot));

    // Scan all related dart files
    final libSrc = p.join(projectRoot, 'lib', 'src');
    final libDir = Directory(libSrc);
    if (!await libDir.exists()) {
      return {
        'success': true,
        'affectedFiles': affectedFiles,
        'message': 'Renamed in entity file only',
      };
    }
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File ||
          !entity.path.endsWith('.dart') ||
          entity.path == entityFile.path) {
        continue;
      }
      var fileContent = await entity.readAsString();
      var modified = false;

      // Replace member access (dot notation) with word boundaries
      final dotAccess = RegExp(r'\.' + RegExp.escape(oldName) + r'\b');
      if (dotAccess.hasMatch(fileContent)) {
        fileContent = fileContent.replaceAll(dotAccess, '.$newName');
        modified = true;
      }

      // Replace named arguments with word boundaries
      final namedParam = RegExp(r'\b' + RegExp.escape(oldName) + r'\s*:');
      if (namedParam.hasMatch(fileContent)) {
        fileContent = fileContent.replaceAll(namedParam, '$newName:');
        modified = true;
      }

      if (modified) {
        await entity.writeAsString(fileContent);
        affectedFiles.add(p.relative(entity.path, from: projectRoot));
      }
    }
    return {
      'success': true,
      'affectedFiles': affectedFiles,
      'message':
          'Renamed field "$oldName" to "$newName" in ${affectedFiles.length} files',
    };
  }

  /// Replace identifier with word boundaries (declarations, references, named args)
  String _replaceIdentifier(String content, String oldName, String newName) {
    // Match field declarations, member access, named arguments
    final patterns = [
      RegExp(r'\b' + RegExp.escape(oldName) + r'\s*;'), // field declaration
      RegExp(r'\bthis\.' + RegExp.escape(oldName) + r'\b'), // this.field
      RegExp(r'\b' + RegExp.escape(oldName) + r'\s*:'), // named argument
    ];

    var result = content;
    result = result.replaceAll(patterns[0], '$newName;');
    result = result.replaceAll(patterns[1], 'this.$newName');
    result = result.replaceAll(patterns[2], '$newName:');
    return result;
  }

  Future<Map<String, dynamic>> _addEntityMethod({
    required String entityName,
    required String methodCode,
  }) async {
    final snake = _toSnakeCase(entityName);
    final entityFile = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        snake,
        '$snake.dart',
      ),
    );
    if (!await entityFile.exists()) {
      return {
        'success': false,
        'affectedFiles': <String>[],
        'message': 'Entity not found: $entityName',
      };
    }
    var content = await entityFile.readAsString();
    final classMatch = RegExp(
      r'class\s+\$?' + RegExp.escape(entityName),
    ).firstMatch(content);
    if (classMatch == null) {
      return {
        'success': false,
        'affectedFiles': <String>[],
        'message': 'Could not find entity class definition',
      };
    }

    // Find the matching closing brace for this specific class
    final classStart = classMatch.end;
    var braceDepth = 0;
    var classClosingBrace = -1;
    var i = classStart;

    while (i < content.length) {
      if (content[i] == '{') {
        braceDepth++;
      } else if (content[i] == '}') {
        braceDepth--;
        if (braceDepth == 0) {
          classClosingBrace = i;
          break;
        }
      }
      i++;
    }

    if (classClosingBrace == -1) {
      return {
        'success': false,
        'affectedFiles': <String>[],
        'message': 'Could not find class closing brace',
      };
    }

    final insertion = methodCode.endsWith('\n') ? methodCode : '$methodCode\n';
    content =
        '${content.substring(0, classClosingBrace)}$insertion}${content.substring(classClosingBrace + 1)}';
    await entityFile.writeAsString(content);
    final relativePath = p.relative(entityFile.path, from: projectRoot);
    return {
      'success': true,
      'affectedFiles': [relativePath],
      'message': 'Added method to $entityName in $relativePath',
    };
  }

  String _extractEntityFromName(String name) {
    for (final suffix in [
      'Repository',
      'DataSource',
      'Datasource',
      'UseCase',
      'Presenter',
      'Controller',
      'View',
      'Page',
      'State',
    ]) {
      if (name.endsWith(suffix)) {
        return name.substring(0, name.length - suffix.length);
      }
    }
    return name;
  }

  String _toSnakeCase(String input) {
    final chars = <String>[];
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char.toUpperCase() == char && char.toLowerCase() != char && i > 0) {
        chars.add('_');
      }
      chars.add(char.toLowerCase());
    }
    return chars.join();
  }

  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
        .join();
  }
}
