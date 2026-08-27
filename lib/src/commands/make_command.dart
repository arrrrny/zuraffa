import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:args/command_runner.dart';
import '../config/zfa_config.dart';
import '../cli/plugin_loader.dart';
import '../core/project/project_root.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../models/generated_file.dart';
import '../utils/entity_field_resolver.dart';

/// Command to run multiple plugins explicitly.
/// Usage: `zfa make <Name> <plugin1> <plugin2> ... [flags]`
/// Example: `zfa make User route di --force`
class MakeCommand extends Command<void> {
  static const String fixedOutputDir = 'lib/src';

  /// Plugins that build a persisted/root CRUD surface around an entity.
  /// Value objects (zuraffa#307) are immutable composition types — none of
  /// these apply to them, so `zfa make` drops them with a notice instead of
  /// generating dead repository/usecase/controller/presenter code.
  static const Set<String> _valueObjectRootPlugins = {
    'repository',
    'datasource',
    'usecase',
    'controller',
    'presenter',
    'view',
    'route',
    'state',
    'provider',
    'observer',
    'cache',
    'gql',
    'graphql',
    'di',
    'service',
    'api',
    'sync',
    'shadcn',
    'test', // entity tests reference the usecases value objects don't get
  };

  /// Plugins whose generated output embeds the entity's identity in
  /// signatures (getById/update/delete params, id-typed route params,
  /// id-keyed queries, ...). Issue #508: the #307 loud no-id failure must
  /// fire only when at least one of these is active — id-NEUTRAL plugins
  /// (`test`, `mock`, `gym`, `di`, `cache`, ...) regenerate from
  /// already-generated artifacts and legitimately work for id-less
  /// entities.
  ///
  /// The named five from the issue plus every other plugin verified to
  /// emit id-typed members: service and provider (UpdateParams/DeleteParams
  /// interfaces), route and view (id-typed route params), gql/graphql
  /// (id-keyed operations), sqlite (id-keyed CRUD), api (bridges id-typed
  /// usecase params), sync (getByIds keys).
  static const Set<String> _idDependentPlugins = {
    'repository',
    'datasource',
    'usecase',
    'controller',
    'presenter',
    'service',
    'provider',
    'route',
    'view',
    'gql',
    'graphql',
    'sqlite',
    'api',
    'sync',
  };

  static const Set<String> _ignoredJsonOptionKeys = {
    'domainRoot',
    'domain-root',
    'domain_root',
    'domainOutput',
    'domain-output',
    'domain_output',
    'entityOutput',
    'entity-output',
    'entity_output',
    'output',
    'output-dir',
    'output_dir',
    'useZorphy',
    'zorphy',
  };

  final PluginRegistry registry;
  late final PluginManager manager;

  MakeCommand(this.registry) {
    final projectRoot = _findProjectRoot();
    manager = PluginManager(
      registry: registry,
      config: ZfaConfig.load(projectRoot: projectRoot),
      pluginConfig: PluginConfig.load(projectRoot: projectRoot),
      projectRoot: projectRoot,
    );
    _addCoreOptions();
    _addPluginOptions();
  }

  String _findProjectRoot() {
    // Route through ProjectRoot.find, which tolerates an invalid CWD
    // (deleted temp dir under `dart test`, chdir into a gone path in
    // CI/containers) instead of throwing PathNotFoundException.
    // See issue #441.
    return ProjectRoot.find();
  }

  void _addCoreOptions() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Output directory for generated files (fixed to lib/src in v5; custom values are ignored)',
      defaultsTo: fixedOutputDir,
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
    argParser.addOption(
      'from-json',
      abbr: 'j',
      help: 'JSON configuration file',
    );
    argParser.addFlag(
      'from-stdin',
      negatable: false,
      help: 'Read JSON configuration from stdin',
    );
    argParser.addOption('preset', help: 'Generation preset to expand');
    argParser.addMultiOption('with', help: 'Additional plugins or aliases');
    argParser.addMultiOption('without', help: 'Plugins or aliases to exclude');
    argParser.addFlag(
      'plan',
      negatable: false,
      help: 'Print the normalized execution plan and exit',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help: 'Explain the normalized execution plan and exit',
    );

