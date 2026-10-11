import 'package:path/path.dart' as p;

import '../../../core/plugin_system/capability.dart';
import '../datasource_explain.dart';
import '../datasource_plugin.dart';
import '../datasource_receipt.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateDataSourceCapability implements ZuraffaCapability {
  final DataSourcePlugin plugin;

  /// Project root the deterministic receipt (spec #1131 order 2) and the
  /// entity source lookups resolve from. The CLI leaves it null and the
  /// root is derived from the plugin outputDir (`<outputDir>/../..`);
  /// tests inject a temp fixture so receipts land in the fixture's own
  /// `.zfa/`.
  final String? projectRoot;

  CreateDataSourceCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Data Source';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the data source'},

      'local': {
        'type': 'boolean',
        'description': 'Generate local data source (instead of remote)',
        'default': false,
      },
      'remote': {
        'type': 'boolean',
        'description': 'Generate remote data source (and API integration)',
        'default': true,
      },
      'cache': {
        'type': 'boolean',
        'description': 'Enable caching',
        'default': false,
      },
      'useService': {
        'type': 'boolean',
        'description':
            'Request a service instead of a datasource. Supersedes '
            'datasource generation: the request is declined with an '
            'honest skip reason (spec #977).',
        'default': false,
      },
      'id-field': {
        'type': 'string',
        'description':
            'Entity id field name the datasource resolves (#294 audit '
            'trail). Defaults to `id`.',
        'default': 'id',
      },
      'id-field-type': {
        'type': 'string',
        'description': 'Entity id field type.',
        'default': 'String',
      },
      'query-field': {
        'type': 'string',
        'description': 'Entity query field name. Defaults to `id`.',
        'default': 'id',
      },
      'query-field-type': {
        'type': 'string',
        'description': 'Entity query field type.',
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
      // Spec #1131 order 3: `--explain` — print the datasource plan (the
      // types generated, the entity field -> method mapping and the
      // interface shape) INSTEAD of generating anything. Read-only.
      'explain': {
        'type': 'boolean',
        'description':
            'Explain the datasource plan (types, entity field mapping, '
            'interface shape) without generating anything',
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
    // Spec #1131 order 4: the plan path is part of the full generate()
    // surface — a hostile argument set must surface as an invalid,
    // message-carrying EffectReport, never an uncaught exception.
    try {
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
    } catch (e) {
      return EffectReport(
        planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
        pluginId: plugin.id,
        capabilityName: name,
        args: args,
        changes: const [],
        isValid: false,
        message:
            'datasource plan failed: $e — re-run with a valid '
            'entity name and typed arguments (methods must be a list).',
      );
    }
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    // Spec #1131 order 4: the FULL generate() path — config build,
    // generation, receipt — is wrapped in try/catch. Every exception
    // becomes `ExecutionResult(success: false, ...)` with a reason and a
    // machine-actionable fix hint; a malformed request or a throwing
    // generator never escapes as an uncaught exception.
    try {
      final config = _buildConfig(args, dryRun: args['dryRun'] ?? false);

      // Spec #1131 order 3: `--explain` answers with the plan instead of
      // generating. Read-only: no artifacts, no receipt.
      if (args['explain'] == true) {
        final text = await const DatasourceExplainer().explain(
          config: config,
          projectRoot: _receiptRoot,
        );
        return ExecutionResult(
          success: true,
          files: const [],
          data: {'explain': text, 'skipReason': 'explain'},
        );
      }

      // Spec #977: a service request supersedes the datasource layer. The
      // plugin's emission semantics are frozen (it still returns [] for
      // `hasService`); the CONTRACT around it is what changed — the skip
      // is reported as a structured failure with the reason so neither the
      // #769 zero-files guard nor a host can mistake it for a success.
      if (config.hasService) {
        return ExecutionResult(
          success: false,
          files: const [],
          message:
              'datasource generation skipped: `${config.name}` requests a '
              'service (use-service) — the service layer supersedes a '
              'dedicated datasource, so nothing was emitted. Re-run without '
              'the service request if a datasource is really wanted.',
          data: const {
            'generatedFiles': <GeneratedFile>[],
            'skipReason': 'hasService',
          },
        );
      }

      final files = await plugin.generate(config);

      // Spec #1131 order 2: the capability persists the deterministic
      // proof.v1 receipt itself — `datasource-<entity>.json` binding the
      // artifacts' digests, the interface's sha256 and the entity source
      // hash — so BOTH invocation paths (the `zfa datasource create`
      // subcommand and the standalone positional command) ship it.
      // Best-effort by design (entity/provider precedent): the artifacts
      // already exist, so a receipt failure degrades to a warning.
      final dryRun = config.dryRun;
      if (!dryRun && files.isNotEmpty) {
        await _emitReceipt(config, files);
      }

      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {
          'generatedFiles': files,
          // #977: resolved input the generation consumed — shipped so the
          // receipt records the id-field / query-field resolution (#294
          // audit trail).
          'input': {
            'id-field': config.idField,
            'id-field-type': config.idFieldType,
            'query-field': config.queryField,
            'query-field-type': config.queryFieldType,
            'local': config.generateLocal,
            'remote': config.generateRemote,
            'cache': config.enableCache,
            'init': config.generateInit,
          },
        },
      );
    } catch (e) {
      // #977/#1131: a thrown generation is an honest failure with a
      // reason and a fix hint, never an empty success or a crash.
      return ExecutionResult(
        success: false,
        files: const [],
        message:
            'datasource generation failed: $e — re-run with a valid entity '
            'name and typed arguments (methods must be a list), then retry '
            '`zfa datasource create <Entity>`.',
      );
    }
  }

  /// The receipt root: the injected [projectRoot] when given (tests),
  /// else derived from the plugin's outputDir — `<outputDir>/../..` is
  /// the project root for both the relative ('lib/src') and absolute
  /// (temp workspace) shapes (provider precedent, spec #979).
  String get _receiptRoot =>
      projectRoot ??
      _normalize(p.join(p.absolute(plugin.outputDir), '..', '..'));

  static String _normalize(String pathValue) => pathValue.replaceAll('\\', '/');

  Future<void> _emitReceipt(
    GeneratorConfig config,
    List<GeneratedFile> files,
  ) async {
    try {
      await DatasourceReceiptWriter().write(
        projectRoot: _receiptRoot,
        outputDir: plugin.outputDir,
        entity: config.name,
        files: files,
        input: {
          'id-field': config.idField,
          'id-field-type': config.idFieldType,
          'query-field': config.queryField,
          'query-field-type': config.queryFieldType,
          'local': config.generateLocal,
          'remote': config.generateRemote,
          'cache': config.enableCache,
          'init': config.generateInit,
        },
      );
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
    }
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) {
    return plugin.generate(_buildConfig(args, dryRun: dryRun));
  }

  GeneratorConfig _buildConfig(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) {
    final name = args['name'];
    return GeneratorConfig(
      name: name,
      outputDir: plugin.outputDir,
      generateDataSource: true,
      generateLocal: args['local'] ?? false,
      generateRemote: args['remote'] ?? true,
      enableCache: args['cache'] ?? false,
      methods: (args['methods'] as List?)?.cast<String>() ?? [],
      paramsType: args['params'],
      returnsType: args['returns'],
      useCaseType: args['type'] ?? 'usecase',
      generateInit: args['init'] == true,
      useService: args['useService'] == true || args['use-service'] == true,
      service: args['service'] as String?,
      idField: args['id-field'] ?? 'id',
      idFieldType: args['id-field-type'] ?? 'String',
      queryField: args['query-field'] ?? 'id',
      queryFieldType: args['query-field-type'] as String?,
      dryRun: dryRun,
      force: args['force'] ?? false,
      verbose: args['verbose'] ?? false,
    );
  }
}
