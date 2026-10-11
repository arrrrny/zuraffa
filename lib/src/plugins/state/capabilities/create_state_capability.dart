import 'package:path/path.dart' as p;

import '../../../core/generator_options.dart';
import '../../../core/plugin_system/capability.dart';
import '../builders/state_builder.dart';
import '../state_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../state_receipt.dart';

/// The `create` capability of the state plugin (spec 1126).
///
/// Spec 1126 (order 2 + order 4): `execute()` is guarded end-to-end
/// (a malformed entity or any generation failure surfaces as
/// `success: false` with the cause — never an uncaught crash through
/// the MCP/capability boundary, the di/repository/service pattern) and
/// every real (non-dry) run ships the deterministic per-entity receipt
/// `.zfa/receipts/state-<entity>.json` via [StateReceiptWriter] —
/// proof.v1 digests plus the state ledger (`state_sha256`,
/// `entity_source`, `state_class`, `methods`). Best-effort by design
/// (the provider/entity precedent): the artifacts already exist, so a
/// receipt failure degrades to a warning instead of failing the run.
/// The config gate (`validateStateConfig`) rejects unknown keys and
/// type-mismatched values before anything runs — JSON args have no
/// args-package type enforcement, so this is the real unknown-key
/// surface.
class CreateStateCapability implements ZuraffaCapability {
  final StatePlugin plugin;

  /// Project root the stable per-entity receipt (`.zfa/receipts/`,
  /// spec 1126 order 2) resolves from. Defaults to the derivation the
  /// service capability uses — `<outputDir>/../..` is the project root
  /// for both the relative (`lib/src`) and absolute (temp workspace)
  /// shapes. Injectable so tests can point at a temp fixture.
  final String? projectRoot;

  CreateStateCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'create';

