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

    // Use DiscoveryEngine to find the entity file
    final entityFile = discovery.findFileSync('$entitySnake.dart');
    final repoInterfaceFile = discovery.findFileSync(
      '${entitySnake}_repository.dart',
    );

    final repoImplDir = p.dirname(
      p.join(
        outputDir,
        'data',
        'repositories',
        'data_${entitySnake}_repository.dart',
      ),
    );

    final isEnum = EntityAnalyzer.isEnum(
      config.name,
      outputDir,
      fileSystem: fileSystem,
    );
    if (isEnum) {
      final baseImport = PackageUtils.getBaseImport(
        outputDir,
        fileSystem: fileSystem,
      );
      imports.add('$baseImport/domain/entities/enums/index.dart');
    } else if (entityFile != null) {
      imports.add(p.relative(entityFile.path, from: repoImplDir));
    } else {
      // Fallback
      final baseImport = PackageUtils.getBaseImport(
        outputDir,
        fileSystem: fileSystem,
      );
      imports.add('$baseImport/domain/entities/$entitySnake/$entitySnake.dart');
    }

    if (repoInterfaceFile != null) {
      imports.add(p.relative(repoInterfaceFile.path, from: repoImplDir));
    } else {
      final baseImport = PackageUtils.getBaseImport(
        outputDir,
        fileSystem: fileSystem,
      );
      imports.add(
        '$baseImport/domain/repositories/${entitySnake}_repository.dart',
      );
    }

    if (config.generateLocal) {
      imports.add(
        '../datasources/$entitySnake/${entitySnake}_local_datasource.dart',
      );
    } else if (config.enableCache) {
      imports.add('../datasources/$entitySnake/${entitySnake}_datasource.dart');
      imports.add(
        '../datasources/$entitySnake/${entitySnake}_local_datasource.dart',
      );
      imports.add('../../cache/${entitySnake}_cache.dart');
    } else {
      imports.add('../datasources/$entitySnake/${entitySnake}_datasource.dart');
    }
    return imports;
  }
}
