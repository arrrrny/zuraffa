import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../core/constants/known_types.dart';
import '../../../core/context/file_system.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../cache_plugin.dart';

/// Capability that registers Hive type adapters for an entity and all its
/// sub-entities by updating the `hive_registrar.dart` file.
///
/// Usage: `zfa cache adapter <EntityName> [--build]`
///
/// This capability discovers the specified entity's field types recursively,
/// adds the entity and its sub-entities to the Hive manual additions file,
/// regenerates the registrar, and optionally runs `zfa build`.
class CreateCacheAdapterCapability implements ZuraffaCapability {
  final CachePlugin plugin;

  CreateCacheAdapterCapability(this.plugin);

  @override
  String get name => 'adapter';

  @override
  String get description =>
      'Register Hive adapters for an entity and its sub-entities';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity or enum (e.g. Product, ParserType)',
      },
      'build': {
        'type': 'boolean',
        'description': 'Run zfa build after updating registrar',
        'default': false,
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Preview changes without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable detailed logging',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'generatedFiles': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'registeredEntities': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'buildStatus': {'type': 'string'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _registerAdapter(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    try {
      final files = await _registerAdapter(
        args,
        dryRun: args['dryRun'] ?? false,
      );

      final registeredEntities =
          args['_discoveredEntities'] as List<String>? ?? [];

      // Optionally run zfa build
      String? buildStatus;
      if (args['build'] == true) {
        if (args['verbose'] == true) {
          print('  Running zfa build...');
        }
        try {
          final process = await Process.start('dart', [
            'run',
            'build_runner',
            'build',
            '--delete-conflicting-outputs',
          ], mode: ProcessStartMode.inheritStdio);
          final exitCode = await process.exitCode;
          buildStatus = exitCode == 0 ? 'success' : 'failed (exit $exitCode)';
        } catch (e) {
          buildStatus = 'failed: $e';
        }
      }

      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {
          'generatedFiles': files,
          'registeredEntities': registeredEntities,
          'buildStatus': ?buildStatus,
        },
      );
    } catch (e) {
      return ExecutionResult(success: false, message: '$e');
    }
  }

  /// Core logic: discover entities, update manual additions, regenerate registrar.
  Future<List<GeneratedFile>> _registerAdapter(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final entityName = args['name'] as String;
    final outputDir = plugin.outputDir;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityFilePath = path.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );

    final fs = plugin.cacheBuilder.fileSystem;

    // Check if entity file exists
    if (!await fs.exists(entityFilePath)) {
      // List available entities for helpful error message
      final entitiesDir = path.join(outputDir, 'domain', 'entities');
      final available = <String>[];
      if (await fs.exists(entitiesDir)) {
        final items = await fs.list(entitiesDir);
        for (final item in items) {
          if (await fs.isDirectory(item)) {
            final dirName = path.basename(item);
            final entityFile = path.join(item, '$dirName.dart');
            if (await fs.exists(entityFile)) {
              available.add(StringUtils.convertToPascalCase(dirName));
            }
          }
        }
      }

      final suggestions = available.isNotEmpty
          ? '\nAvailable entities:\n${available.map((e) => '  - $e').join('\n')}'
          : '';
      throw Exception("Entity '$entityName' not found.$suggestions");
    }

    // Discover the entity and all its sub-entities
    final imports = <String>[];
    final adapterEntities = <String>[];
    final processedEntities = <String>{entityName};

    // Add the main entity
    adapterEntities.add(entityName);
    imports.add('../domain/entities/$entitySnake/$entitySnake.dart');

    // Discover sub-entities using the same pattern as CacheBuilderRegistrar
    await _collectSubtypeAdapters(
      entityName,
      outputDir,
      fs,
      imports,
      adapterEntities,
      processedEntities,
    );

    // ── ALSO scan existing *_cache.dart files to preserve their adapters ──
    // Without this, entities that have cache files but aren't in the current
    // entity's sub-entity tree would be lost when the registrar is regenerated.
    final cacheDirForScan = path.join(outputDir, 'cache');
    if (await fs.exists(cacheDirForScan)) {
      final cacheItems = await fs.list(cacheDirForScan);
      for (final cacheItem in cacheItems) {
        if (await fs.isDirectory(cacheItem)) continue;
        final cacheFileName = path.basename(cacheItem);
        if (cacheFileName.endsWith('_cache.dart') &&
            !cacheFileName.endsWith('index.dart') &&
            !cacheFileName.endsWith('timestamp_cache.dart')) {
          final entitySnakeFromCache = cacheFileName.replaceAll(
            '_cache.dart',
            '',
          );
          final cachedEntityName = StringUtils.convertToPascalCase(
            entitySnakeFromCache,
          );
          if (!processedEntities.contains(cachedEntityName)) {
            processedEntities.add(cachedEntityName);
            adapterEntities.add(cachedEntityName);
            final cacheImportPath =
                '../domain/entities/$entitySnakeFromCache/$entitySnakeFromCache.dart';
            if (!imports.contains(cacheImportPath)) {
              imports.add(cacheImportPath);
            }
            // Also discover sub-entities of this cached entity
            await _collectSubtypeAdapters(
              cachedEntityName,
              outputDir,
              fs,
              imports,
              adapterEntities,
              processedEntities,
            );
          }
        }
      }
    }

    if (verbose) {
      print('Discovered entities for adapter registration:');
      for (final entity in adapterEntities) {
        print('  - $entity');
      }
    }

    // Add discovered entities to hive_manual_additions.txt
    final cacheDir = path.join(outputDir, 'cache');
    final manualAdditionsPath = path.join(
      cacheDir,
      'hive_manual_additions.txt',
    );

    // Ensure cache directory exists
    if (!await fs.exists(cacheDir)) {
      if (dryRun) {
        if (verbose) print('  Dry run: Would create directory $cacheDir');
      } else {
        // We can't create directories through the abstract FileSystem,
        // but we can create the file via FileUtils which handles it.
        if (verbose) print('  Creating cache directory: $cacheDir');
      }
    }

    // Read existing additions and merge
    final existingLines = <String>[];
    bool hasExistingFile = false;
    if (await fs.exists(manualAdditionsPath)) {
      hasExistingFile = true;
      final content = await fs.read(manualAdditionsPath);
      existingLines.addAll(content.split('\n'));
    }

    // Build merged additions content
    final mergedLines = <String>[];
    final existingEntityEntries = <String>{};

    // Parse existing comments and entries
    for (final line in existingLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        mergedLines.add(line); // Preserve comments and blank lines
      } else {
        final parts = trimmed.split('|');
        if (parts.length == 2) {
          final existingName = parts[1].trim();
          existingEntityEntries.add(existingName);
          mergedLines.add(line); // Keep existing entries
        }
      }
    }

    // Add new entity entries that don't exist yet
    final newLines = <String>[];
    for (var i = 0; i < adapterEntities.length; i++) {
      final entity = adapterEntities[i];
      final entitySnakeName = StringUtils.camelToSnake(entity);
      final importPath =
          '../domain/entities/$entitySnakeName/$entitySnakeName.dart';

      if (!existingEntityEntries.contains(entity)) {
        newLines.add('$importPath|$entity');
        existingEntityEntries.add(entity);
      }
    }

    // If there's no existing file, add the header
    final files = <GeneratedFile>[];
    if (!hasExistingFile && newLines.isNotEmpty) {
      mergedLines.insertAll(0, [
        '# Hive Manual Additions',
        '# Add nested entities and enums that need Hive adapters',
        '# Format: import_path|EntityName',
        '# Example: ../domain/entities/enums/index.dart|ParserType',
        '',
      ]);
    }

    mergedLines.addAll(newLines.map((l) => l));

    if (newLines.isNotEmpty || !hasExistingFile) {
      // Write updated manual additions
      await FileUtils.writeFile(
        manualAdditionsPath,
        mergedLines.join('\n'),
        'hive_manual_additions',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        fileSystem: fs,
      );

      if (dryRun) {
        files.add(
          GeneratedFile(
            path: manualAdditionsPath,
            type: 'hive_manual_additions',
            action: 'created',
          ),
        );
      }
    }

    // Regenerate the hive registrar
    final config = GeneratorConfig(
      name: entityName,
      outputDir: outputDir,
      enableCache: true,
      cacheStorage: 'hive',
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // The registrar regeneration reads cache files and manual additions,
    // so it will pick up our newly added entities.
    await plugin.cacheBuilder.regenerateHiveRegistrar(config);

    // Track the registrar file
    final registrarPath = path.join(cacheDir, 'hive_registrar.dart');
    final registrarExists = await fs.exists(registrarPath);
    files.add(
      GeneratedFile(
        path: registrarPath,
        type: 'hive_registrar',
        action: registrarExists ? 'modified' : 'created',
      ),
    );

    // Store discovered entities for execute() to use
    args['_discoveredEntities'] = adapterEntities;

    if (verbose) {
      print('Adapter registration complete.');
      print('  Entities: ${adapterEntities.join(', ')}');
      print('  Files: ${files.map((f) => f.path).join(', ')}');
    }

    return files;
  }

  /// Recursively discovers sub-entities by analyzing field types.
  Future<void> _collectSubtypeAdapters(
    String entityName,
    String outputDir,
    FileSystem fs,
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

    if (!await fs.exists(entityPath)) return;

    final fields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fs,
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

      if (await fs.exists(subEntityPath)) {
        processedEntities.add(baseType);
        adapterEntities.add(baseType);
        final importPath =
            '../domain/entities/$subEntitySnake/$subEntitySnake.dart';
        if (!imports.contains(importPath)) {
          imports.add(importPath);
        }
        await _collectSubtypeAdapters(
          baseType,
          outputDir,
          fs,
          imports,
          adapterEntities,
          processedEntities,
        );
      }
    }
  }

  /// Extracts the base type from a field type string (handles generics).
  String? _extractBaseType(String type) {
    final cleanType = type.replaceAll('?', '');
    final genericMatch = RegExp(r'(\w+)<(.+)>').firstMatch(cleanType);
    if (genericMatch != null) {
      return genericMatch.group(2)?.replaceAll('?', '');
    }
    return cleanType;
  }
}
