import '../../../models/generator_config.dart';

/// Spec 0973 (issue #973) — resolved emission plan for the repository
/// plugin.
///
/// `zfa make --explain` / `--explain --json` surfaces WHAT the repository
/// plugin will emit and WHY — which variant was selected and which flags
/// triggered each decision — without running generation and without
/// changing PluginManager activation order. This kills the flag-maze
/// opacity for agents: intent and emission become diffable.
///
/// The planner is a pure function of [GeneratorConfig] plus one bit of
/// context the plugin reads at generation time
/// ([RepositoryEmissionPlanner.resolve]'s `datasourcePluginActive`), so
/// `--explain` output is deterministic (output-relative POSIX paths, no
/// timestamps) and snapshot-testable.

/// One emission decision (interface, implementation, datasource interface).
class RepositoryEmissionItem {
  /// Stable id: `interface`, `implementation`, `datasource_interface`.
  final String id;

  /// Whether the file will be emitted.
  final bool emit;

  /// Output-dir-relative POSIX path of the file.
  final String path;
  final String className;

  /// Interface method names (interface item only).
  final List<String>? methods;

  /// `simple` | `cached` | `synced` | `conflicted` (implementation only).
  final String? variant;

  /// The flags / rules that triggered this decision, in order.
  final List<String> triggeredBy;

  const RepositoryEmissionItem({
    required this.id,
    required this.emit,
    required this.path,
    required this.className,
    required this.triggeredBy,
    this.methods,
    this.variant,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'emit': emit,
    'path': path,
    'class': className,
    if (methods != null) 'methods': methods,
    if (variant != null) 'variant': variant,
    'triggered_by': triggeredBy,
  };
}

class RepositoryEmissionPlan {
  final String plugin;
  final String entity;

  /// False when the resolved flags cannot generate (e.g. --cache + --sync).
  final bool valid;
  final List<RepositoryEmissionItem> emissions;
  final List<String> warnings;

  const RepositoryEmissionPlan({
    this.plugin = 'repository',
    required this.entity,
    required this.valid,
    required this.emissions,
    required this.warnings,
  });

  Map<String, dynamic> toJson() => {
    'plugin': plugin,
    'entity': entity,
    'valid': valid,
    'emissions': emissions.map((e) => e.toJson()).toList(),
    'warnings': warnings,
  };

  /// Human-readable rendering used by `zfa make --explain` (text mode).
  String renderText() {
    final buffer = StringBuffer('Emission plan ($plugin):\n');
    for (final emission in emissions) {
      final verdict = emission.emit ? 'emit ' : 'skip';
      buffer.writeln(
        '  ${emission.id.padRight(20)} $verdict  ${emission.path} '
        '(${emission.className})',
      );
      if (emission.variant != null) {
        buffer.writeln('    variant: ${emission.variant}');
      }
      if (emission.methods != null && emission.methods!.isNotEmpty) {
        buffer.writeln('    methods: ${emission.methods!.join(', ')}');
      }
      for (final reason in emission.triggeredBy) {
        buffer.writeln('    why: $reason');
      }
    }
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    return buffer.toString().trimRight();
  }
}

class RepositoryEmissionPlanner {
  /// Verbs the interface generator's switch actually declares.
  static const _interfaceVerbs = {
    'get',
    'getList',
    'list',
    'create',
    'update',
    'toggle',
    'delete',
    'watch',
    'watchList',
  };

  const RepositoryEmissionPlanner();

