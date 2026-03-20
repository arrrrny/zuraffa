part of 'implementation_generator.dart';

extension RepositoryImplementationGeneratorAppend
    on RepositoryImplementationGenerator {
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

    final baseImport = PackageUtils.getBaseImport(outputDir);

    if (EntityAnalyzer.isEnum(config.name, outputDir)) {
      imports.add('$baseImport/domain/entities/enums/index.dart');
    } else {
      imports.add('$baseImport/domain/entities/$entitySnake/$entitySnake.dart');
    }
    imports.add(
      '$baseImport/domain/repositories/${entitySnake}_repository.dart',
    );

    if (config.generateLocal) {
      imports.add(
        '$baseImport/data/datasources/$entitySnake/${entitySnake}_local_datasource.dart',
      );
    } else if (config.enableCache) {
      imports.add(
        '$baseImport/data/datasources/$entitySnake/${entitySnake}_datasource.dart',
      );
      imports.add(
        '$baseImport/data/datasources/$entitySnake/${entitySnake}_local_datasource.dart',
      );
      imports.add('$baseImport/cache/${entitySnake}_cache.dart');
    } else {
      imports.add(
        '$baseImport/data/datasources/$entitySnake/${entitySnake}_datasource.dart',
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
    required List<Method> methods,
    List<String> imports = const [],
  }) {
    final importLines = _buildImportLines(imports);
    final mergedImports = _mergeImports(source, importLines);

    var updated = mergedImports;
    for (final method in methods) {
      final methodSource = method.accept(DartEmitter()).toString();
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

  String _appendFields({
    required String source,
    required String className,
    required List<Field> fields,
  }) {
    var updated = source;
    for (final field in fields) {
      final fieldSource = field.accept(DartEmitter()).toString();
      final result = appendExecutor.execute(
        AppendRequest.field(
          source: updated,
          className: className,
          memberSource: fieldSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _removeMethods({
    required String source,
    required String className,
    required List<Method> methods,
  }) {
    var updated = source;
    for (final method in methods) {
      final methodSource = method.accept(DartEmitter()).toString();
      final result = appendExecutor.undo(
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

  String _removeFields({
    required String source,
    required String className,
    required List<Field> fields,
  }) {
    var updated = source;
    for (final field in fields) {
      final fieldSource = field.accept(DartEmitter()).toString();
      final result = appendExecutor.undo(
        AppendRequest.field(
          source: updated,
          className: className,
          memberSource: fieldSource,
        ),
      );
      updated = result.source;
    }
    return updated;
  }

  String _removeConstructors({
    required String source,
    required String className,
    required List<Constructor> constructors,
  }) {
    var updated = source;
    final helper = const AstHelper();
    for (final _ in constructors) {
      updated = helper.removeConstructorFromClass(
        source: updated,
        className: className,
      );
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
}
