import 'dart:io';
import 'package:path/path.dart' as path;
import '../../../core/plugin_system/capability.dart';
import '../../../domain/entities/feature_contract/feature_contract.dart';
import '../../../domain/entities/feature_contract/feature_contract_registry.dart';
import '../feature_plugin.dart';
import '../../../models/generated_file.dart';
import '../../../config/zfa_config.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../core/context/file_system.dart';
import '../../../utils/file_utils.dart';

class ScaffoldFeatureCapability implements ZuraffaCapability {
  final FeaturePlugin plugin;

  /// Project root override (spec 1098): defaults to [Directory.current]
  /// exactly as before; injectable so contract validation can run
  /// hermetically against an explicit root.
  final String? projectRoot;

  ScaffoldFeatureCapability(this.plugin, {this.projectRoot});

  String get _projectRoot => projectRoot ?? Directory.current.path;

  @override
  String get name => 'scaffold';

  @override
  String get description =>
      'Scaffold a full feature set (VPC, Repo, UseCase, etc.)';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the feature (e.g. UserProfile)',
      },
      'vpcs': {
        'type': 'boolean',
        'description': 'Generate View, Presenter, Controller, State',
      },
      'repository': {'type': 'boolean', 'description': 'Generate Repository'},
      'datasource': {
        'type': 'boolean',
        'description': 'Generate DataSource (Remote and/or Local)',
      },
      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
      },
      'mock': {'type': 'boolean', 'description': 'Generate Mock data'},
      'use-mock': {
        'type': 'boolean',
        'description': 'Use mock datasources in DI registration',
      },
      'di': {
        'type': 'boolean',
        'description': 'Generate Dependency Injection setup',
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable Caching (generates local + remote datasources)',
        'default': false,
      },
      'use-service': {
        'type': 'boolean',
        'description':
            'Use service and provider instead of repository and datasource',
        'default': false,
      },
      'route': {
        'type': 'boolean',
        'description': 'Generate Routing definitions',
      },
      'test': {'type': 'boolean', 'description': 'Generate Tests'},
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of custom usecases to generate',
        'default': [],
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of entity methods to generate',
        'default': ['get', 'update', 'toggle'],
      },
      'id-field': {
        'type': 'string',
        'description': 'Name of the ID field',
        'default': 'id',
      },
      'id-field-type': {
        'type': 'string',
        'description': 'Type of the ID field',
        'default': 'String',
      },
      'query-field': {
        'type': 'string',
        'description': 'Name of the query field',
        'default': 'id',
      },
      'query-field-type': {
        'type': 'string',
        'description': 'Type of the query field',
        'default': 'String',
      },
      'outputDir': {
        'type': 'string',
        'description': 'Target directory for generation',
      },
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
      'revert': {
        'type': 'boolean',
        'description': 'Revert generated files',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    // Spec 1098 (gap 5): validate the raw string name against the known
    // feature contracts BEFORE planning. A project that declares no
    // contracts keeps the historical unvalidated behavior.
    final validation = _validateAgainstContracts(args);
    if (validation != null) {
      return EffectReport(
        planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        pluginId: plugin.id,
        capabilityName: name,
        args: args,
        changes: const [],
        isValid: false,
        message: validation,
      );
    }

    final files = await _generateFiles(args, dryRun: true);

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
    final validation = _validateAgainstContracts(args);
    if (validation != null) {
      return ExecutionResult(success: false, message: validation);
    }

    final files = await _generateFiles(args, dryRun: false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  /// Resolves [args] name against the project's declared feature
  /// contracts (specs/*/contract.yaml).
  ///
  /// Returns `null` when scaffolding may proceed; otherwise the failure
  /// message naming the unknown id and the known ids.
  String? _validateAgainstContracts(Map<String, dynamic> args) {
    final featureName = args['name'];
    if (featureName is! String || featureName.isEmpty) return null;

    final registry = FeatureContractRegistry.scanProject(_projectRoot);
    if (!registry.isNotEmpty) return null;
    if (registry.findById(featureName) != null) return null;

    final known = registry.knownIds.toList()..sort();
    return 'Unknown feature contract: "$featureName". '
        'Known contracts: ${known.isEmpty ? "(none)" : known.join(", ")}. '
        'Declare it at specs/<feature-id>/contract.yaml or use one of the '
        'known ids (spec 1098).';
  }

  /// The contract resolved for this scaffold run, or null when the
  /// project declares none matching the name (unscoped run).
  FeatureContract? _resolveContract(Map<String, dynamic> args) {
    final featureName = args['name'];
    if (featureName is! String || featureName.isEmpty) return null;
    final registry = FeatureContractRegistry.scanProject(_projectRoot);
    return registry.findById(featureName);
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final featureName = args['name'] as String;
    final zfaConfig = ZfaConfig.load();
    final projectRoot = _projectRoot;

    final manager = PluginManager(
      registry: PluginRegistry.instance,
      config: zfaConfig,
      projectRoot: projectRoot,
    );

    // Spec 1098 (materialization step 5): pass the typed contract — not
    // the raw string — into the context so plugins read the active
    // feature from context.core.feature.
    final activeContract = _resolveContract(args);

    final normalizedOptions = _normalizePlanOptions(args);
    final plan = manager.resolvePlan(
      name: featureName,
      options: normalizedOptions,
    );
    final activePlugins = plan.activePlugins;

    final context = manager.buildContext(
      name: featureName,
      argResults: null,
      activePlugins: activePlugins,
      overrideOutputDir: (args['outputDir'] as String?) ?? plugin.outputDir,
      overrideDryRun: dryRun,
      overrideForce: args['force'] == true,
      overrideVerbose: args['verbose'] == true,
      overrideRevert: args['revert'] == true,
      feature: activeContract,
    );

    context.data.addAll(plan.normalizedOptions);
    context.setShared(
      'normalizedOptions',
      Map<String, dynamic>.from(plan.normalizedOptions),
    );

    // Merge manual args into context data.
    args.forEach((key, value) {
      context.data[key] = value;
    });

    // Preserve normalized cache intent separately from plugin activation.
    context.data['cache'] = plan.normalizedOptions['cache'] == true;
    context.data['enableCache'] = plan.normalizedOptions['cache'] == true;

    // Ensure core flags are set
    context.data['dry-run'] = dryRun;
    context.data['force'] = args['force'] ?? false;
    context.data['verbose'] = args['verbose'] ?? false;
    context.data['revert'] = args['revert'] ?? false;

    // When reverting a full scaffold, we need to clean up ALL layers including:
    // - entities (and their generated files)
    // - usecases
    // - repositories
    // - datasources
    // - presentation layers
    // - DI, routes, mocks, tests
    if (args['revert'] == true) {
      final fileSystem = FileSystem.create(root: projectRoot);
      final files = <GeneratedFile>[];

      // For revert, we need to clean up the entity directory entirely
      // Pass empty methods to trigger full revert in usecase generator
      final entityDirPath = path.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        featureName.toLowerCase(),
      );
      if (fileSystem.existsSync(entityDirPath)) {
        // Delete the entire entity folder (entity + any .g.dart, .zorphy.dart files)
        final entityFiles = await fileSystem.list(entityDirPath);
        for (final entityFile in entityFiles) {
          if (entityFile.endsWith('.dart')) {
            files.add(
              await FileUtils.deleteFile(
                entityFile,
                'entity',
                dryRun: dryRun,
                verbose: args['verbose'] == true,
                fileSystem: fileSystem,
              ),
            );
          }
        }
        // Also delete the directory itself if empty
        final remainingFiles = await fileSystem.list(entityDirPath);
        if (remainingFiles.isEmpty ||
            remainingFiles.every((f) => f == '.gitkeep')) {
          await fileSystem.delete(entityDirPath);
        }
      }

      // Also clean up any leftover usecases from entity-based generation
      // These may have been created without going through the normal capability flow
      final usecaseDirPath = path.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'usecases',
        featureName.toLowerCase(),
      );
      if (fileSystem.existsSync(usecaseDirPath)) {
        final usecaseFiles = await fileSystem.list(usecaseDirPath);
        for (final usecaseFile in usecaseFiles) {
          if (usecaseFile.endsWith('.dart')) {
            files.add(
              await FileUtils.deleteFile(
                usecaseFile,
                'usecase',
                dryRun: dryRun,
                verbose: args['verbose'] == true,
                fileSystem: fileSystem,
              ),
            );
          }
        }
      }
    }

    return await manager.run(context, activePlugins);
  }

  Map<String, dynamic> _normalizePlanOptions(Map<String, dynamic> args) {
    final options = <String, dynamic>{
      'preset': 'feature',
      'cache': args['cache'] == true,
    };

    if (args['methods'] case final List<dynamic> methods) {
      options['methods'] = methods.cast<String>();
    }
    if (args['usecases'] case final List<dynamic> usecases) {
      options['usecases'] = usecases.cast<String>();
    }
    if (args['local'] == true) {
      options['local'] = true;
    }
    if (args['mock'] == true) {
      options['mock'] = true;
    }
    if (args['route'] == true) {
      options['route'] = true;
    }
    if (args['use-service'] == true) {
      options['use-service'] = true;
    }
    if (args['id-field'] case final String idField when idField.isNotEmpty) {
      options['id-field'] = idField;
    }
    if (args['id-field-type'] case final String idFieldType
        when idFieldType.isNotEmpty) {
      options['id-field-type'] = idFieldType;
    }
    if (args['query-field'] case final String queryField
        when queryField.isNotEmpty) {
      options['query-field'] = queryField;
    }
    if (args['query-field-type'] case final String queryFieldType
        when queryFieldType.isNotEmpty) {
      options['query-field-type'] = queryFieldType;
    }

    final excluded = <String>{'test'};
    if (args['repository'] == false) {
      excluded.add('repository');
    }
    if (args['datasource'] == false) {
      excluded.add('datasource');
    }
    if (args['vpcs'] == false) {
      excluded.addAll(['view', 'presenter', 'controller', 'state']);
    }
    if (args['di'] == false) {
      excluded.add('di');
    }
    if (args['test'] == true) {
      excluded.remove('test');
    }
    if (args['use-service'] == true) {
      excluded.addAll(['repository', 'datasource']);
    }
    if (excluded.isNotEmpty) {
      options['without'] = excluded.toList(growable: false);
    }

    return options;
  }
}