  RepositoryEmissionPlan resolve(
    GeneratorConfig config, {
    required bool datasourcePluginActive,
  }) {
    final warnings = <String>[];

    // --cache + --sync: the implementation generator throws ArgumentError
    // before writing anything — the plan must say so, not silently pick a
    // side.
    final cacheAndSync = config.enableCache && config.enableSync;
    if (cacheAndSync) {
      warnings.add(
        '--cache and --sync are mutually exclusive: cache is remote-first, '
        'sync is local-first (generation would fail with ArgumentError)',
      );
    }

    // Interface emission — mirrors RepositoryPlugin.generate().
    final interfaceEmit =
        config.isEntityBased || (config.appendToExisting && config.repo != null);
    final interfaceTriggeredBy = <String>[];
    if (config.isEntityBased) {
      interfaceTriggeredBy.add(
        'entity-based generation (methods: ${config.methods.join(', ')})',
      );
    } else if (config.appendToExisting && config.repo != null) {
      interfaceTriggeredBy.add('--repo ${config.repo} with --append');
    }
    if (config.enableSync) {
      interfaceTriggeredBy.add(
        '--sync adds syncPending/pullRemote to the interface',
      );
    }

    // Implementation emission — mirrors RepositoryPlugin.generate() and the
    // generator's variant selection.
    final implEmit =
        (config.isEntityBased ||
            config.generateData ||
            config.generateDataSource ||
            config.appendToExisting) &&
        !config.hasService;
    final implTriggeredBy = <String>[];
    if (config.isEntityBased) {
      implTriggeredBy.add('entity-based generation emits the implementation');
    }
    if (config.generateData && !config.isEntityBased) {
      implTriggeredBy.add('--data');
    }
    if (config.generateDataSource && !config.isEntityBased) {
      implTriggeredBy.add('--datasource');
    }
    if (config.appendToExisting && !config.isEntityBased) {
      implTriggeredBy.add('--append');
    }

    String variant;
    if (cacheAndSync) {
      variant = 'conflicted';
      implTriggeredBy.add(
        '--cache and --sync both requested (mutually exclusive: cache is '
        'remote-first, sync is local-first)',
      );
    } else if (config.enableCache) {
      variant = 'cached';
      implTriggeredBy.add('--cache selects the cached (remote-first) variant');
    } else if (config.enableSync) {
      variant = 'synced';
      implTriggeredBy.add(
        '--sync selects the synced (local-first) variant',
      );
    } else {
      variant = 'simple';
    }
    if (config.hasService) {
      implTriggeredBy.add('skipped: --service / use-service mode emits a '
          'service repository instead');
    }

    // Datasource interface emission — mirrors the #406 block: the
    // repository plugin only emits it when the datasource plugin is NOT
    // active (the plugin emits it itself, avoiding a duplicate-write
    // conflict on the same file).
    final dsEmit =
        config.generateDataSource && !config.hasService &&
        !datasourcePluginActive;
    final dsTriggeredBy = <String>['--datasource requested'];
    dsTriggeredBy.add(
      datasourcePluginActive
          ? 'skipped: the datasource plugin is active and emits it itself'
          : 'emitted by the repository plugin because the datasource plugin '
              'is NOT active',
    );

    return RepositoryEmissionPlan(
      entity: config.name,
      valid: warnings.isEmpty,
      emissions: [
        RepositoryEmissionItem(
          id: 'interface',
          emit: interfaceEmit,
          path: 'domain/repositories/${config.nameSnake}_repository.dart',
          className: '${config.name}Repository',
          methods: interfaceEmit ? _interfaceMethodNames(config) : null,
          triggeredBy: interfaceTriggeredBy,
        ),
        RepositoryEmissionItem(
          id: 'implementation',
          emit: implEmit,
          path:
              'data/repositories/data_${config.nameSnake}_repository.dart',
          className: 'Data${config.name}Repository',
          variant: variant,
          triggeredBy: implTriggeredBy,
        ),
        RepositoryEmissionItem(
          id: 'datasource_interface',
          emit: dsEmit,
          path: 'data/datasources/${config.nameSnake}/'
              '${config.nameSnake}_datasource.dart',
          className: '${config.name}DataSource',
          triggeredBy: dsTriggeredBy,
        ),
      ],
      warnings: warnings,
    );
  }

  /// Method names the interface generator would declare (known verbs only —
  /// unknown --methods values contribute nothing to the interface, which
  /// the generation-time conformance gate flags on the impl side).
  List<String> _interfaceMethodNames(GeneratorConfig config) {
    final names = <String>[];
    if (config.isCustomUseCase && config.appendToExisting) {
      names.add(config.getRepoMethodName());
    }
    if (config.generateInit) {
      names.addAll(const ['isInitialized', 'initialize', 'dispose']);
    }
    names.addAll(config.methods.where(_interfaceVerbs.contains));
    if (config.enableSync) {
      names.addAll(const ['syncPending', 'pullRemote']);
    }
    return names;
  }
}
