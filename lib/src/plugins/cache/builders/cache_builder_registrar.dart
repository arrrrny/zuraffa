part of 'cache_builder.dart';

extension CacheBuilderRegistrar on CacheBuilder {
  Future<void> _regenerateHiveRegistrar(GeneratorConfig config) async {
    final dirPath = path.join(outputDir, 'cache');
    final registrarPath = path.join(dirPath, 'hive_registrar.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('_cache.dart') &&
              !f.path.endsWith('index.dart') &&
              !f.path.endsWith('timestamp_cache.dart'),
        )
        .toList();

    if (files.isEmpty) {
      if (File(registrarPath).existsSync()) {
        if (options.dryRun) {
          if (options.verbose) print('  Dry run: Deleting $registrarPath');
        } else {
          File(registrarPath).deleteSync();
        }
      }
      return;
    }

    final imports = <String>[];
    final adapterEntities = <String>[];
    final processedEntities = <String>{};

    final manualAdditionsPath = path.join(
      outputDir,
      'cache',
      'hive_manual_additions.txt',
    );
    final manualAdditionsFile = File(manualAdditionsPath);

    if (manualAdditionsFile.existsSync()) {
      final lines = manualAdditionsFile.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final parts = trimmed.split('|');
        if (parts.length == 2) {
          final importPath = parts[0].trim();
          final entityName = parts[1].trim();

          if (!imports.contains(importPath)) {
            imports.add(importPath);
          }
          if (!processedEntities.contains(entityName)) {
            processedEntities.add(entityName);
            adapterEntities.add(entityName);
          }
        }
      }
    }

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entitySnake = fileName.replaceAll('_cache.dart', '');
      final entityName = StringUtils.convertToPascalCase(entitySnake);
      final importPath = '../domain/entities/$entitySnake/$entitySnake.dart';

      if (!imports.contains(importPath)) {
        imports.add(importPath);
      }
      if (!processedEntities.contains(entityName)) {
        processedEntities.add(entityName);
        adapterEntities.add(entityName);
      }

      await _collectNestedEntitiesForHive(
        entityName,
        imports,
        adapterEntities,
        processedEntities,
      );
    }

    final adapterSpecs = adapterEntities
        .map(
          (entity) => refer('AdapterSpec').call([], const {}, [refer(entity)]),
        )
        .toList();

    final registrationStatements = adapterEntities
        .map(
          (entity) => refer(
            'registerAdapter',
          ).call([refer('${entity}Adapter').call([])]).statement,
        )
        .toList();

    final directives = [
      Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      ...imports.map(Directive.import),
      Directive.part('hive_registrar.g.dart'),
    ];

    final generateAdapters = refer(
      'GenerateAdapters',
    ).call([literalList(adapterSpecs)]);

    final registerMethod = Method(
      (m) => m
        ..name = 'registerAdapters'
        ..returns = refer('void')
        ..body = Block((b) => b..statements.addAll(registrationStatements)),
    );

    final hiveRegistrarExtension = Extension(
      (e) => e
        ..name = 'HiveRegistrar'
        ..on = refer('HiveInterface')
        ..annotations.add(generateAdapters)
        ..methods.add(registerMethod),
    );

    final isolatedRegistrarExtension = Extension(
      (e) => e
        ..name = 'IsolatedHiveRegistrar'
        ..on = refer('IsolatedHiveInterface')
        ..methods.add(registerMethod),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [hiveRegistrarExtension, isolatedRegistrarExtension],
        directives: directives,
      ),
    );

    await FileUtils.writeFile(
      registrarPath,
      content,
      'hive_registrar',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );

    if (!manualAdditionsFile.existsSync() && !config.revert) {
      final template = '''# Hive Manual Additions
# Add nested entities and enums that need Hive adapters
# Format: import_path|EntityName
# Example: ../domain/entities/enums/index.dart|ParserType

# Uncomment and add your entities below:
# ../domain/entities/enums/index.dart|ParserType
# ../domain/entities/enums/index.dart|HttpClientType
# ../domain/entities/range/range.dart|Range
''';
      await FileUtils.writeFile(
        manualAdditionsFile.path,
        template,
        'hive_manual_additions',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
      );
    }
  }

  Future<void> _collectNestedEntitiesForHive(
    String entityName,
    List<String> imports,
    List<String> adapterEntities,
    Set<String> processedEntities,
  ) async {
    await _collectSubtypeAdapters(
      entityName,
      imports,
      adapterEntities,
      processedEntities,
    );
  }

  Future<void> _collectSubtypeAdapters(
    String entityName,
    List<String> imports,
    List<String> adapterEntities,
    Set<String> processedEntities,
  ) async {
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityPath = path.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );

    final file = File(entityPath);
    if (!file.existsSync()) return;

    final fields = EntityAnalyzer.analyzeEntity(entityName, outputDir);

    for (final fieldType in fields.values) {
      final baseType = _extractBaseType(fieldType);
      if (baseType == null || processedEntities.contains(baseType)) continue;

      if (KnownTypes.isExcluded(baseType)) continue;

      final subEntitySnake = StringUtils.camelToSnake(baseType);
      final subEntityPath = path.join(
        outputDir,
        'domain',
        'entities',
        subEntitySnake,
        '$subEntitySnake.dart',
      );

      if (File(subEntityPath).existsSync()) {
        processedEntities.add(baseType);
        adapterEntities.add(baseType);
        final importPath = '../domain/entities/$subEntitySnake/$subEntitySnake.dart';
        if (!imports.contains(importPath)) {
          imports.add(importPath);
        }
        await _collectSubtypeAdapters(
          baseType,
          imports,
          adapterEntities,
          processedEntities,
        );
      }
    }
  }

  String? _extractBaseType(String type) {
    final cleanType = type.replaceAll('?', '');
    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(cleanType);
    if (genericMatch != null) {
      return genericMatch.group(2)?.replaceAll('?', '');
    }
    return cleanType;
  }
}
