part of 'cache_builder.dart';

extension CacheBuilderRegistrar on CacheBuilder {
  Future<void> _regenerateHiveRegistrar(GeneratorConfig config) async {
    // Issue #2008: seed the barrel-export resolver from the project root
    // so the barrel hide below is verified against the zuraffa this
    // project actually resolves (the #942 mechanism, made empty-safe by
    // #1530). The make flows seed via PluginManager.buildContext; the
    // registrar's own regeneration paths (`zfa build`'s #1732 refresh,
    // `zfa cache adapter`) reach this builder with no plugin context —
    // an unseeded resolver yields an EMPTY hide list and re-emits the
    // unhidden barrel import this fix exists to remove.
    await _seedBarrelResolver(outputDir);

    final dirPath = path.join(outputDir, 'cache');
    final registrarPath = path.join(dirPath, 'hive_registrar.dart');

    if (!await fileSystem.exists(dirPath)) {
      return;
    }

    final items = await fileSystem.list(dirPath);
    final files = <String>[];
    for (final item in items) {
      if (!await fileSystem.isDirectory(item)) {
        if (item.endsWith('_cache.dart') &&
            !item.endsWith('index.dart') &&
            !item.endsWith('timestamp_cache.dart')) {
          files.add(item);
        }
      }
    }

    if (files.isEmpty) {
      // Check if there are manual additions to preserve
      final manualAdditionsPath = path.join(
        outputDir,
        'cache',
        'hive_manual_additions.txt',
      );
      bool hasManualAdditions = false;
      if (await fileSystem.exists(manualAdditionsPath)) {
        final content = await fileSystem.read(manualAdditionsPath);
        for (final line in content.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            final parts = trimmed.split('|');
            if (parts.length == 2) {
              hasManualAdditions = true;
              break;
            }
          }
        }
      }

      if (!hasManualAdditions) {
        // An existing registrar that still carries AdapterSpec entries is
        // hand-maintained state, not an empty artifact — let the merge path
        // below decide what survives instead of deleting it outright
        // (issue #1734 follow-up: this branch used to truncate a
        // hand-maintained registrar before the merge ever ran).
        final registrarHasAdapters =
            await fileSystem.exists(registrarPath) &&
            RegExp(
              r'AdapterSpec<(\w+)>\(\)',
            ).hasMatch(await fileSystem.read(registrarPath));
        if (!registrarHasAdapters) {
          if (await fileSystem.exists(registrarPath)) {
            if (options.dryRun) {
              if (options.verbose) print('  Dry run: Deleting $registrarPath');
            } else {
              await fileSystem.delete(registrarPath);
            }
          }
          return;
        }
      }
    }

    final imports = <String>[];
    final adapterEntities = <String>[];
    final processedEntities = <String>{};

    final manualAdditionsPath = path.join(
      outputDir,
      'cache',
      'hive_manual_additions.txt',
    );

