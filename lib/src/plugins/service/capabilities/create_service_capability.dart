import '../../../core/plugin_system/capability.dart';
import '../service_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';

class CreateServiceCapability implements ZuraffaCapability {
  final ServicePlugin plugin;

  CreateServiceCapability(this.plugin);

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
    final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files, 'verdict': _verdict(files, args)},
    );
  }

  /// Issue #978 (order 5) — the machine verdict for `zfa service create`.
  ///
  /// Printed verbatim by CapabilityCommand when the caller passed `--json`
  /// (machine mode), following the #778 single-object convention:
  ///
  ///     {"schema":1, "ok":true, "file":..., "methods":[...], "type":...}
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
    final generateInit = args['init'] == true;

    // The member names the generated interface declares — mirrors
    // ServiceInterfaceBuilder's method emission order.
    final methodNames = <String>[
      if (args['params'] != null || args['returns'] != null)
        _serviceMethodName(args['name'] as String),
      if (generateInit) ...['isInitialized', 'initialize', 'dispose'],
    ];

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

  String _serviceMethodName(String name) {
    if (name.isEmpty) return name;
    return name[0].toLowerCase() + name.substring(1);
  }

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
