import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import '../../config/zfa_config.dart';
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
            } else if (propertyConfig.containsKey('default')) {
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

    // Sync plugin activation flags into data so plugins can inspect each other
    final activePluginIds = activePlugins.map((p) => p.id).toSet();
    for (final id in activePluginIds) {
      if (!data.containsKey(id)) {
        data[id] = true;
      }
    }

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
    final planId = 'last_run_${context.core.name}';
    final report = await PlanStore.instance.loadPlan(
      planId,
      baseDir: projectRoot,
    );

    if (report == null) {
      if (context.core.verbose) {
        print(
          '  ⚠️ No saved plan found for ${context.core.name} in $projectRoot. Falling back to heuristic revert.',
        );
      }
      return []; // Return empty to let legacy revert handle it or just fail gracefully
    }

    final files = <GeneratedFile>[];
    if (context.core.verbose) {
      print(
        '  🔄 Reverting ${report.changes.length} changes from plan in $projectRoot...',
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
