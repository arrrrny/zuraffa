import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import '../../../core/constants/known_types.dart';
import '../../../core/context/file_system.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../core/project/receipt_store.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import '../../../version.dart';
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
      final dryRun = args['dryRun'] ?? false;
      final files = await _registerAdapter(args, dryRun: dryRun);

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

      // Spec #975, Order 2: persist a registrar receipt so
      // `zfa proof check` can prove where the registrar came from and
      // `zfa cache verify` can detect drift. Best-effort by design: the
      // artifacts already exist, so a receipt failure degrades to a
      // warning instead of failing the run. Dry runs write nothing and
      // must not ship receipts.
      if (!dryRun) {
        await _emitReceipt(
          entityName: args['name'] as String,
          discoveredEntities: registeredEntities,
          buildStatus: buildStatus,
          wroteManualAdditions: args['_wroteManualAdditions'] == true,
          entitySourcePath: args['_entitySourcePath'] as String?,
          verbose: args['verbose'] == true,
        );
      }

      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {
          'generatedFiles': files,
          'registeredEntities': registeredEntities,
          'buildStatus': buildStatus,
        },
      );
    } catch (e) {
      return ExecutionResult(success: false, message: '$e');
    }
  }

  /// Spec #975, Order 2 — persists the registrar receipt through
  /// [ReceiptStore] (schema `proof.v1`, command `cache-adapter`).
  ///
  /// The payload the adapter already computes — target entity, discovered
  /// entities, the registrar digest, the optional build status — becomes
  /// durable so `zfa proof check` can re-derive the digests and
  /// `zfa cache verify` can gate on drift. Receipt file paths are
  /// project-relative so they stay portable across machines.
  ///
  /// The project root is resolved as the nearest ancestor of the
  /// registrar artifact that carries a `pubspec.yaml`; when the artifact
  /// lives inside a project-less directory under the current working
  /// directory, the CWD is used; otherwise no receipt is written (there
  /// is no project to prove provenance for, and writing into an
  /// unrelated CWD would pollute it).
  Future<void> _emitReceipt({
    required String entityName,
    required List<String> discoveredEntities,
    required String? buildStatus,
    required bool wroteManualAdditions,
    String? entitySourcePath,
    bool verbose = false,
  }) async {
    try {
      final outputDir = plugin.outputDir;
      final registrarAbs = _absoluteOf(
        path.join(outputDir, 'cache', 'hive_registrar.dart'),
      );
      final projectRoot = _resolveProjectRoot(registrarAbs);
      if (projectRoot == null) {
        if (verbose) {
          print('  Receipt skipped: no project root for $registrarAbs');
        }
        return;
      }

      String projectRel(String absPath) => path
          .normalize(path.relative(absPath, from: projectRoot))
          .replaceAll('\\', '/');

      final files = <GenerationReceiptFile>[];
      String? registrarHash;

      final registrarFile = File(registrarAbs);
      if (registrarFile.existsSync()) {
        final bytes = registrarFile.readAsBytesSync();
        registrarHash = crypto.sha256.convert(bytes).toString();
        final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
        files.add(
          GenerationReceiptFile(
            path: projectRel(registrarAbs),
            action: 'update',
            sha256: registrarHash,
            bytes: bytes.length,
            snapshot: keepSnapshot ? registrarFile.readAsStringSync() : null,
          ),
        );
      }

      if (wroteManualAdditions) {
        final manualAbs = _absoluteOf(
          path.join(outputDir, 'cache', 'hive_manual_additions.txt'),
        );
        final manualFile = File(manualAbs);
        if (manualFile.existsSync()) {
          final bytes = manualFile.readAsBytesSync();
          final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
          files.add(
            GenerationReceiptFile(
              path: projectRel(manualAbs),
              action: 'update',
              sha256: crypto.sha256.convert(bytes).toString(),
              bytes: bytes.length,
              snapshot: keepSnapshot ? manualFile.readAsStringSync() : null,
            ),
          );
        }
      }

      if (files.isEmpty) return;

      // Spec binding: the entity source this run discovered FROM, so a
      // later edit surfaces as a stale registration (not just a digest
      // mismatch on the registrar).
      GenerationReceiptSpec? spec;
      if (entitySourcePath != null) {
        final sourceAbs = _absoluteOf(entitySourcePath);
        final sourceFile = File(sourceAbs);
        if (sourceFile.existsSync()) {
          final bytes = sourceFile.readAsBytesSync();
          spec = GenerationReceiptSpec(
            path: projectRel(sourceAbs),
            sha256: crypto.sha256.convert(bytes).toString(),
            snapshot: bytes.length <= ReceiptStore.maxSnapshotBytes
                ? sourceFile.readAsStringSync()
                : null,
          );
        }
      }

      await ReceiptStore(projectRoot: projectRoot).save(
        GenerationReceipt(
          command: 'cache-adapter',
          target: entityName,
          repro: 'zfa cache adapter $entityName',
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'entity': entityName,
            'discoveredEntities': discoveredEntities,
            'registrarHash': registrarHash,
            'buildStatus': buildStatus,
          },
          spec: spec,
          files: files,
        ),
      );
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
    }
  }

  /// Resolves [maybeRelative] against the CWD into a canonical absolute
  /// path.
  String _absoluteOf(String maybeRelative) =>
      path.canonicalize(path.absolute(maybeRelative));

  /// Nearest ancestor of [artifactAbs] containing `pubspec.yaml`; when
  /// none exists and the artifact is under the CWD, the CWD wins; when
  /// the artifact is outside any project, `null` (no receipt).
  String? _resolveProjectRoot(String artifactAbs) {
    var dir = Directory(artifactAbs).parent;
    while (true) {
      if (File(path.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break; // filesystem root
      dir = parent;
    }
    final cwd = Directory.current.path;
    return path.isWithin(path.canonicalize(cwd), artifactAbs)
        ? path.canonicalize(cwd)
        : null;
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
    final fs = plugin.cacheBuilder.fileSystem;

    // Check if entity file exists - support both regular entities and enums
    final entityFilePath = path.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );

    // Also check for enum in enums directory
    final enumIndexPath = path.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      'index.dart',
    );
    final enumFilePath = path.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      '$entitySnake.dart',
    );

    bool entityExists = await fs.exists(entityFilePath);
    bool enumExists = false;
    String enumImportPath = '../domain/entities/$entitySnake/$entitySnake.dart';

    if (!entityExists) {
      // Check enums directory
      if (await fs.exists(enumIndexPath)) {
        final content = await fs.read(enumIndexPath);
        if (content.contains('enum $entityName')) {
          enumExists = true;
          enumImportPath = '../domain/entities/enums/index.dart';
        }
      }
      if (!enumExists && await fs.exists(enumFilePath)) {
        final content = await fs.read(enumFilePath);
        if (content.contains('enum $entityName')) {
          enumExists = true;
          enumImportPath = '../domain/entities/enums/$entitySnake.dart';
        }
      }
    }

    if (!entityExists && !enumExists) {
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
            // Also check enums directory
            if (dirName == 'enums') {
              if (await fs.exists(enumIndexPath)) {
                final content = await fs.read(enumIndexPath);
                final enumMatches = RegExp(r'enum\s+(\w+)').allMatches(content);
                for (final match in enumMatches) {
                  available.add(match.group(1)!);
                }
              }
              final enumItems = await fs.list(item);
              for (final enumItem in enumItems) {
                if (!await fs.isDirectory(enumItem) &&
                    enumItem.endsWith('.dart')) {
                  final content = await fs.read(enumItem);
                  final enumMatches = RegExp(
                    r'enum\s+(\w+)',
                  ).allMatches(content);
                  for (final match in enumMatches) {
                    available.add(match.group(1)!);
                  }
                }
              }
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
    if (enumExists) {
      imports.add(enumImportPath);
    } else {
      imports.add('../domain/entities/$entitySnake/$entitySnake.dart');
    }

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
      // Use the correct import path for enums
      String importPath;
      if (entity == entityName && enumExists) {
        importPath = enumImportPath;
      } else {
        importPath =
            '../domain/entities/$entitySnakeName/$entitySnakeName.dart';
      }

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

    // Spec #975: report with verbs the CLI summary recognizes
    // (`created`/`updated`). The pre-#975 code reported `modified` — a
    // verb `CapabilityCommand` does not summarize, which made every
    // adapter run a SILENT success (no output, exit 0).
    final wroteManualAdditions = newLines.isNotEmpty || !hasExistingFile;
    if (wroteManualAdditions) {
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

      files.add(
        GeneratedFile(
          path: manualAdditionsPath,
          type: 'hive_manual_additions',
          action: hasExistingFile ? 'updated' : 'created',
        ),
      );
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
    // so it will pick up our newly added entities. Capture the prior
    // existence so the reported action is honest (created vs updated).
    final registrarPath = path.join(cacheDir, 'hive_registrar.dart');
    final registrarExistedBefore = await fs.exists(registrarPath);

    await plugin.cacheBuilder.regenerateHiveRegistrar(config);

    // Track the registrar file
    final registrarExists = await fs.exists(registrarPath);
    files.add(
      GeneratedFile(
        path: registrarPath,
        type: 'hive_registrar',
        action: registrarExistedBefore
            ? 'updated'
            : (registrarExists ? 'created' : 'skipped'),
      ),
    );

    // Store discovered entities for execute() to use
    args['_discoveredEntities'] = adapterEntities;
    args['_wroteManualAdditions'] = wroteManualAdditions;
    args['_entitySourcePath'] = entityExists
        ? entityFilePath
        : (enumExists
              ? (await fs.exists(enumFilePath) ? enumFilePath : enumIndexPath)
              : null);

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
