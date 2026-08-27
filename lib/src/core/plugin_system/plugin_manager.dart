import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import '../../config/zfa_config.dart';
import '../../utils/string_utils.dart';
import '../../cli/plugin_loader.dart';
import '../context/file_system.dart';
import '../context/progress_reporter.dart';
import '../transaction/transactional_file_system.dart';
import '../project/project_root.dart';
import '../project/run_store.dart';
import '../project/project_context_store.dart';
import 'plugin_interface.dart';
import 'plugin_registry.dart';
import 'plugin_context.dart';
import 'discovery_engine.dart';
import 'plan_store.dart';
import 'capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../transaction/generation_transaction.dart';
import '../planning/generation_plan.dart';
import '../planning/plan_resolver.dart';

/// Orchestrates the selection, validation, and execution of plugins.
class PluginManager {
  final PluginRegistry registry;
  final ZfaConfig? config;
  final PluginConfig? pluginConfig;
  final String projectRoot;

  PluginManager({
    required this.registry,
    this.config,
    this.pluginConfig,
    String? projectRoot,
  }) : projectRoot = projectRoot ?? ProjectRoot.find();

  GenerationPlan resolvePlan({
    required String name,
    List<String> explicitPluginIds = const [],
    ArgResults? argResults,
    Map<String, dynamic> options = const {},
  }) {
    return PlanResolver(
      registry: registry,
      config: config,
      pluginConfig: pluginConfig,
    ).resolve(
      name: name,
      explicitPluginIds: explicitPluginIds,
      argResults: argResults,
      options: options,
    );
  }

  /// Resolves the set of active plugins based on explicit requests,
  /// config defaults, and explicit muting (--no-flags).
  List<ZuraffaPlugin> resolveActivePlugins({
    required List<String> explicitPluginIds,
    required ArgResults? argResults,
  }) {
    return resolvePlan(
      name: argResults != null && argResults.rest.isNotEmpty
          ? argResults.rest.first
          : 'Generation',
      explicitPluginIds: explicitPluginIds,
      argResults: argResults,
    ).activePlugins;
  }

