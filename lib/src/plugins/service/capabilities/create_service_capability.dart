import 'package:path/path.dart' as p;

import '../../../core/plugin_system/capability.dart';
import '../service_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../service_receipt.dart';

class CreateServiceCapability implements ZuraffaCapability {
  final ServicePlugin plugin;

  /// Project root the stable per-entity receipt (`.zfa/receipts/`,
  /// SPEC 1127 order 3) resolves from. Defaults to the derivation the
  /// provider capability uses — `<outputDir>/../..` is the project root
  /// for both the relative (`lib/src`) and absolute (temp workspace)
  /// shapes. Injectable so tests can point at a temp fixture.
  final String? projectRoot;

  CreateServiceCapability(this.plugin, {this.projectRoot});

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Service interface';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the service'},

      // Issue #978 (schema ≡ grammar): `init` was missing here, so
      // `zfa service create --init` could not even parse —
      // CapabilityCommand synthesizes the subcommand's flags from THIS
      // schema. The four grammar knobs (params/returns/type/init) now
      // match ServiceCommand's grammar, including the `type` enum and the
      // params/returns defaults the command grammar declares.
      'params': {
        'type': 'string',
        'description': 'Parameter type for the service method',
        'default': 'NoParams',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for the service method',
        'default': 'void',
      },
      'type': {
        'type': 'string',
        'description': 'Service method type (sync, stream, completable)',
        'enum': ['sync', 'stream', 'completable', 'usecase'],
        'default': 'usecase',
      },
      'init': {
        'type': 'boolean',
        'description': 'Generate initialization and disposal methods',
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
    final dryRun = args['dryRun'] == true;
    final target = args['name']?.toString() ?? '';

    List<GeneratedFile> files;
    try {
      // SPEC 1127 (order 4, the di/repository pattern — spec 0974 order
      // 4): the ENTIRE generation path is guarded. A malformed entity or
      // any generation failure surfaces as success: false with the cause —
      // never as an unhandled crash through the MCP/capability boundary.
      files = await _generateFiles(args, dryRun: dryRun);
    } catch (e) {
      return ExecutionResult(
        success: false,
        message: 'service create failed for $target: $e',
        data: {'generatedFiles': const <GeneratedFile>[]},
      );
    }

    // SPEC 1127 (order 3): the deterministic per-entity receipt —
    // proof.v1 digests plus the service ledger (interface, methods,
    // knobs). Best-effort by design (the provider/entity precedent): the
    // artifacts already exist, so a receipt failure degrades to a warning
    // instead of failing the run. Dry runs never persist proofs.
    String? receiptPath;
    if (!dryRun) {
      receiptPath = await _emitReceipt(args, files);
    }

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {
        'generatedFiles': files,
        'verdict': _verdict(files, args),
        'serviceReceipt': ?receiptPath,
      },
    );
  }

  /// The receipt root: the injected [projectRoot] when given (tests), else
  /// derived from the plugin's outputDir.
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
      final written = files
          .where(
            (f) =>
                f.action == 'created' ||
                f.action == 'overwritten' ||
                f.action == 'updated',
          )
          .toList();
      if (written.isEmpty) return null;

      final interface = _interfaceName(name);
      final methodNames = _methodNames(args);

      final written2 = await ServiceReceiptWriter().write(
        projectRoot: _receiptRoot,
        entity: entity,
        files: written,
        interface: interface,
        methods: methodNames,
        input: {
          'name': name,
          if (args['params'] != null) 'params': args['params'],
          if (args['returns'] != null) 'returns': args['returns'],
          'type': args['type'] ?? 'usecase',
          if (args['init'] == true) 'init': true,
        },
      );
      return _normalize(written2.path);
    } catch (e) {
      // Provenance is best-effort at this layer (the artifact already
      // exists); loud warning, never a failed generation.
      print('⚠️  Service receipt not written: $e');
      return null;
    }
  }

  /// Issue #978 (order 5) — the machine verdict for direct capability
  /// callers (MCP / make-context consumers). The CLI's `--json` surface
  /// upgrades to the canonical `zuraffa.verdict.v1` envelope (SPEC 1127,
  /// issue #1105) in [ServiceCreateCommand]; this inner verdict keeps the
  /// single-object `{schema:1, ok, ...}` shape those callers read.
  ///
  /// `ok` is true only when the run actually changed something (a file was
  /// created/overwritten/updated). Zero files or an all-`skipped` result is
  /// `ok:false` with an actionable `fix` hint — a declined generation is
  /// never dressed up as success (issue #769 semantics).
  Map<String, dynamic> _verdict(
    List<GeneratedFile> files,
    Map<String, dynamic> args,
  ) {
    final useCaseType = args['type'] ?? 'usecase';

    final methodNames = _methodNames(args);

    final changed = files.where((f) => f.action != 'skipped').toList();
    if (files.isEmpty) {
      return {
        'schema': 1,
        'ok': false,
        'file': null,
        'methods': methodNames,
        'type': useCaseType,
        'error': 'no files were generated',
        'fix': 'zfa service create --name <ServiceName>',
      };
    }
    if (changed.isEmpty) {
      return {
        'schema': 1,
        'ok': false,
        'file': files.first.path,
        'methods': methodNames,
        'type': useCaseType,
        'error': 'the service file already exists (skipped, nothing changed)',
        'fix': 're-run with --force to overwrite ${files.first.path}',
      };
    }
    return {
      'schema': 1,
      'ok': true,
      'file': files.first.path,
      'methods': methodNames,
      'type': useCaseType,
    };
  }

  /// The member names the generated interface declares — mirrors
  /// ServiceInterfaceBuilder's method emission order.
  List<String> _methodNames(Map<String, dynamic> args) {
    final generateInit = args['init'] == true;
    final hasCustomMethod = args['params'] != null || args['returns'] != null;
    final name = args['name']?.toString() ?? '';
    return <String>[
      if (hasCustomMethod && name.isNotEmpty) _camelCase(name),
      if (generateInit) ...['isInitialized', 'initialize', 'dispose'],
    ];
  }

  String _serviceMethodName(String name) {
    if (name.isEmpty) return name;
    return name[0].toLowerCase() + name.substring(1);
  }

  String _camelCase(String name) => _serviceMethodName(name);

  /// `<Base>Service` from a raw name (accepts an existing -Service or
  /// -Provider suffix, like GeneratorConfig.effectiveService).
  String _interfaceName(String name) {
    var base = name;
    if (base.endsWith('Service')) {
      base = base.substring(0, base.length - 7);
    } else if (base.endsWith('Provider')) {
      base = base.substring(0, base.length - 8);
    }
    return '${_pascalCase(base)}Service';
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
    final paramsType = args['params'];
    final returnsType = args['returns'];
    final useCaseType = args['type'] ?? 'usecase';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: name,
      methods: [],
      paramsType: paramsType,
      returnsType: returnsType,
      useCaseType: useCaseType,
      generateInit: args['init'] == true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
