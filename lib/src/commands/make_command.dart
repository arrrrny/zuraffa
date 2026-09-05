import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart' as p;
// Show-listed: the zorphy barrel also exports PluginRegistry and
// PluginContext, which collide with zuraffa's own plugin-system types.
import 'package:zorphy/zorphy.dart'
    show EntityConfig, EntityCreator, FieldDefinition;

import '../plugins/shadcn/vocabulary/composite_scaffolder.dart';
import '../plugins/shadcn/vocabulary/ui_node_registry.dart';
import '../config/zfa_config.dart';
import '../cli/plugin_loader.dart';
import '../core/branding/branding_writer.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_context.dart';
import '../core/project/project_root.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../engine/engine_checker.dart';
import '../engine/engine_receipt_writer.dart';
import '../feature_flags/feature_flag.dart';
import '../feature_flags/feature_flag_config.dart';
import '../models/generated_file.dart';
import '../plugins/provider/provider_receipt.dart';
import '../plugins/provider/provider_verifier.dart';
import '../plugins/repository/plan/repository_emission_plan.dart';
import '../plugins/repository/repository_plugin.dart';
import '../plugins/usecase/usecase_expectation_post_pass.dart';
import '../utils/entity_field_resolver.dart';
import '../utils/string_utils.dart';
import '../utils/framework_export_surface.dart';

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
    'test', // value objects generate no usecases, so there are no usecase tests to emit
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

  /// Spec 1002: plugins the engine preset hard-excludes — every
  /// Flutter-importing presentation plugin. The engine slice is pure
  /// Dart (no view, no presenter, no controller, no state, no route, no
  /// shadcn), so these are dropped with a notice even when a config
  /// default or an alias pulled them into the plan.
  static const Set<String> _engineExcludedPluginIds = {
    'view',
    'presenter',
    'controller',
    'state',
    'route',
    'shadcn',
  };

  /// Spec 1002: the default method set for `zfa make engine <Entity>`
  /// when neither `--methods` nor a `--from-json` config supplies one.
  static const List<String> _engineDefaultMethods = [
    'get',
    'getList',
    'create',
    'update',
    'delete',
  ];

  final PluginRegistry registry;
  late final PluginManager manager;

  MakeCommand(this.registry) {
    argParser.addFlag(
      'ui',
      negatable: false,
      help:
          'Scaffold a composite UI component (spec 024): node entity + '
          'renderer extension + schema registration',
    );
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
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit the resolved plan — including the repository emission plan '
          '(spec 0973) — as a single JSON object; implies --format json for '
          'plan/explain output',
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
      'sqlite',
      negatable: false,
      help: 'Generate a SQLite-backed local data source (package:sqlite3)',
    );
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
    argParser.addFlag(
      'skin',
      negatable: false,
      help:
          'Generate views with the runtime skin-contract auditor wrap '
          '(issues #1102/#1166); the auditor kit file is emitted when '
          'missing',
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
      'json',
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
      'sqlite',
      'sync',
      'bidirectional',
      'sync-batch-size',
      'sync-max-retries',
      'route',
      'mock',
      'test',
      'append',
      'xray',
      'skin',
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

  /// Test seam: constructs a MakeCommand bound to a temp project root for
  /// the `--ui` composite flow (spec 024).
  @visibleForTesting
  factory MakeCommand.forTesting({required String projectRoot}) {
    final command = MakeCommand(PluginRegistry.instance);
    command._uiProjectRootOverride = projectRoot;
    return command;
  }

  String? _uiProjectRootOverride;

  /// Runs the `zfa make <Name> --ui` composite scaffolding flow (spec 024
  /// FR-002). Exposed for in-process tests; the CLI path reaches it via
  /// the `--ui` flag.
  @visibleForTesting
  Future<void> runForUi(String name) async {
    await _scaffoldComposite(name);
  }

  Future<void> _scaffoldComposite(String name) async {
    final projectRoot = _uiProjectRootOverride ?? Directory.current.path;
    try {
      final registry = NodeRegistry.load(projectRoot: projectRoot);
      final result = await CompositeScaffolder().scaffold(
        name,
        projectRoot: projectRoot,
        registry: registry,
        force: argResults?['force'] == true,
      );
      for (final file in result.writtenFiles) {
        print('  ✨ Created: $file');
      }
      print('✅ Composite "$name" is now a first-class UI vocabulary entry.');
      print('   Re-run `zfa ui schema` to include it in the export.');
    } on CompositeScaffoldException catch (e) {
      print('❌ $e');
      exitCode = 1;
    }
  }

  @override
  Future<void> run() async {
    final jsonConfig = await _loadJsonConfig();
    final rest = argResults!.rest;

    // Spec 024 FR-002: `zfa make <Name> --ui` scaffolds a composite UI
    // component — intercepted before the entity pipeline (composites are
    // vocabulary entries, not entities).
    if (argResults?['ui'] == true) {
      if (rest.isEmpty) {
        print('❌ Usage: zfa make <Name> --ui');
        exitCode = 64;
        return;
      }
      await _scaffoldComposite(rest.first);
      return;
    }

    if (rest.isEmpty && jsonConfig == null) {
      print('❌ Usage: zfa make <Name> <plugin1> <plugin2> ... [options]');
      print('Example: zfa make User route di');
      exit(1);
    }

    // ── Spec 1002: the `engine` mode token ────────────────────────────
    // `zfa make engine <Entity> [plugins...] [options]` runs the engine
    // preset in one shot: entity create (auto) → the engine plugin chain
    // (usecase, service, provider, repository, datasource, mock, di) →
    // mock certification → engine check → engine.receipt.json. The token
    // is the exact lowercase `engine` in the entity position; an entity
    // literally named `Engine` (PascalCase) still routes through the
    // classic grammar, so no existing invocation changes meaning.
    final engineMode = rest.isNotEmpty && rest.first == 'engine';
    if (engineMode && rest.length < 2) {
      print('❌ Usage: zfa make engine <Entity> [options]');
      print(
        'Example: zfa make engine Login '
        '--methods=get,getList,create,update,delete',
      );
      exitCode = 64;
      return;
    }
    if (engineMode) {
      String? explicitPreset;
      if (argResults?.wasParsed('preset') == true) {
        explicitPreset = argResults?['preset'] as String?;
      }
      if (explicitPreset != null && explicitPreset != 'engine') {
        print(
          '❌ --preset=$explicitPreset conflicts with the `engine` mode '
          'token (the engine preset is implied by the token itself).',
        );
        exitCode = 64;
        return;
      }
    }

    final entityName = engineMode
        ? rest[1]
        : (rest.isNotEmpty
              ? rest.first
              : (jsonConfig?['name']?.toString() ?? ''));
    if (entityName.isEmpty) {
      print('❌ Missing required feature/entity name.');
      exit(1);
    }

    // ── Spec 030 (FR-004, US2.AC2): a feature disabled via the `features:`
    // section of .zfa.json generates NOTHING — the run is skipped before
    // planning and before the entity-exists guard, so a disabled slice
    // leaves no trace in the build output (SC-001). Name mapping is by
    // convention: `ProAnalytics` slice <-> `pro-analytics` flag.
    final flagSkipReason = _disabledFeatureSkipReason(entityName);
    if (flagSkipReason != null) {
      print('⏭ Skipped: $flagSkipReason');
      return;
    }

    final explicitPluginIds = engineMode
        ? rest.skip(2).toList()
        : rest.skip(1).toList();
    final normalizedOptions = _normalizedOptions(jsonConfig);
    if (engineMode) {
      // The engine preset is implied by the mode token; the plan resolves
      // through the same PresetRegistry entry `--preset=engine` uses.
      normalizedOptions['preset'] = 'engine';
      // Spec 1002 default method set — only when neither the CLI flag
      // nor a --from-json config supplied one.
      if (!argResults!.wasParsed('methods') &&
          !normalizedOptions.containsKey('methods')) {
        normalizedOptions['methods'] = List<String>.from(_engineDefaultMethods);
      }
    }
    final plan = manager.resolvePlan(
      name: entityName,
      explicitPluginIds: explicitPluginIds,
      argResults: argResults!,
      options: normalizedOptions,
    );

    final planOnly =
        argResults?['plan'] == true || argResults?['explain'] == true;

    // #496: fail fast when the entity source file is missing (and --no-entity
    // is not set). Without this guard `zfa make <NonExistentEntity>` resolves a
    // plan, prints it, and silently proceeds with a default `id` field,
    // generating broken code for an entity that was never created. This must
    // run before the `--plan`/`--explain` early return below so planning also
    // fails fast. Only the MISSING-FILE case fails here — when the file EXISTS
    // but has no id field, the no-id handling further down (#307/#508/#514)
    // still applies unchanged.
    //
    // Spec 1002 exception: the engine chain STARTS with `entity create` — a
    // missing entity is generated (with a minimal `id: String` identity)
    // instead of rejected, so `zfa make engine Login` is a true one-shot. In
    // plan-only mode nothing is written, so the guard is simply skipped.
    if (argResults?['no-entity'] != true &&
        !EntityFieldResolver.entityFileExists(
          entityName: entityName,
          projectRoot: manager.projectRoot,
        )) {
      if (engineMode && planOnly) {
        // Planning never writes files: the engine plan can be inspected
        // before the entity exists (the generation path auto-creates it).
      } else if (engineMode) {
        await _createEngineEntity(entityName);
      } else {
        throw MakeCommandException(
          'Cannot run `zfa make` for "$entityName": no entity source file '
          'was found. Create the entity first with '
          '`zfa entity create -n $entityName` (or pass --no-entity if you '
          'intentionally want to generate code without a backing entity).',
        );
      }
    }

    if (planOnly) {
      _printPlan(
        plan,
        emission: _repositoryEmissionSection(plan, normalizedOptions),
      );
      return;
    }

    final activePlugins = plan.activePlugins;
    if (activePlugins.isEmpty) {
      print('❌ No active plugins to run.');
      return;
    }

    // Spec 1002: the engine slice is pure Dart — drop every
    // Flutter-importing presentation plugin with a notice, even when a
    // config default, an alias, or a positional extra pulled it in.
    if (engineMode) {
      final flutterPlugins =
          activePlugins
              .where((plugin) => _engineExcludedPluginIds.contains(plugin.id))
              .map((plugin) => plugin.id)
              .toList()
            ..sort();
      if (flutterPlugins.isNotEmpty) {
        print(
          'ℹ️  engine preset: dropping Flutter-importing plugins '
          '(${flutterPlugins.join(", ")}) — the engine slice stays pure '
          'Dart (spec 1002).',
        );
        activePlugins.removeWhere(
          (plugin) => _engineExcludedPluginIds.contains(plugin.id),
        );
      }
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
          final activeIdDependent = activePlugins
              .where((plugin) => _idDependentPlugins.contains(plugin.id))
              .toList();

          if (activeIdDependent.isNotEmpty) {
            // #514: an id-dependent plugin may be active only because a config
            // default enabled it (e.g. `usecase` is on by default in
            // apps/zikzak_demo) — not because the user asked for it. When the
            // user's explicit intent is id-neutral (`--test` / `--mock`) and
            // they did NOT explicitly request any id-dependent plugin
            // (no --methods / --usecase / --service / --with / positional),
            // drop the implied id-dependent plugins so the id-neutral
            // regeneration proceeds — mirroring the value-object drop above.
            // An id-dependent plugin the user explicitly requested keeps the
            // loud failure armed (e.g. `--test --methods=get` must still fail).
            final explicitIdDependent = _explicitIdDependentPluginIds(
              explicitPluginIds,
              normalizedOptions,
            );
            final impliedIdDependent = activeIdDependent
                .where((p) => !explicitIdDependent.contains(p.id))
                .toList();
            final idNeutralIntent =
                argResults!['test'] == true || argResults!['mock'] == true;

            if (impliedIdDependent.isNotEmpty &&
                explicitIdDependent.isEmpty &&
                idNeutralIntent) {
              final dropped = impliedIdDependent.map((p) => p.id).toList()
                ..sort();
              print(
                'ℹ️  "$entityName" has no id field — dropping id-dependent '
                'plugins implied by config defaults (${dropped.join(', ')}) '
                'so id-neutral (--test/--mock) regeneration can proceed.',
              );
              activePlugins.removeWhere((p) => impliedIdDependent.contains(p));
            } else {
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

      // Spec #972 FR-4 — same-plan interface-expectation post-pass.
      //
      // When the usecase plugin's source-interface guard failed open
      // (the interface was absent at generation time), the run recorded
      // what it ASSUMED the same plan would declare. Verify that now,
      // against the tree as committed: if the responsible plugin
      // (repository/service) did not declare the requested methods, the
      // generated usecases cannot compile — fail the run loudly with the
      // exact repair command instead of letting `zfa build` break later.
      if (!isDryRun && !isRevert) {
        final failures = await _verifyUsecaseExpectations(
          context,
          activePlugins,
        );
        if (failures.isNotEmpty) {
          for (final failure in failures) {
            print(failure.detail);
            print('   ${failure.fixLine}');
          }
          exitCode = 1;
          return;
        }
      }

      // Spec #979 (orders 2 + 4) — provider post-pass hook: persist the
      // deterministic provider receipt and run the stub-escape +
      // conformance gates. Fresh stubs are RECORDED and NAMED (stub-first
      // semantics preserved — the TDD flow fills them); a provider the run
      // did not rewrite whose stubs survived, or a missing interface
      // method, fails the run with --> fix: lines (a stub is not allowed
      // to hide, and a hollow provider must not reach production).
      if (!isDryRun && !isRevert) {
        final providerGateFailed = await _providerPostPass(
          entityName,
          files,
          activePlugins,
        );
        if (providerGateFailed) {
          exitCode = 1;
          return;
        }
      }

      _logSummary(files, context.core.verbose, plan: plan);
      // Spec 1002: the engine tail — mock certification, engine check,
      // and the auto-receipt — runs after the generation transaction
      // committed, so the checker reads the real on-disk tree.
      var engineCheckPassed = true;
      if (engineMode && !planOnly && !isRevert && !isDryRun) {
        engineCheckPassed = await _runEngineTail(
          entityName: entityName,
          files: files,
          context: context,
        );
      }
      if (!engineCheckPassed) {
        // The generation succeeded but the engine check found dangling
        // wiring — report failure to automation (the receipt records the
        // findings) and skip the success branding below.
        return;
      }
    } catch (e) {
      print('❌ Generation failed: $e');
      if (context.core.verbose) {
        rethrow;
      }
      exit(1);
    }

    // 5b. Apply Zuraffa branding (spec 053): icons, assets, README.
    //     Skipped in plan/explain mode; idempotent so safe to call on
    //     any project regardless of whether setup already ran branding.
    if (argResults?['plan'] != true &&
        argResults?['explain'] != true &&
        argResults?['revert'] != true) {
      final verbose = argResults!['verbose'] as bool? ?? false;
      final dryRun = argResults!['dry-run'] as bool? ?? false;
      final isFlutter = context.data['isFlutter'] as bool? ?? true;
      final brandingWriter = BrandingWriter(zuraffaRoot: findZuraffaRoot());
      if (isFlutter) {
        await brandingWriter.writeFlutterBranding(
          projectRoot: manager.projectRoot,
          dryRun: dryRun,
          verbose: verbose,
        );
      } else {
        await brandingWriter.writeDartBranding(
          projectRoot: manager.projectRoot,
          dryRun: dryRun,
          verbose: verbose,
        );
      }
    }

    if (argResults?['format'] != 'json') {
      print('✅ Done.');
    }
  }

  /// Spec #972 FR-4: runs the usecase interface-expectation post-pass
  /// for the expectations this plan recorded (see
  /// [UseCasePlugin.generateWithContext]). Failures mean a same-plan
  /// misfire: the generated usecases call methods the responsible plugin
  /// never declared.
  Future<List<UsecaseExpectationFailure>> _verifyUsecaseExpectations(
    PluginContext context,
    List<ZuraffaPlugin> activePlugins,
  ) async {
    final expectations = expectationsFromContextData(context.data);
    if (expectations.isEmpty) return const [];
    return UsecaseExpectationPostPass().verify(
      projectRoot: manager.projectRoot,
      expectations: expectations,
      activePluginIds: activePlugins.map((p) => p.id).toSet(),
    );
  }

  /// Spec #979 (orders 2 + 4): the provider post-pass — receipt + gates.
  ///
  /// Returns true when the run must FAIL (committed stubs survived, or a
  /// conformance miss). Fresh stubs (the provider this run just wrote —
  /// stub-first semantics) are recorded in the deterministic receipt and
  /// named in the output, and do NOT fail the run: stubs are allowed to
  /// exist, never to hide.
  Future<bool> _providerPostPass(
    String entityName,
    List<GeneratedFile> files,
    List<ZuraffaPlugin> activePlugins,
  ) async {
    if (!activePlugins.any((p) => p.id == 'provider')) return false;

    final entity = StringUtils.convertToPascalCase(entityName);
    final report = await const ProviderVerifier().verify(
      projectRoot: manager.projectRoot,
      entity: entity,
    );

    // The provider plugin declined to generate (e.g. no service named —
    // its own skip semantics, the #412 full-bundle shape): nothing was
    // committed, nothing to gate.
    if (report.providerFile == null) return false;

    final providerFile = report.providerFile!;
    final relative = _projectRelative(providerFile);

    // Did THIS run (re)write the provider? (make reports paths relative
    // to the project root, e.g. lib/src/data/providers/...)
    final runEntry = files.where((f) {
      final fRel = f.path.replaceAll('\\', '/');
      return fRel == relative ||
          fRel.endsWith('/$relative') ||
          providerFile.endsWith('/${fRel.split('/').last}') &&
              f.type == 'provider';
    }).toList();
    final fresh = runEntry.any(
      (f) =>
          f.action == 'created' ||
          f.action == 'overwritten' ||
          f.action == 'updated',
    );

    // Receipt: proof.v1 digests of the final bytes + the ledger data
    // (interface / methods / stub count) — best-effort by design.
    try {
      await ProviderReceiptWriter().write(
        projectRoot: manager.projectRoot,
        entity: entity,
        files: runEntry.isNotEmpty
            ? runEntry
            : [
                // Committed, untouched by this run — digest the current
                // bytes so the receipt stays truthful.
                GeneratedFile(
                  path: providerFile,
                  type: 'provider',
                  action: 'updated',
                ),
              ],
        interface: report.interface,
        methods: report.methods,
        stubCount: report.stubCount,
        input: {'name': entity, 'via': 'zfa make $entityName'},
      );
    } catch (e) {
      print('⚠️  Provider receipt not written: $e');
    }

    // ── Conformance gate (order 4): always a failure ───────────────────
    final conformance = report.findings
        .where(
          (f) =>
              f.kind == ProviderVerifyFinding.kindMissingMethod ||
              f.kind == ProviderVerifyFinding.kindMissingService,
        )
        .toList();
    if (conformance.isNotEmpty) {
      print(
        '❌ Provider conformance failed for "$entity" — '
        '${conformance.length} finding(s):',
      );
      for (final finding in conformance) {
        print('  [${finding.kind}] ${finding.detail}');
        print('    ${finding.fix}');
      }
      return true;
    }

    // ── Stub-escape gate (order 2) ────────────────────────────────────
    final stubs = report.stubFindings.toList();
    if (stubs.isEmpty) return false;

    if (fresh) {
      // Fresh stubs are the intended stub-first output: NAME them and
      // record them (the receipt above carries the count), do not fail.
      print(
        'ℹ️  Provider $relative generated stub-first: '
        '${stubs.length} method(s) still throw UnimplementedError '
        '(recorded in .zfa/receipts/provider-$entity.json — the TDD '
        'flow fills them):',
      );
      print('    ${stubs.map((s) => s.method).join(', ')}');
      print(
        '    --> fix: `zfa provider verify $entity` fails until every '
        'stub is filled.',
      );
      return false;
    }

    print(
      '❌ Provider stub-escape: the committed provider for "$entity" '
      'still contains UnimplementedError method bodies — the skeleton '
      'survived a full make run (spec 979):',
    );
    for (final finding in stubs) {
      print('  [stub] ${finding.detail}');
      print('    ${finding.fix}');
    }
    return true;
  }

  String _projectRelative(String absolutePath) {
    final rel = path.isAbsolute(absolutePath)
        ? path.relative(absolutePath, from: manager.projectRoot)
        : absolutePath;
    return rel.replaceAll('\\', '/');
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

  /// Id-dependent plugin ids the user EXPLICITLY requested — as opposed to
  /// ones pulled in only by config defaults or presets. Drives the #514 no-id
  /// decision: an implied id-dependent plugin (e.g. `usecase` on by default in
  /// `apps/zikzak_demo`) can be dropped for id-neutral (`--test`/`--mock`)
  /// regeneration, but an explicitly-requested one cannot (it must keep the
  /// #307 loud failure armed).
  Set<String> _explicitIdDependentPluginIds(
    List<String> explicitPluginIds,
    Map<String, dynamic> normalizedOptions,
  ) {
    final explicit = <String>{};
    final ar = argResults!;

    // Positional plugin args (e.g. `zfa make Foo usecase repository`).
    for (final id in explicitPluginIds) {
      if (_idDependentPlugins.contains(id)) explicit.add(id);
    }

    // `--with` (CLI flag or --from-json config key).
    final withIds = _splitListOption(
      ar.options.contains('with') ? ar['with'] : normalizedOptions['with'],
    );
    for (final id in withIds) {
      if (_idDependentPlugins.contains(id)) explicit.add(id);
    }

    // Plugin flags the user actually passed (`--usecase`, `--repository`, ...).
    // The argParser defaults every plugin flag to `true`, so we must consult
    // `wasParsed` — an untouched default must NOT count as explicit.
    for (final id in _idDependentPlugins) {
      if (ar.options.contains(id) && ar.wasParsed(id) && ar[id] == true) {
        explicit.add(id);
      }
    }

    // `--methods` implies the usecase plugin (PlanResolver._hasEntityMethods).
    final methods = _splitListOption(
      ar.options.contains('methods')
          ? ar['methods']
          : normalizedOptions['methods'],
    );
    if (ar.wasParsed('methods') && methods.isNotEmpty) {
      explicit.add('usecase');
    }

    // `--service` implies usecase + service + provider.
    final service = ar.options.contains('service')
        ? ar['service']
        : normalizedOptions['service'];
    if (ar.wasParsed('service') &&
        (service == true || (service is String && service.isNotEmpty))) {
      explicit
        ..add('usecase')
        ..add('service')
        ..add('provider');
    }

    return explicit;
  }

  static List<String> _splitListOption(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .expand((e) => e.toString().split(','))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return [value.toString()];
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

  /// Spec 0973: resolves the repository plugin's emission plan for this
  /// run — what will be emitted and why (which variants, which flags
  /// triggered them) — WITHOUT running generation or changing activation.
  /// Null when the repository plugin is not part of the plan.
  RepositoryEmissionPlan? _repositoryEmissionSection(
    dynamic plan,
    Map<String, dynamic> normalizedOptions,
  ) {
    final argResults = this.argResults;
    if (argResults == null) return null;
    try {
      final repositoryPlugins = plan.activePlugins
          .whereType<RepositoryPlugin>()
          .toList();
      if (repositoryPlugins.isEmpty) return null;

      // Build the same context generation would build (schema defaults,
      // activation sync, normalized options) so the explanation can never
      // drift from what generation actually does.
      final previewContext = manager.buildContext(
        name: plan.name as String,
        argResults: argResults,
        activePlugins: plan.activePlugins,
        overrideOutputDir: fixedOutputDir,
      );
      previewContext.data.addAll(normalizedOptions);
      return repositoryPlugins.first.explainEmission(previewContext);
    } catch (_) {
      // Explaining must never fail the run — omit the section instead.
      return null;
    }
  }

  void _printPlan(dynamic plan, {RepositoryEmissionPlan? emission}) {
    final jsonMode =
        argResults?['format'] == 'json' || argResults?['json'] == true;
    if (jsonMode) {
      print(
        jsonEncode({
          'success': true,
          'plan': plan.toJson(),
          if (emission != null) 'emission': emission.toJson(),
        }),
      );
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
    if (emission != null) {
      print(emission.renderText());
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

  /// Spec 1002: engine-chain step 1 — `entity create`. Generates the
  /// entity via the same zorphy `EntityCreator` path `zfa entity create`
  /// uses, with a minimal `id: String` identity so the id-dependent
  /// generators (repository/usecase/datasource/mock signatures, seeded
  /// mock data) have a real identity to reference.
  Future<void> _createEngineEntity(String name) async {
    // Issue #942 preflight (same guard as `zfa entity create`): an entity
    // name colliding with a zuraffa framework export makes every
    // generated file fail with ambiguous_import errors.
    final surface = FrameworkExportSurface.tryResolve(
      projectRoot: manager.projectRoot,
    );
    final collisionSource = surface?.lookup(name);
    if (collisionSource != null) {
      throw MakeCommandException(
        'Cannot create entity "$name": the name collides with the zuraffa '
        'framework export "$name" ($collisionSource).\n'
        '--> fix: rename the entity, e.g. `zfa make engine ${name}Entity`.',
      );
    }

    final outputDir = ZfaConfig.fixedEntityOutput;
    final config = EntityConfig(
      name: name,
      outputDir: outputDir,
      fields: const [FieldDefinition(name: 'id', type: 'String')],
      generateJson: true,
      generateCompareTo: true,
    );
    final creator = EntityCreator(baseOutputDir: outputDir);
    final result = await creator.create(config);
    if (!result.isSuccess) {
      throw MakeCommandException(
        'Engine chain step `entity create` failed for "$name": '
        '${result.error ?? 'unknown zorphy error'}',
      );
    }
    print('✨ Engine chain [entity create]: ${result.filePath}');
  }

  /// Spec 1002: the engine tail — mock certification (per-method),
  /// `engine check` (getIt resolution + purity scan), and the
  /// `engine.receipt.json` auto-receipt. Returns true when the engine
  /// check passed.
  Future<bool> _runEngineTail({
    required String entityName,
    required List<GeneratedFile> files,
    required PluginContext context,
  }) async {
    final projectRoot = manager.projectRoot;
    final methods =
        (context.data['methods'] as List?)?.cast<String>() ?? const <String>[];
    final format = (argResults?['format'] as String?) ?? 'text';

    final checkResult = await EngineChecker.check(
      entity: entityName,
      projectRoot: projectRoot,
      methods: methods,
    );

    final slice = EngineSlicePaths(
      entity: entityName,
      projectRoot: projectRoot,
    );
    final diFiles = slice
        .entityDiFiles()
        .map((file) => p.relative(file.path, from: projectRoot))
        .toList();

    final writer = EngineReceiptWriter(projectRoot: projectRoot);
    final receiptFile = await writer.write(
      command: 'zfa make engine $entityName',
      entityName: entityName,
      entityPath: slice.entityFile,
      methods: methods,
      mockCertified: checkResult.mockCertification?.methods ?? const {},
      mockDatasourcePath: checkResult.mockCertification?.mockDatasourcePath,
      mockDataPath: checkResult.mockCertification?.mockDataPath,
      diFiles: diFiles,
      getItTypes: checkResult.resolvedTypes,
      engineCheckPassed: checkResult.passed,
      engineCheckFailures: checkResult.failures,
      generatedFiles: files.map((file) => file.path).toList(),
      // Spec 1098: attribute the receipt to the active feature contract
      // when one is in play (grouped copy lands under .zfa/receipts/<id>/).
      featureId: context.core.feature?.id,
    );
    final receiptPath = p.relative(receiptFile.path, from: projectRoot);

    if (format == 'json') {
      print(
        jsonEncode({
          'engine_receipt': receiptPath,
          'engine_check': {
            'passed': checkResult.passed,
            'getit_types': checkResult.resolutions.length,
            'getit_types_resolved': checkResult.resolvedTypes.length,
            'mock_certified': checkResult.mockCertification?.certified,
            'failures': [
              for (final failure in checkResult.failures) failure.toJson(),
            ],
          },
        }),
      );
    } else {
      print('\n🔍 Engine check: $entityName');
      final certification = checkResult.mockCertification;
      if (certification != null) {
        for (final entry in certification.methods.entries) {
          print(
            '  ${entry.value ? "✅" : "❌"} mock ${entry.key} '
            '${entry.value ? "certified" : "uncertified"}',
          );
        }
      }
      for (final resolution in checkResult.resolutions) {
        final target =
            resolution.diRegistrationFile ?? resolution.declaringFile;
        print(
          '  ${resolution.resolved ? "✅" : "❌"} '
          'getIt<${resolution.typeName}> (${target ?? "dangling"})',
        );
      }
      print('🧾 Engine receipt: $receiptPath');
    }

    if (checkResult.passed) {
      if (format != 'json') {
        print(
          '✅ Engine check passed for "$entityName" '
          '(${checkResult.resolvedTypes.length} getIt references resolved).',
        );
      }
      return true;
    }

    if (format != 'json') {
      print(
        '❌ Engine check failed for "$entityName" '
        '(${checkResult.failures.length} finding(s)):',
      );
      for (final failure in checkResult.failures) {
        print('❌ ${failure.message}');
      }
    }
    exitCode = 1;
    return false;
  }

  /// Returns the skip reason when [entityName] normalizes to a feature
  /// disabled in .zfa.json's `features:` section, or null when generation
  /// should proceed (no flags declared, feature enabled/unknown).
  String? _disabledFeatureSkipReason(String entityName) {
    final FeatureFlagConfig flagConfig;
    try {
      flagConfig = FeatureFlagConfig.load(projectRoot: manager.projectRoot);
    } on FeatureConfigException catch (e) {
      throw MakeCommandException(e.message);
    }
    if (flagConfig.isEmpty) return null;

    final flagName = pascalToKebab(entityName);
    final resolved = flagConfig.resolve();
    if (resolved.disabled.contains(flagName)) {
      return 'feature "$flagName" is disabled in .zfa.json — no code '
          'generated for $entityName (enable it with '
          '`zfa feature enable $flagName`)';
    }
    return null;
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