  /// Builds a [PluginContext] for a set of plugins and arguments.
  PluginContext buildContext({
    required String name,
    required ArgResults? argResults,
    required List<ZuraffaPlugin> activePlugins,
    String? overrideOutputDir,
    bool? overrideDryRun,
    bool? overrideForce,
    bool? overrideVerbose,
    bool? overrideRevert,
  }) {
    final core = CoreConfig(
      name: name,
      projectRoot: projectRoot,
      outputDir: overrideOutputDir ?? argResults?['output'] ?? 'lib/src',
      dryRun: overrideDryRun ?? argResults?['dry-run'] == true,
      force: overrideForce ?? argResults?['force'] == true,
      verbose: overrideVerbose ?? argResults?['verbose'] == true,
      revert: overrideRevert ?? argResults?['revert'] == true,
    );

    final data = <String, dynamic>{};

    // #346: Sync plugin activation flags into data FIRST, before merging
    // schema defaults below. Some schema properties share their name with a
    // plugin id (e.g. RepositoryPlugin's `datasource` option, DataSourcePlugin's
    // `cache` option) and default to false — when the schema-default merge ran
    // first it wrote `data['datasource'] = false` and the activation sync's
    // `!data.containsKey(id)` guard then skipped marking the datasource plugin
    // active. Downstream plugins (DI) read `data['datasource']` to decide
    // whether to emit datasource registrations, so the app compiled but
    // crashed at runtime with `GetIt: DataSource is not registered`.
    //
    // #412: The activation sync also poisons slots whose own plugin schema
    // declares the id as a NON-boolean type. `ServicePlugin.id == 'service'`
    // and its own `configSchema.properties.service = {type:'string'}` — so
    // writing `data['service'] = true` (bool) made every consumer that read
    // `data['service'] as String?` (or `context.get<String>('service')`)
    // crash with `type 'bool' is not a subtype of type 'String?' in type
    // cast` whenever the user ran `zfa make <Entity> ... service ...`
    // without an explicit `--service <Name>`. The same `service: {type:
    // 'string'}` property is also declared by `UseCasePlugin`, so the
    // collision spans multiple consumers.
    //
    // Fix: for active plugin ids whose OWN schema declares the id as a
    // non-boolean type, record the activation under the dedicated
    // `__active_<id>` key (queried via `PluginContext.isActive`) and leave
    // `data[id]` for the typed value (String/int/...) — which the
    // argResults / schema-default merge below fills in, or stays absent
    // (null) when the user didn't pass an explicit value. For ids whose
    // own schema is boolean-typed or absent, keep writing `data[id] =
    // true` directly (preserves the #346 behavior for `datasource`,
    // `cache`, `state`, etc. and all their downstream `== true` checks).
    for (final plugin in activePlugins) {
      final id = plugin.id;
      if (data.containsKey(id)) continue;
      if (_ownSchemaDeclaresNonBoolean(plugin)) {
        data['__active_$id'] = true;
      } else {
        data[id] = true;
      }
    }

    // Merge plugin-specific data from ArgResults
    if (argResults != null) {
      for (final plugin in activePlugins) {
        final schema = plugin.configSchema;
        if (schema.containsKey('properties')) {
          final properties = Map<String, dynamic>.from(
            schema['properties'] as Map,
          );
          for (final key in properties.keys) {
            final propertyConfig = Map<String, dynamic>.from(
              properties[key] as Map,
            );
            if (argResults.wasParsed(key)) {
              final val = argResults[key];
              if (val is List) {
                // Flatten and split by comma to be robust
                data[key] = val
                    .expand((e) => e.toString().split(','))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              } else if (val is String && (propertyConfig['type'] == 'array')) {
                // Handle comma-separated string for array types
                data[key] = val
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              } else if (val is String && propertyConfig['type'] == 'integer') {
                final parsed = int.tryParse(val);
                if (parsed == null) {
                  throw FormatException(
                    'Invalid value for integer flag "$key": "$val"',
                  );
                }
                data[key] = parsed;
              } else if (val is String && propertyConfig['type'] == 'number') {
                final parsed = double.tryParse(val);
                if (parsed == null) {
                  throw FormatException(
                    'Invalid value for number flag "$key": "$val"',
                  );
                }
                data[key] = parsed;
              } else {
                data[key] = val;
              }
            } else if (propertyConfig.containsKey('default') &&
                // #346: never let a schema default overwrite a plugin
                // activation flag (e.g. `datasource`, `cache` are both
                // plugin ids and schema properties of other plugins).
                !data.containsKey(key)) {
              final def = propertyConfig['default'];
              if (def is String && propertyConfig['type'] == 'array') {
                data[key] = def
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              } else {
                data[key] = def;
              }
            }
          }
        }
      }
    }

    // Add core parameters from ArgResults if present
    final coreParams = [
      'methods',
      'domain',
      'repo',
      'service',
      'usecases',
      'variants',
      'id-field',
      'id-field-type',
      'query-field',
      'query-field-type',
      'no-entity',
      'vpc',
      'vpcs',
      'state',
      'di',
      'data',
      'datasource',
      'cache',
      'sqlite',
      'route',
      'mock',
      'test',
      'append',
    ];

    if (argResults != null) {
      for (final key in coreParams) {
        if (argResults.wasParsed(key)) {
          final val = argResults[key];
          if (val is List) {
            // Flatten and split by comma to be robust, and filter out empty strings
            data[key] = val
                .expand((e) => e.toString().split(','))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (val is String && val.contains(',')) {
            data[key] = val
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          } else if (val is String &&
              val.isEmpty &&
              (key == 'methods' ||
                  key == 'usecases' ||
                  key == 'variants' ||
                  key == 'fields')) {
            // Explicit empty string for list-types should be an empty list
            data[key] = <String>[];
          } else {
            data[key] = val;
          }
        }
      }
    }

    // Add positional arguments and other common fields to data for backward compat
    data['name'] = name;
    data['output_dir'] = core.outputDir;

    final baseFileSystem = FileSystem.create(root: projectRoot);
    final transactionalFileSystem = TransactionalFileSystem(baseFileSystem);

    return PluginContext(
      core: core,
      data: data,
      discovery: DiscoveryEngine(
        projectRoot: projectRoot,
        fileSystem: transactionalFileSystem,
      ),
      fileSystem: transactionalFileSystem,
    );
  }

  Future<List<GeneratedFile>> _handleRevert(PluginContext context) async {
    final files = <GeneratedFile>[];

    // 1. Deep revert (issue #323): delete the canonical entity-snake-keyed
    //    architecture files for this entity, regardless of what the current
    //    or last run produced. This handles the re-modeled-as-value_object
    //    case where the saved plan was overwritten by an empty run and the
    //    historical CRUD orphans remain on disk. It also makes
    //    `zfa make <Entity> --revert` mean "remove the entity's generated
    //    architecture" uniformly — whether the entity is currently an
    //    entity, a value object, or anything else.
    files.addAll(await _deepRevertEntityArchitecture(context));

    // 2. Plan-based revert: restore shared files (route registrations, DI
    //    aggregators) to their previous content. This complements the deep
    //    revert, which only deletes entity-keyed files. For `create`
    //    actions on entity-keyed files, the deep revert has already removed
    //    them — the existence check below naturally skips those.
    final planId = 'last_run_${context.core.name}';
    final report = await PlanStore.instance.loadPlan(
      planId,
      baseDir: projectRoot,
    );

    if (report == null) {
      if (context.core.verbose) {
        print(
          '  ⚠️ No saved plan found for ${context.core.name} in $projectRoot. '
          'Relying on deep revert only.',
        );
      }
      // Still return the deep-revert deletions (previously this returned
      // `[]`, which silently swallowed the orphan-architecture case).
      return files;
    }

    if (context.core.verbose) {
      print(
        '  🔄 Reverting ${report.changes.length} tracked changes from plan in $projectRoot...',
      );
    }

    for (final change in report.changes.reversed) {
      if (context.core.verbose) {
        print('    - Reverting ${change.action} for ${change.file}');
      }
      if (!await context.fileSystem.exists(change.file)) {
        if (context.core.verbose) {
          print('      ⏭ File does not exist, skipping.');
        }
        continue;
      }

      if (change.action == 'create' || change.action == 'created') {
        if (!context.core.dryRun) {
          await context.fileSystem.delete(change.file);
          if (context.core.verbose) print('      🗑 Deleted file.');
        }
        files.add(
          GeneratedFile(path: change.file, type: 'unknown', action: 'deleted'),
        );
      } else if (change.action == 'update' || change.action == 'overwritten') {
        if (change.previousContent != null) {
          if (!context.core.dryRun) {
            await context.fileSystem.write(
              change.file,
              change.previousContent!,
            );
            if (context.core.verbose) {
              print('      📝 Restored previous content.');
            }
          }
          files.add(
            GeneratedFile(
              path: change.file,
              type: 'unknown',
              action: 'overwritten',
              content: change.previousContent,
            ),
          );
        }
      }
    }

    await PlanStore.instance.deletePlan(planId, baseDir: projectRoot);
    return files;
  }

  /// Deletes all canonical generated-architecture files for the entity
  /// named [context.core.name], regardless of whether the current run
  /// generated them.
  ///
  /// This is the "deep revert" path (issue #323): when an entity is
  /// re-modeled as a value object, the previously generated CRUD
  /// architecture stays on disk as orphans because `zfa make` for a
  /// value object generates nothing and overwrites the saved plan with
  /// an empty one. Deep revert walks the canonical entity-snake-keyed
  /// paths the generators would produce and deletes those that exist,
  /// so `zfa make <Entity> --revert` cleans up the entity's generated
  /// architecture uniformly.
  ///
  /// The entity source file itself
  /// (`lib/src/domain/entities/<snake>/<snake>.dart`) is NEVER touched —
  /// the entity is the source of truth, not generated architecture.
  /// Re-modeling the entity (entity ↔ value_object, field changes) is
  /// the user's job; `--revert` only removes generated architecture.
  ///
  /// Dry-run mode lists files that would be deleted without touching
  /// the filesystem, mirroring the plan-based revert's dry-run behavior.
  Future<List<GeneratedFile>> _deepRevertEntityArchitecture(
    PluginContext context,
  ) async {
    final entityName = context.core.name;
    final snake = StringUtils.camelToSnake(entityName);
    final fs = context.fileSystem;
    final dryRun = context.core.dryRun;
    final verbose = context.core.verbose;
    final deleted = <GeneratedFile>[];

    if (verbose) {
      print(
        '  🧹 Deep revert: removing generated architecture for '
        '"$entityName" (snake: $snake)...',
      );
    }

    // Directories fully owned by this entity's generation: every .dart
    // file under them was produced by the generator for THIS entity (the
    // directory itself is snake-named after the entity). Delete every
    // .dart file inside, then prune the directory if it becomes empty.
    final entityScopedDirs = <String>[
      path.join('lib', 'src', 'data', 'datasources', snake),
      path.join('lib', 'src', 'domain', 'usecases', snake),
      path.join('lib', 'src', 'presentation', 'pages', snake),
      path.join('test', 'domain', 'usecases', snake),
      path.join('test', 'presentation', 'pages', snake),
    ];

    for (final dir in entityScopedDirs) {
      if (!await fs.exists(dir)) continue;
      if (!await fs.isDirectory(dir)) continue;
      final entries = await fs.list(dir, recursive: true);
      for (final entry in entries) {
        if (!entry.endsWith('.dart')) continue;
        final base = path.basename(entry);
        // Skip keep-file markers — they're not Dart source.
        if (base == '.gitkeep' || base == '.keep') continue;
        if (!dryRun) {
          await fs.delete(entry);
        }
        deleted.add(
          GeneratedFile(path: entry, type: 'deep_revert', action: 'deleted'),
        );
        if (verbose) print('    🗑 Deleted file: $entry');
      }
      // Prune the directory if it is now empty (or only keeps markers).
      if (!dryRun) {
        final remaining = await fs.list(dir);
        final onlyMarkers =
            remaining.isEmpty ||
            remaining.every((e) {
              final b = path.basename(e);
              return b == '.gitkeep' || b == '.keep';
            });
        if (onlyMarkers) {
          await fs.delete(dir);
          if (verbose) print('    🗑 Pruned empty directory: $dir');
        }
      }
    }

    // Entity-keyed files in shared directories: exact paths the generators
    // write for this entity. Delete those that exist. These live alongside
    // other entities' files, so we never delete the parent directory.
    final entityKeyedFiles = <String>[
      // data layer
      path.join(
        'lib',
        'src',
        'data',
        'repositories',
        'data_${snake}_repository.dart',
      ),
      path.join('lib', 'src', 'data', 'mock', '${snake}_mock_data.dart'),
      path.join('lib', 'src', 'data', 'cache', '${snake}_cache.dart'),
      path.join('lib', 'src', 'data', 'sync', '${snake}_sync.dart'),
      path.join('lib', 'src', 'data', 'providers', '${snake}_provider.dart'),
      // domain layer (excluding the entity source directory — never touch)
      path.join(
        'lib',
        'src',
        'domain',
        'repositories',
        '${snake}_repository.dart',
      ),
      path.join('lib', 'src', 'domain', 'services', '${snake}_service.dart'),
      // di layer
      path.join(
        'lib',
        'src',
        'di',
        'repositories',
        '${snake}_repository_di.dart',
      ),
      path.join(
        'lib',
        'src',
        'di',
        'datasources',
        '${snake}_datasource_di.dart',
      ),
      path.join('lib', 'src', 'di', 'services', '${snake}_service_di.dart'),
      path.join('lib', 'src', 'di', 'providers', '${snake}_provider_di.dart'),
      // presentation layer
      path.join('lib', 'src', 'presentation', 'routes', '${snake}_route.dart'),
      path.join(
        'lib',
        'src',
        'presentation',
        'observers',
        '${snake}_observer.dart',
      ),
      path.join(
        'lib',
        'src',
        'presentation',
        'providers',
        '${snake}_provider.dart',
      ),
      // shared-directory tests (entity-scoped test dirs handled above)
      path.join(
        'test',
        'data',
        'repositories',
        'data_${snake}_repository_test.dart',
      ),
      path.join(
        'test',
        'domain',
        'repositories',
        '${snake}_repository_test.dart',
      ),
    ];

    for (final file in entityKeyedFiles) {
      if (!await fs.exists(file)) continue;
      // Safety: never recursively delete a path that turned out to be a
      // directory (shouldn't happen for these canonical file paths, but
      // guard against name collisions anyway).
      if (await fs.isDirectory(file)) continue;
      if (!dryRun) {
        await fs.delete(file);
      }
      deleted.add(
        GeneratedFile(path: file, type: 'deep_revert', action: 'deleted'),
      );
      if (verbose) print('    🗑 Deleted file: $file');
    }

    // Glob-keyed files in shared directories: per-method DI registrations
    // (`<op>_<snake>_usecase_di.dart`). The method prefix varies
    // (get_/create_/update_/delete_/toggle_/watch_/...), so we glob by
    // suffix. The shared directory itself is never deleted.
    final diUsecasesDir = path.join('lib', 'src', 'di', 'usecases');
    final usecaseDiSuffix = '_${snake}_usecase_di.dart';
    if (await fs.exists(diUsecasesDir) && await fs.isDirectory(diUsecasesDir)) {
      final entries = await fs.list(diUsecasesDir);
      for (final entry in entries) {
        if (!entry.endsWith('.dart')) continue;
        if (!path.basename(entry).endsWith(usecaseDiSuffix)) continue;
        if (!dryRun) {
          await fs.delete(entry);
        }
        deleted.add(
          GeneratedFile(path: entry, type: 'deep_revert', action: 'deleted'),
        );
        if (verbose) print('    🗑 Deleted file: $entry');
      }
    }

    if (verbose && deleted.isNotEmpty) {
      print('  🧹 Deep revert: removed ${deleted.length} file(s).');
    } else if (verbose) {
      print(
        '  🧹 Deep revert: no generated architecture found for '
        '"$entityName".',
      );
    }

    return deleted;
  }

  /// Executes the full generation lifecycle for the active plugins.
  Future<List<GeneratedFile>> run(
    PluginContext context,
    List<ZuraffaPlugin> activePlugins, {
    ProgressReporter? progress,
  }) async {
    // 0. Handle Revert if requested
    if (context.core.revert) {
      return await _handleRevert(context);
    }

    await _validateEntityFirstPreconditions(context, activePlugins);

    final allFiles = <GeneratedFile>[];
    final startedAt = DateTime.now().toUtc();

    // Sort plugins by dependencies before running
    final sortedPlugins = registry.sortPlugins(activePlugins);

    // Initialize transaction for this run
    final transaction = GenerationTransaction(
      dryRun: context.core.dryRun,
      force: context.core.force,
    );

    if (progress != null) {
      progress.started('Generating ${context.core.name}', sortedPlugins.length);
    }

    await GenerationTransaction.run(transaction, () async {
      // 1. Validate
      for (final plugin in sortedPlugins) {
        final result = await plugin.validate(context);
        if (!result.isValid) {
          throw StateError(
            'Validation failed for plugin ${plugin.id}: ${result.reasons.join(", ")}',
          );
        }
      }

      // 2. Before Generate
      for (final plugin in sortedPlugins) {
        await plugin.beforeGenerate(context);
      }

      // 3. Generate
      try {
        for (final plugin in sortedPlugins) {
          if (plugin is FileGeneratorPlugin) {
            if (progress != null) {
              progress.update(plugin.id);
            } else if (context.core.verbose) {
              print('  Running ${plugin.name}...');
            }
            final files = await plugin.generateWithContext(context);
            allFiles.addAll(files);
          }
        }
      } catch (e, stack) {
        // 4. On Error
        for (final plugin in sortedPlugins) {
          await plugin.onError(context, e, stack);
        }
        rethrow;
      }

      // Commit the transaction - MUST pass baseFileSystem (not transactional one to avoid recursion/confusion during final write)
      final baseFs = context.fileSystem is TransactionalFileSystem
          ? (context.fileSystem as TransactionalFileSystem).base
          : context.fileSystem;

      final result = await transaction.commit(baseFs);
      if (!result.success) {
        throw StateError('Transaction failed: ${result.errors.join(", ")}');
      }

      // 5. After Generate
      for (final plugin in sortedPlugins) {
        await plugin.afterGenerate(context);
      }
    });

    if (!context.core.dryRun && !context.core.revert) {
      final completedAt = DateTime.now().toUtc();
      await _persistProjectMemory(
        context: context,
        sortedPlugins: sortedPlugins,
        allFiles: allFiles,
        transaction: transaction,
        startedAt: startedAt,
        completedAt: completedAt,
      );
    }

    if (progress != null) {
      progress.completed();
    }

    return allFiles;
  }

  Future<void> _persistProjectMemory({
    required PluginContext context,
    required List<ZuraffaPlugin> sortedPlugins,
    required List<GeneratedFile> allFiles,
    required GenerationTransaction transaction,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    final planId = 'last_run_${context.core.name}';
    final pluginIds = sortedPlugins
        .map((plugin) => plugin.id)
        .toList(growable: false);
    final normalizedArgs = Map<String, dynamic>.from(context.data)
      ..['plugin_ids'] = pluginIds
      ..['execution_order'] = pluginIds
      ..['output_dir'] = _normalizeProjectPath(context.core.outputDir);

    final report = EffectReport(
      planId: planId,
      pluginId: 'manager',
      capabilityName: 'make',
      args: normalizedArgs,
      changes: transaction.operations
          .map(
            (operation) => Effect(
              file: _normalizeProjectPath(operation.path),
              action: operation.type.name,
              previousContent: operation.previousContent,
            ),
          )
          .toList(growable: false),
    );
    await PlanStore.instance.savePlan(report, baseDir: projectRoot);

    // Save run artifact
    final runStore = RunStore(projectRoot: projectRoot);
    await runStore.save(
      RunArtifact(
        name: context.core.name,
        timestamp: startedAt,
        duration: completedAt.difference(startedAt),
        success: true,
        files: allFiles,
        errors: [],
        warnings: [],
        options: normalizedArgs,
      ),
    );

    // Save project context
    final contextStore = ProjectContextStore(projectRoot: projectRoot);
    await contextStore.save(ProjectContextStore.defaultContext());
  }

  String _normalizeProjectPath(String value) {
    if (value.isEmpty) {
      return value;
    }
    return path.isAbsolute(value)
        ? path.relative(value, from: projectRoot)
        : value;
  }

  /// Returns `true` when [plugin]'s own `configSchema` declares a property
  /// named `plugin.id` with a non-boolean `type`.
  ///
  /// Used by the activation sync in [buildContext] to decide whether to
  /// write `data[id] = true` (the #346 fast path — safe when the slot is
  /// boolean-typed or unclaimed) or to record the activation under
  /// `data['__active_<id>']` instead (issue #412 — required when the slot
  /// is claimed by a string/integer/array schema property, so the bool
  /// doesn't poison the typed value the schema-default merge below would
  /// otherwise fill in).
  ///
  /// Schemas are JSON-shaped (`Map<String, dynamic>`), but pub cache
  /// literals sometimes surface as `_Map<dynamic, dynamic>`; the
  /// defensive `is Map` + `Map.from` casts keep this helper robust to
  /// both shapes.
  bool _ownSchemaDeclaresNonBoolean(ZuraffaPlugin plugin) {
    final schema = plugin.configSchema;
    final propsRaw = schema['properties'];
    if (propsRaw is! Map) return false;
    final props = Map<String, dynamic>.from(propsRaw);
    final ownRaw = props[plugin.id];
    if (ownRaw is! Map) return false;
    final own = Map<String, dynamic>.from(ownRaw);
    final type = own['type'];
    return type != null && type != 'boolean';
  }

  Future<void> _validateEntityFirstPreconditions(
    PluginContext context,
    List<ZuraffaPlugin> activePlugins,
  ) async {
    final methods = switch (context.data['methods']) {
      List<dynamic> values =>
        values
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
      String value =>
        value
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      _ => const <String>[],
    };
    final noEntity = context.data['no-entity'] == true;
    final entityAwarePlugins = {
      'usecase',
      'repository',
      'datasource',
      'view',
      'presenter',
      'controller',
      'state',
      'route',
      'mock',
      'cache',
      'test',
    };

    final requiresEntity =
        config?.entityFirst == true &&
        !noEntity &&
        methods.isNotEmpty &&
        activePlugins.any((plugin) => entityAwarePlugins.contains(plugin.id));

    if (!requiresEntity) {
      return;
    }

    final entitySnake = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
    ).nameSnake;
    final entityPath = path.join(
      context.core.outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );

    if (await context.fileSystem.exists(entityPath)) {
      return;
    }

    throw StateError(
      'Entity "${context.core.name}" not found at $entityPath. '
      'Create it first with `zfa entity create -n ${context.core.name}` and then run `zfa build`.',
    );
  }
}