    if (await fileSystem.exists(manualAdditionsPath)) {
      final content = await fileSystem.read(manualAdditionsPath);
      final lines = content.split('\n');
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

    // ── Merge with existing registrar (issue #1734) ──
    // Read the existing registrar and extract AdapterSpec entries and
    // imports so hand-maintained adapters are not silently truncated.
    if (await fileSystem.exists(registrarPath)) {
      final existingContent = await fileSystem.read(registrarPath);

      final specRegex = RegExp(r'AdapterSpec<(\w+)>\(\)');
      final retainedEnumNames = <String>{};
      for (final match in specRegex.allMatches(existingContent)) {
        final name = match.group(1)!;
        if (processedEntities.contains(name)) continue;
        // Keep only specs whose entity or enum still resolves. Re-emitting a
        // spec for a deleted/renamed entity recreates the exact
        // `spec.type.element == null` crash this PR fixes — the pre-fix
        // registrar is precisely a carrier of such specs (issue #1734).
        final resolved = await resolveCacheEntityLocation(
          name,
          outputDir: outputDir,
          fileSystem: fileSystem,
        );
        if (resolved == null) {
          if (config.verbose) {
            print('  Dropping AdapterSpec<$name>: no matching entity');
          }
          continue;
        }
        processedEntities.add(name);
        adapterEntities.add(name);
        if (resolved.isEnum) retainedEnumNames.add(name);
        if (!imports.contains(resolved.importPath)) {
          imports.add(resolved.importPath);
        }
      }

      final importRegex = RegExp(r"import\s+'([^']+)'");
      for (final match in importRegex.allMatches(existingContent)) {
        final importPath = match.group(1)!;
        // Retain an import only when a retained spec needs it: either it is
        // the import the spec's type is named after (hand-maintained
        // adapters may live outside ../domain/entities/, e.g. package:
        // imports — dropping those produced an uncompilable registrar), or
        // it is the enums barrel carrying a retained enum spec. Imports of
        // dropped specs must not survive, or the registrar references types
        // that no longer exist.
        final neededByRetainedSpec = adapterEntities.any(
          (name) =>
              importPath.endsWith('/${StringUtils.camelToSnake(name)}.dart'),
        );
        final neededByRetainedEnum =
            retainedEnumNames.isNotEmpty &&
            importPath.endsWith('/enums/index.dart');
        if ((neededByRetainedSpec || neededByRetainedEnum) &&
            !imports.contains(importPath)) {
          imports.add(importPath);
        }
      }
    }

    for (final filePath in files) {
      final fileName = path.basename(filePath);
      final entitySnake = fileName.replaceAll('_cache.dart', '');
      final entityName = StringUtils.convertToPascalCase(entitySnake);

      // Check if entity exists (regular or enum) — issue #1734
      final resolved = await resolveCacheEntityLocation(
        entityName,
        outputDir: outputDir,
        fileSystem: fileSystem,
      );

      if (resolved == null) {
        if (config.verbose) {
          print('  Skipping $fileName: no matching entity for $entityName');
        }
        continue;
      }

      if (!imports.contains(resolved.importPath)) {
        imports.add(resolved.importPath);
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

    // Issue #2008: the registrar references every adapter entity by bare
    // name, so an entity whose name matches a zuraffa core export (e.g. an
    // app `DeviceInfo` — the barrel exports its own `DeviceInfo`) makes
    // the generated registrar fail the analyze gate with
    // `ambiguous_import`. Hide the adapter entities' own symbols from the
    // barrel, exactly as every other generated file does (#942); the
    // filter drops names the barrel does not export, so an empty list
    // emits no combinator at all.
    final barrelHide =
        adapterEntities
            .expand((entity) => EntityUtils.barrelHideNames(entity))
            .toSet()
            .toList()
          ..sort();

    final directives = [
      Directive.import('package:zuraffa/zuraffa.dart', hide: barrelHide),
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
      fileSystem: fileSystem,
    );

    if (!await fileSystem.exists(manualAdditionsPath) && !config.revert) {
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
        manualAdditionsPath,
        template,
        'hive_manual_additions',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }
  }

  /// Walks up from [outputDir] to the nearest `pubspec.yaml` and seeds
  /// [ZuraffaBarrelExports] with it — the same root walk
  /// `_resolveProjectRoot` uses in the cache-adapter capability. A no-op
  /// when no pubspec bounds the walk (the resolver then stays unseeded
  /// and the emission carries no combinator, the #1530 empty-safe path).
  Future<void> _seedBarrelResolver(String outputDir) async {
    var dir = path.normalize(path.absolute(outputDir));
    while (true) {
      if (await fileSystem.exists(path.join(dir, 'pubspec.yaml'))) {
        ZuraffaBarrelExports.seed(dir);
        return;
      }
      final parent = path.dirname(dir);
      if (parent == dir) return;
      dir = parent;
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

    if (!await fileSystem.exists(entityPath)) return;

    final fields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );

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

      if (await fileSystem.exists(subEntityPath)) {
        processedEntities.add(baseType);
        adapterEntities.add(baseType);
        final importPath =
            '../domain/entities/$subEntitySnake/$subEntitySnake.dart';
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