    argParser.addMultiOption('methods', help: 'Entity methods to generate');
    argParser.addMultiOption(
      'usecases',
      help: 'UseCases to inject into presenter/controller',
    );
    argParser.addMultiOption(
      'variants',
      help: 'Polymorphic variants to generate',
    );
    argParser.addOption('domain', help: 'Domain subfolder');
    argParser.addOption('repo', help: 'Repository to inject');
    argParser.addOption('service', help: 'Service to inject');
    argParser.addOption('id-field', help: 'ID field name', defaultsTo: 'id');
    argParser.addOption(
      'id-field-type',
      help: 'ID field type',
      defaultsTo: 'String',
    );
    argParser.addOption(
      'query-field',
      help: 'Query field name',
      defaultsTo: 'id',
    );
    argParser.addOption('query-field-type', help: 'Query field type');
    argParser.addFlag('no-entity', negatable: false, help: 'Skip entity');
    argParser.addFlag('vpc', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('vpcs', negatable: false, help: 'Generate full VPC set');
    argParser.addFlag('state', negatable: false, help: 'Generate state class');
    argParser.addFlag('data', negatable: false, help: 'Generate data layer');
    argParser.addFlag(
      'datasource',
      negatable: false,
      help: 'Generate data source',
    );
    argParser.addFlag('cache', negatable: false, help: 'Enable caching');
    argParser.addFlag(
      'sync',
      negatable: false,
      help: 'Enable offline-first sync',
    );
    argParser.addFlag(
      'bidirectional',
      negatable: false,
      help: 'Enable bidirectional sync (push + pull)',
    );
    argParser.addOption(
      'sync-batch-size',
      help: 'Sync batch size (default: 50)',
      defaultsTo: '50',
    );
    argParser.addOption(
      'sync-max-retries',
      help: 'Max sync retry attempts (default: 5)',
      defaultsTo: '5',
    );
    argParser.addFlag('route', negatable: false, help: 'Generate route');
    argParser.addFlag('mock', negatable: false, help: 'Generate mock data');
    argParser.addFlag('test', negatable: false, help: 'Generate tests');
    argParser.addFlag(
      'append',
      negatable: false,
      help: 'Append to existing repo/service',
    );
    argParser.addFlag(
      'xray',
      negatable: false,
      help: 'Generate views with X-Ray scope/node decoration (issue #360)',
    );
  }

  void _addPluginOptions() {
    final addedOptions = <String>{
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
      'format',
      'from-json',
      'from-stdin',
      'preset',
      'with',
      'without',
      'plan',
      'explain',
      'methods',
      'usecases',
      'variants',
      'domain',
      'repo',
      'service',
      'id-field',
      'id-field-type',
      'query-field',
      'query-field-type',
      'no-entity',
      'vpc',
      'vpcs',
      'state',
      'data',
      'datasource',
      'cache',
      'sync',
      'bidirectional',
      'sync-batch-size',
      'sync-max-retries',
      'route',
      'mock',
      'test',
      'append',
      'xray',
    };

    for (final plugin in registry.plugins) {
      // Add a flag for the plugin itself to allow --no-<plugin> muting
      if (!addedOptions.contains(plugin.id)) {
        argParser.addFlag(
          plugin.id,
          help: 'Enable or disable ${plugin.name}',
          defaultsTo: true,
          negatable: true,
        );
        addedOptions.add(plugin.id);
      }

      // Add flags/options from plugin schema
      final schema = plugin.configSchema;
      if (schema.containsKey('properties')) {
        final properties = Map<String, dynamic>.from(
          schema['properties'] as Map,
        );
        for (final entry in properties.entries) {
          final key = entry.key;
          if (addedOptions.contains(key)) continue;

          final config = Map<String, dynamic>.from(entry.value as Map);
          final type = config['type'];
          final help = config['description'] ?? '';
          final def = config['default'];

          if (type == 'boolean') {
            argParser.addFlag(key, help: help, defaultsTo: def ?? false);
          } else if (type == 'string' ||
              type == 'integer' ||
              type == 'number') {
            argParser.addOption(key, help: help, defaultsTo: def?.toString());
          } else if (type == 'array') {
            argParser.addMultiOption(
              key,
              help: help,
              defaultsTo: (def as List?)?.cast<String>(),
            );
          }
          addedOptions.add(key);
        }
      }
    }
  }

