import 'dart:io';

import '../../../core/plugin_system/capability.dart';
import '../di_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import 'di_receipt_writer.dart';

class CreateDiCapability implements ZuraffaCapability {
  final DiPlugin plugin;

  /// Project root the standalone receipt (`.zfa/receipts/`, spec 0974)
  /// resolves from. Defaults to the current working directory — the CLI
  /// contract. Injectable so tests can point at a temp fixture.
  final String? projectRoot;

  CreateDiCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'create';

  @override
  String get description => 'Create DI registrations';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },

      'domain': {
        'type': 'string',
        'description': 'Domain name for the usecase/entity',
      },
      'service': {
        'type': 'string',
        'description': 'Service name for custom usecases',
      },
      'repo': {
        'type': 'string',
        'description': 'Repository name for custom usecases',
      },
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of entity methods to wire '
            '(get,create,update,delete,list,watch,getList,watchList). '
            'Defaults to ["get", "update"] for entity-based generation, '
            'matching `zfa usecase create <Entity>`.',
      },
      'usecases': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of usecases to orchestrate (enables orchestrator DI)',
      },
      'noEntity': {
        'type': 'boolean',
        'description':
            'Treat as a custom (non-entity) usecase — emits a single '
            '<name>_usecase_di.dart referencing <Name>UseCase '
            '(for hand-written usecases).',
        'default': false,
      },
      'useMock': {
        'type': 'boolean',
        'description': 'Use mock implementation for datasources',
        'default': false,
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
    final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

    // Spec 0974 (issue #974, order 3): the standalone path ships proof —
    // a `di-<target>` receipt binding the written registrations and the
    // DI index hashes, so `zfa proof check` covers `zfa di create` runs
    // exactly like `zfa make` runs (issue #807).
    final dryRun = args['dryRun'] == true;
    final revert = args['revert'] == true;
    if (!dryRun &&
        !revert &&
        DiReceiptWriter.hasWritableOutput(files)) {
      await DiReceiptWriter(
        projectRoot: projectRoot ?? Directory.current.path,
      ).writeReceipt(
        capability: 'create',
        target: args['name']?.toString() ?? '',
        args: args,
        files: files,
      );
    }

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final domain = args['domain']?.toString();
    final service = args['service']?.toString();
    final repo = args['repo']?.toString();
    final useMock = args['useMock'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final revert = args['revert'] ?? false;

    // #410: `zfa di create <Entity>` must wire the per-method usecases that
    // `zfa usecase create <Entity>` actually emits (GetXUseCase /
    // UpdateXUseCase / …), NOT a non-existent `<entity>_usecase.dart` +
    // `<Entity>UseCase`. Previously this capability built a GeneratorConfig
    // with no `methods`, so `isEntityBased` was false and the DI dispatcher
    // fell into `_generateCustomUseCaseDI`, emitting
    // `my_entity_usecase_di.dart` importing `my_entity_usecase.dart` and
    // referencing `MyEntityUseCase` — neither of which the usecase plugin
    // ever generates for entity-based flows, producing ~100
    // `uri_does_not_exist` / `non_type_as_type_argument` /
    // `undefined_function` errors under `dart analyze`.
    //
    // Mirror `CreateUseCaseCapability._generateFiles`: when none of the
    // custom-usecase signals are present (repo/service/usecases/domain/
    // noEntity), default `methods` to ['get', 'update'] — the exact default
    // `zfa usecase create <Entity>` uses. (The orchestrator `make` path uses
    // ['get','update','toggle'] — see usecase_plugin #284 — but that path
    // also generates its own matching usecases, so the two stay in sync.)
    // This routes the DI dispatcher to `_generateEntityUseCaseDIFiles`,
    // emitting per-method DI files (`get_<entity>_usecase_di.dart`,
    // `update_<entity>_usecase_di.dart`) that import the real usecase files
    // and reference the real usecase classes. The custom path
    // (`_generateCustomUseCaseDI`) is preserved for genuine hand-written
    // single usecases via `--no-entity`/`--repo`/`--service`/`--domain`/
    // `--usecases`.
    final methods =
        (args['methods'] as List<dynamic>?)?.cast<String>() ?? const [];
    final usecases =
        (args['usecases'] as List<dynamic>?)?.cast<String>() ?? const [];
    final noEntity = args['noEntity'] == true || args['no-entity'] == true;

    final isCustomUseCase =
        repo != null ||
        service != null ||
        usecases.isNotEmpty ||
        domain != null ||
        noEntity;

    final effectiveMethods = (methods.isEmpty && !isCustomUseCase)
        ? const ['get', 'update']
        : methods;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      domain: domain,
      service: service,
      repo: repo,
      methods: effectiveMethods,
      usecases: usecases,
      noEntity: noEntity,
      generateDi: true,
      useMockInDi: useMock,
      generateUseCase: true,
      generateData: repo != null || service != null,
      generateRepository: repo != null,
      generateDataSource: repo != null,
      generateService: service != null,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      revert: revert,
    );

    return await plugin.generate(config);
  }
}
