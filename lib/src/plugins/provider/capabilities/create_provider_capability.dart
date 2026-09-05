import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/plugin_system/capability.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../provider_plugin.dart';
import '../provider_receipt.dart';
import '../provider_verifier.dart';

class CreateProviderCapability implements ZuraffaCapability {
  final ProviderPlugin plugin;

  /// Injectable project root for the deterministic receipt (spec #979
  /// order 1). The CLI leaves it null and the receipt root is derived
  /// from the plugin's outputDir (which resolves relative to the scoped
  /// working directory); tests inject a temp root so they never write
  /// receipts into the repo's own `.zfa/`.
  final String? projectRoot;

  CreateProviderCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Provider';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the provider'},

      'domain': {
        'type': 'string',
        'description': 'Domain folder for the provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for the provider method',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for the provider method',
      },
      // Spec #979 (order 3, schema ≡ grammar): `type` carries the same
      // enum the retired parent-level grammar allowed, and `init` is now
      // declared — `zfa provider create --init` used to be a parse error
      // because CapabilityCommand synthesizes subcommand flags from THIS
      // schema while `init` was only read from args. No defaults are
      // declared for params/returns on purpose: the interface-extraction
      // path (the provider mirrors the Service interface it implements)
      // is the live semantic — see the #768 fix note below.
      'type': {
        'type': 'string',
        'description': 'Provider method type (sync, stream, completable)',
        'enum': ['sync', 'stream', 'completable', 'usecase'],
      },
      'init': {
        'type': 'boolean',
        'description': 'Generate initialization and disposal methods',
        'default': false,
      },
      // Issue #768: MUST match the positional `zfa provider <Entity>` CLI
      // path (ProviderCommand defaults `data` to true). The previous schema
      // default (`false`) made the documented minimal invocation
      // `zfa provider create --name X` a silent no-op: the provider plugin's
      // gate returned zero files while the command reported success.
      'data': {
        'type': 'boolean',
        'description': 'Generate data layer dependencies',
        'default': true,
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
    final dryRun = args['dryRun'] ?? false;
    final files = await _generateFiles(args, dryRun: dryRun);

    // Spec #979 (order 1): persist the deterministic provider receipt —
    // proof.v1 digests plus the interface/methods/stub-count ledger.
    // Best-effort by design (entity_command precedent): the artifacts
    // already exist, so a receipt failure degrades to a warning instead
    // of failing the run. Dry runs never persist proofs.
    if (!dryRun) {
      await _emitReceipt(args, files);
    }

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  /// The receipt root: the injected [projectRoot] when given (tests),
  /// else derived from the plugin's outputDir — `<outputDir>/../..` is
  /// the project root for both the relative ('lib/src') and absolute
  /// (temp workspace) shapes.
  String get _receiptRoot =>
      projectRoot ??
      p.normalize(p.join(p.absolute(plugin.outputDir), '..', '..'));

  Future<void> _emitReceipt(
    Map<String, dynamic> args,
    List<GeneratedFile> files,
  ) async {
    try {
      final name = args['name'] as String;
      final entity = _pascalCase(name);
      final written = files
          .where(
            (f) =>
                f.action == 'created' ||
                f.action == 'overwritten' ||
                f.action == 'updated',
          )
          .toList();
      if (written.isEmpty) return;

      final providerFile = written.first;
      final interface = _interfaceName(name);
      final scan = const ProviderVerifier().scanSource(
        providerFile.content ?? _readFile(providerFile.path),
        '$entity${entity.endsWith('Provider') ? '' : 'Provider'}',
      );

      await ProviderReceiptWriter().write(
        projectRoot: _receiptRoot,
        entity: entity,
        files: written,
        interface: interface,
        methods: scan?.methods ?? const <String>[],
        stubCount: scan?.stubs.length ?? 0,
        input: {
          'name': name,
          if (args['domain'] != null) 'domain': args['domain'],
          if (args['params'] != null) 'params': args['params'],
          if (args['returns'] != null) 'returns': args['returns'],
          if (args['type'] != null) 'type': args['type'],
          if (args['init'] == true) 'init': true,
          'data': args['data'] ?? true,
        },
      );
    } catch (e) {
      print('⚠️  Provider receipt not written: $e');
    }
  }

  static String _readFile(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  static String _interfaceName(String name) {
    final base = name.endsWith('Service')
        ? name.substring(0, name.length - 7)
        : name.endsWith('Provider')
        ? name.substring(0, name.length - 8)
        : name;
    return '$base${base.endsWith('Service') ? '' : 'Service'}';
  }

  static String _pascalCase(String input) {
    if (input.isEmpty) return input;
    final base = input.endsWith('Service')
        ? input.substring(0, input.length - 7)
        : input.endsWith('Provider')
        ? input.substring(0, input.length - 8)
        : input;
    if (base.isEmpty) return input;
    return base[0].toUpperCase() + base.substring(1);
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final domain = args['domain'];
    final paramsType = args['params'];
    final returnsType = args['returns'];
    final useCaseType = args['type'] ?? 'usecase';
    // Issue #768: semantic default for direct execute() callers that omit
    // the key — same contract as the schema default and the positional CLI
    // path. Explicit values, including `false`, are always honored.
    final generateData = args['data'] ?? true;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: name,
      domain: domain,
      methods: [],
      paramsType: paramsType,
      returnsType: returnsType,
      useCaseType: useCaseType,
      generateData: generateData,
      generateInit: args['init'] == true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    // Issue #768: a provider implements a service interface — the builder
    // imports `domain/services/<service>_service.dart` for this capability's
    // non-entity-based config (methods: []). Generating without that
    // interface produces a file that cannot compile; generating nothing
    // silently is the #769 family of false success. Validate up front and
    // fail with an actionable message instead.
    if (generateData) {
      final serviceSnake = config.serviceSnake;
      if (serviceSnake != null) {
        final serviceFile = p.join(
          outputDir,
          'domain',
          'services',
          '${serviceSnake}_service.dart',
        );
        if (!File(serviceFile).existsSync()) {
          throw StateError(
            'No service interface found for `${config.effectiveService}`.\n'
            'Expected: $serviceFile\n'
            'A provider implements a service interface, so it cannot be '
            'generated before the service exists. Create the service first:\n'
            '  zfa service create --name ${args['name']}\n'
            'or run the full-stack flow (which generates provider + service '
            'together):\n'
            '  zfa make ${args['name']}',
          );
        }
      }
    }

    return await plugin.generate(config);
  }
}