  @override
  String get description => 'Create a State class';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },

      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'List of methods (get,create,update,delete,list,watch,getList,watchList)',
        'default': ['get', 'update'],
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
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    // Issue #976: the schema now describes the ACTUAL return shape of
    // execute() — an ExecutionResult whose files entry lists the
    // written paths as strings AND whose data.generatedFiles carries
    // the full GeneratedFile objects. The old schema declared only
    // `files: string[]`, silently hiding the generatedFiles payload
    // every manifest/AI consumer plans against.
    'type': 'object',
    'properties': {
      'success': {
        'type': 'boolean',
        'description': 'Whether the state generation succeeded.',
      },
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Paths of the written state files.',
      },
      'data': {
        'type': 'object',
        'properties': {
          'generatedFiles': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'path': {
                  'type': 'string',
                  'description': 'Path of the generated state file.',
                },
                'type': {
                  'type': 'string',
                  'description': 'Artifact type (state).',
                },
                'action': {
                  'type': 'string',
                  'description':
                      'What the run did: create, update/modify or delete.',
                },
                'content': {
                  'type': 'string',
                  'description': 'Final emitted source of the artifact.',
                },
              },
            },
          },
        },
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
    final dryRun = args['dryRun'] == true;
    final target = args['name']?.toString() ?? '';

    // Spec 1126 (order 4): the config gate — unknown keys and
    // type-mismatched values are refused BEFORE anything runs (the
    // JSON-args surface has no parser-enforced types).
    final violations = validateStateConfig(_configInputsOf(args));
    if (violations.isNotEmpty) {
      return ExecutionResult(
        success: false,
        message:
            'state create config rejected: ${violations.join('; ')} '
            '--> fix: pass only the declared state config keys '
            '(methods, no-entity, domain) with matching types',
        data: {'generatedFiles': const <GeneratedFile>[]},
      );
    }

    List<GeneratedFile> files;
    try {
      // Spec 1126 (order 4, the service/di pattern — spec 0974 order
      // 4): the ENTIRE generation path is guarded. A malformed entity
      // or any generation failure surfaces as success: false with the
      // cause — never as an unhandled crash through the MCP/capability
      // boundary.
      files = await _generateFiles(args, dryRun: dryRun);
    } catch (e) {
      return ExecutionResult(
        success: false,
        message: 'state create failed for $target: $e',
        data: {'generatedFiles': const <GeneratedFile>[]},
      );
    }

    // Spec 1126 (order 2): the deterministic per-entity receipt.
    // Best-effort by design; dry runs never persist proofs.
    String? receiptPath;
    if (!dryRun) {
      receiptPath = await _emitReceipt(args, files);
    }

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files, 'stateReceipt': ?receiptPath},
    );
  }

  /// The state config inputs the config gate audits: only the declared
  /// vocabulary entries present in [args] (unknown keys are picked up
  /// by the schema check, not filtered away).
  Map<String, dynamic> _configInputsOf(Map<String, dynamic> args) {
    final config = <String, dynamic>{
      for (final key in args.keys)
        if (key == 'methods' || key == 'no-entity' || key == 'domain')
          key: args[key],
      // Any OTHER key present in args is an unknown config property —
      // feed it to the validator so it is named by a violation.
      for (final key in args.keys)
        if (key != 'methods' &&
            key != 'no-entity' &&
            key != 'domain' &&
            key != 'name' &&
            key != 'dryRun' &&
            key != 'force' &&
            key != 'verbose')
          key: args[key],
    };
    return config;
  }

  /// The receipt root: the injected [projectRoot] when given (tests),
  /// else derived from the plugin's outputDir.
  String get _receiptRoot =>
      projectRoot ??
      _normalize(p.join(p.absolute(plugin.outputDir), '..', '..'));

  Future<String?> _emitReceipt(
    Map<String, dynamic> args,
    List<GeneratedFile> files,
  ) async {
    try {
      final name = args['name']?.toString();
      if (name == null || name.isEmpty) return null;
      final entity = _pascalCase(name);
      final explicitMethods = (args['methods'] as List?)
          ?.map((m) => m.toString())
          .toList(growable: false);
      final noEntity = args['no-entity'] == true;
      final domain = args['domain']?.toString();
      // Mirror the emission defaulting (see _generateFiles).
      final contractMethods =
          explicitMethods ??
          (noEntity ? const <String>[] : const <String>['get', 'update']);

      final written = await StateReceiptWriter().write(
        projectRoot: _receiptRoot,
        outputDir: plugin.outputDir,
        entity: entity,
        files: files,
        stateClass: '${_pascalCase(name)}State',
        methods: contractMethods,
        input: {
          'name': name,
          'methods': contractMethods,
          if (noEntity) 'no-entity': true,
          'domain': ?domain,
          if (args['force'] == true) 'force': true,
        },
      );
      return _normalize(written.path);
    } catch (e) {
      // Provenance is best-effort at this layer (the artifact already
      // exists); loud warning, never a failed generation.
      print('⚠️  State receipt not written: $e');
      return null;
    }
  }

  String _pascalCase(String input) {
    final parts = input
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty);
    final buffer = StringBuffer();
    for (final part in parts) {
      buffer.write(part[0].toUpperCase());
      buffer.write(part.substring(1));
    }
    final out = buffer.toString();
    return out.isEmpty ? input : out;
  }

  String _normalize(String path) => path.replaceAll('\\', '/');

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final noEntity = args['no-entity'] == true;
    // The generateWithContext defaulting: an explicit methodset wins;
    // otherwise a no-entity run wires no CRUD methods (custom mode).
    final explicitMethods = (args['methods'] as List?)?.cast<String>();
    final methods =
        explicitMethods ??
        (noEntity ? <String>[] : const <String>['get', 'update']);
    final force = args['force'] == true;
    final verbose = args['verbose'] == true;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      generateState: true,
      methods: methods,
      noEntity: noEntity,
      domain: args['domain']?.toString(),
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // The emission knobs (dryRun/force/verbose) live at the
    // GeneratorOptions level in this repo (plugin_loader wires the CLI
    // flags there). A capability invocation carries its own knobs in
    // args — derive the builder options from them so `force`
    // regeneration and `dryRun` actually honor the caller's intent
    // instead of silently lying (the #876 family). The builder IS the
    // same emission core plugin.generate delegates to.
    final builder = StateBuilder(
      outputDir: outputDir,
      options: GeneratorOptions(dryRun: dryRun, force: force, verbose: verbose),
    );
    final file = await builder.generate(config);
    return <GeneratedFile>[file];
  }
}