  @override
  String get name => 'make';

  @override
  String get description => 'Run multiple generator plugins explicitly.';

  @override
  String get invocation => 'zfa make <Name> <plugin1> <plugin2> ... [options]';

  /// Returns true if dry-run mode is enabled.
  bool get isDryRun => argResults?['dry-run'] == true;

  /// Returns true if force mode is enabled.
  bool get isForce => argResults?['force'] == true;

  /// Returns true if verbose logging is enabled.
  bool get isVerbose => argResults?['verbose'] == true;

  /// Returns true if revert mode is enabled.
  bool get isRevert => argResults?['revert'] == true;

  /// Returns the resolved output directory.
  String get outputDir => fixedOutputDir;

  @override
  Future<void> run() async {
    final jsonConfig = await _loadJsonConfig();
    final rest = argResults!.rest;

    if (rest.isEmpty && jsonConfig == null) {
      print('❌ Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print('Example: zfa make User route di');
      exit(1);
    }

    final entityName = rest.isNotEmpty
        ? rest.first
        : (jsonConfig?['name']?.toString() ?? '');
    if (entityName.isEmpty) {
      print('❌ Missing required feature/entity name.');
      exit(1);
    }

    final explicitPluginIds = rest.skip(1).toList();
    final normalizedOptions = _normalizedOptions(jsonConfig);
    final plan = manager.resolvePlan(
      name: entityName,
      explicitPluginIds: explicitPluginIds,
      argResults: argResults!,
      options: normalizedOptions,
    );

    if (argResults?['plan'] == true || argResults?['explain'] == true) {
      _printPlan(plan);
      return;
    }

    final activePlugins = plan.activePlugins;
    if (activePlugins.isEmpty) {
      print('❌ No active plugins to run.');
      return;
    }

    final context = manager.buildContext(
      name: entityName,
      argResults: argResults!,
      activePlugins: activePlugins,
      overrideOutputDir: fixedOutputDir,
    );
    context.data.addAll(normalizedOptions);

    // #360: honor .zfa.json xray default for the view plugin.
    // --xray flag always wins; otherwise fall back to config. An explicit
    // `false` already present in context.data (e.g. set by a plugin or
    // via --from-json) is preserved — the config fallback only fires when
    // the key is absent.
    final xrayFlag = argResults!['xray'] as bool? ?? false;
    if (xrayFlag || !context.data.containsKey('xray')) {
      final xrayConfig = ZfaConfig.load(projectRoot: manager.projectRoot);
      context.data['xray'] = xrayFlag || (xrayConfig?.xrayByDefault ?? false);
    }

    // #294/#307: auto-resolve the entity's actual id-like field from the
    // entity source file so the generated presenter/test/datasource
    // code references a Field constant that exists on the entity's
    // Fields class. Without this, generators hardcode `EntityFields.id`
    // and produce broken code for entities whose id is e.g. `depotId`.
    // User-provided --id-field / --query-field always wins.
    //
    // #307: the old resolver fell back to the FIRST field as the id —
    // for id-less entities whose first field is an enum (ChatMessage.role,
    // TelemetryEvent.type) that produced enum-typed ids and missing enum
    // imports. The fallback is gone: id-less entities must opt into
    // `autoId`, and value objects are treated as embedded types (their
    // root plugins are dropped below).
    if (context.data['no-entity'] != true) {
      final resolution = EntityFieldResolver.resolveIdField(
        entityName: entityName,
        projectRoot: manager.projectRoot,
      );
      if (resolution != null) {
        if (resolution.isValueObject) {
          final dropped =
              activePlugins
                  .where((p) => _valueObjectRootPlugins.contains(p.id))
                  .map((p) => p.id)
                  .toList()
                ..sort();
          if (dropped.isNotEmpty) {
            print(
              'ℹ️  "$entityName" is a value object — skipping root plugins '
              '(no repository/usecase/controller/presenter for embedded '
              'types): ${dropped.join(', ')}',
            );
            activePlugins.removeWhere(
              (p) => _valueObjectRootPlugins.contains(p.id),
            );
          }
        } else if (resolution.hasId) {
          if (!argResults!.wasParsed('id-field') &&
              (context.data['id-field'] == null ||
                  context.data['id-field'] == 'id')) {
            context.data['id-field'] = resolution.idField!.name;
            context.data['id-field-type'] = resolution.idField!.nonNullableType;
            if (context.core.verbose) {
              print(
                '🔍 Resolved id field for "$entityName": '
                '${resolution.idField!.name} '
                '(${resolution.idField!.nonNullableType})',
              );
            }
          }
          if (!argResults!.wasParsed('query-field') &&
              (context.data['query-field'] == null ||
                  context.data['query-field'] == 'id')) {
            context.data['query-field'] = resolution.idField!.name;
            // query-field-type falls back to id-field-type inside
            // GeneratorConfig's constructor (see generator_config.dart).
          }
        } else {
          // Loud failure (issue #307): an entity with no id-like field and
          // no autoId marker would silently produce enum-typed ids /
          // broken signatures if we fell back to the first field.
          //
          // Issue #508: that requirement only applies to id-DEPENDENT
          // plugins — the ones whose generated signatures embed the id.
          // Id-neutral plugins (test/mock regeneration from
          // already-generated usecases, di, ...) legitimately work for
          // id-less entities and must proceed.
          final hasIdDependentPlugin = activePlugins.any(
            (plugin) => _idDependentPlugins.contains(plugin.id),
          );
          if (hasIdDependentPlugin) {
            print(
              '❌ Cannot generate architecture for "$entityName": the entity '
              'has no id field.',
            );
            print('');
            print('Entities need a real identity. Choose one of:');
            print(
              '  1. Add an id field:    zfa entity add-field -n '
              '$entityName --field id:String',
            );
            print(
              '  2. Auto-generate one:  recreate with '
              'zfa entity create -n $entityName --auto-id <fields...>',
            );
            print(
              '  3. Mark it as a value object if it is an immutable '
              'composition type (no identity, no CRUD surface):',
            );
            print(
              '       zfa entity create -n $entityName --kind=value_object '
              '<fields...>',
            );
            print(
              '     or add @ZValueObject / kind: ZorphyKind.valueObject '
              'to its annotation.',
            );
            print('');
            // Thrown (not `exit(1)`) so the CLI runner's catch-all prints the
            // diagnostic and exits 1 — while `runCapturing` tests can assert
            // on the message without killing the test isolate.
            throw MakeCommandException(
              'Cannot generate architecture for "$entityName": the entity '
              'has no id field.',
            );
          }

          // #508 id-neutral path: the generators still need a query/filter
          // key so the regenerated tests reference a Field constant that
          // exists (and the seeded mock data matches the get/update/toggle
          // filters). Resolve a representative REAL field — never an
          // enum-typed field, never a synthetic id. User-provided
          // --query-field always wins.
          if (!argResults!.wasParsed('query-field') &&
              (context.data['query-field'] == null ||
                  context.data['query-field'] == 'id')) {
            final representative =
                EntityFieldResolver.resolveRepresentativeField(
                  entityName: entityName,
                  projectRoot: manager.projectRoot,
                );
            if (representative != null) {
              context.data['query-field'] = representative.name;
              context.data['query-field-type'] = representative.nonNullableType;
              if (context.core.verbose) {
                print(
                  '🔍 Resolved query field for "$entityName" (id-less, '
                  'id-neutral plugins): ${representative.name} '
                  '(${representative.nonNullableType})',
                );
              }
            }
          }
        }
      }
    }

    if (context.core.verbose) {
      print(
        '🚀 Running plugins: ${activePlugins.map((p) => p.id).join(", ")} for $entityName...',
      );
    }

    try {
      final files = await manager.run(context, activePlugins);
      _logSummary(files, context.core.verbose, plan: plan);
    } catch (e) {
      print('❌ Generation failed: $e');
      if (context.core.verbose) {
        rethrow;
      }
      exit(1);
    }

    if (argResults?['format'] != 'json') {
      print('✅ Done.');
    }
  }

  Future<Map<String, dynamic>?> _loadJsonConfig() async {
    try {
      if (argResults?['from-stdin'] == true) {
        final input = await stdin.transform(utf8.decoder).join();
        if (input.trim().isEmpty) return null;
        return jsonDecode(input) as Map<String, dynamic>;
      }

      final fromJson = argResults?['from-json'] as String?;
      if (fromJson == null || fromJson.isEmpty) {
        return null;
      }

      final file = File(fromJson);
      if (!file.existsSync()) {
        throw StateError('JSON file not found: $fromJson');
      }
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error parsing JSON input: $e');
      exit(1);
    }
  }

  Map<String, dynamic> _normalizedOptions(Map<String, dynamic>? jsonConfig) {
    final normalized = <String, dynamic>{};
    if (jsonConfig == null) {
      return normalized;
    }

    jsonConfig.forEach((key, value) {
      final normalizedKey = key.replaceAll('_', '-');
      if (_ignoredJsonOptionKeys.contains(key) ||
          _ignoredJsonOptionKeys.contains(normalizedKey)) {
        return;
      }
      normalized[normalizedKey] = value;
      normalized[key] = value;
    });

    return normalized;
  }

  void _printPlan(dynamic plan) {
    if (argResults?['format'] == 'json') {
      print(jsonEncode({'success': true, 'plan': plan.toJson()}));
      return;
    }

    print('🧭 Normalized plan for ${plan.name}:');
    if (plan.preset != null) {
      print('  Preset: ${plan.preset}');
    }
    print('  Requested: ${plan.requestedPluginIds.join(', ')}');
    print('  Resolved: ${plan.pluginIds.join(', ')}');
    if (plan.warnings.isNotEmpty) {
      print('  Warnings:');
      for (final warning in plan.warnings) {
        print('    - $warning');
      }
    }
  }

  void _logSummary(
    List<GeneratedFile> files,
    bool verbose, {
    required dynamic plan,
  }) {
    if (argResults?['format'] == 'json') {
      print(
        jsonEncode({
          'success': true,
          'plan': plan.toJson(),
          'files': files.map((file) => file.toJson()).toList(),
          'warnings': plan.warnings,
        }),
      );
      return;
    }

    if (files.isEmpty) {
      print('ℹ️  No files generated.');
      return;
    }

    final created = files.where((f) => f.action == 'created').length;
    final overwritten = files
        .where((f) => f.action == 'overwritten' || f.action == 'updated')
        .length;
    final skipped = files.where((f) => f.action == 'skipped').length;
    final deleted = files
        .where((f) => f.action == 'deleted' || f.action == 'reverted')
        .length;

    print('\n✅ Generation complete:');
    if (created > 0) print('  ✨ Created: $created files');
    if (overwritten > 0) print('  📝 Overwritten: $overwritten files');
    if (skipped > 0) print('  ⏭ Skipped: $skipped files');
    if (deleted > 0) print('  🗑 Deleted: $deleted files');

    if (!verbose) {
      for (final file in files) {
        final prefix = switch (file.action) {
          'created' => '  ✨',
          'overwritten' => '  📝',
          'updated' => '  📝',
          'deleted' => '  🗑',
          'reverted' => '  🗑',
          _ => '  ⏭',
        };
        if (file.action != 'skipped') {
          print('$prefix ${file.path}');
        }
      }
    }
  }
}

/// Thrown when `zfa make` cannot proceed because of an entity-contract
/// violation (e.g. an id-less entity without `autoId` — issue #307).
///
/// The CLI runner's catch-all prints the message and exits 1; tests using
/// `runCapturing` catch it without terminating the isolate.
class MakeCommandException implements Exception {
  final String message;

  const MakeCommandException(this.message);

  @override
  String toString() => message;
}
