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
    required List<Method> methods,
  }) {
    var updated = source;
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    for (final method in methods) {
      final methodSource = method.accept(emitter).toString();
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
}
