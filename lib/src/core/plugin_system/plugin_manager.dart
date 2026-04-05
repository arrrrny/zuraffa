import 'dart:io';
import 'package:args/args.dart';
import '../../config/zfa_config.dart';
import '../../cli/plugin_loader.dart';
import '../context/file_system.dart';
import '../context/progress_reporter.dart';
import '../transaction/transactional_file_system.dart';
import 'plugin_interface.dart';
import 'plugin_registry.dart';
import 'plugin_context.dart';
import 'discovery_engine.dart';
import 'plan_store.dart';
import 'capability.dart';
import '../../models/generated_file.dart';
import '../transaction/generation_transaction.dart';

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
  }) : projectRoot = projectRoot ?? Directory.current.path;

  /// Resolves the set of active plugins based on explicit requests,
  /// config defaults, and explicit muting (--no-flags).
  List<ZuraffaPlugin> resolveActivePlugins({
    required List<String> explicitPluginIds,
    required ArgResults? argResults,
  }) {
    final activeIds = <String>{...explicitPluginIds};

    // 1. Add defaults from config if not explicitly muted
    for (final plugin in registry.plugins) {
      final configKey = plugin.configKey;
      if (configKey != null) {
        // Check if enabled by default in .zfa.json
        final isDefault = _getConfigValue(configKey) ?? false;

        // Check if explicitly muted via --no-plugin_id
        final isMuted =
            argResults != null &&
            argResults.wasParsed(plugin.id) &&
            argResults[plugin.id] == false;

        if (isDefault && !isMuted) {
          activeIds.add(plugin.id);
        }
      }
    }

    // 2. Filter out any plugin that is explicitly muted via --no-flag
    if (argResults != null) {
      activeIds.removeWhere((id) {
        return argResults.wasParsed(id) && argResults[id] == false;
      });
    }

    // 3. Filter out disabled plugins from PluginConfig
    if (pluginConfig != null) {
      activeIds.removeWhere((id) => pluginConfig!.disabled.contains(id));
    }

    final activePlugins = activeIds
        .map((id) => registry.getById(id))
        .whereType<ZuraffaPlugin>()
        .toList();

    // 4. Sort by dependencies (DAG)
    return registry.sortPlugins(activePlugins);
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

    final allFiles = <GeneratedFile>[];

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

      // 6. Save execution plan for future revert
      if (!context.core.dryRun && !context.core.revert) {
        final report = EffectReport(
          planId: 'last_run_${context.core.name}',
          pluginId: 'manager',
          capabilityName: 'make',
          args: context.data,
          changes: transaction.operations
              .map(
                (op) => Effect(
                  file: op.path,
                  action: op.type.name,
                  previousContent: op.previousContent,
                ),
              )
              .toList(),
        );
        await PlanStore.instance.savePlan(report, baseDir: projectRoot);
      }
    });

    if (progress != null) {
      progress.completed();
    }

    return allFiles;
  }

  bool? _getConfigValue(String key) {
    if (config == null) return null;
    final json = config!.toJson();
    return json[key] as bool?;
  }
}
