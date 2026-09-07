import '../../../core/plugin_system/capability.dart';
import '../test_plugin.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../test_explain.dart';

class CreateTestCapability implements ZuraffaCapability {
  final TestPlugin plugin;

  CreateTestCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Test';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the test target'},

      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Methods to test (for entity based)',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for custom usecases',
        'default': 'general',
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
      // Spec 1129: the human twin of the certification envelope. The
      // schema property makes the flag surface manifest-verifiable (the
      // #902/#904 drift classes) and advertises it to MCP clients; the
      // CLI bespoke create grammar accepts the same flag.
      'explain': {
        'type': 'boolean',
        'description':
            'Attach the human-readable explain block (generated files, '
            'test kinds unit/integration/widget, per-file '
            'self-certification, trust tiers) to the result data; the '
            'CLI prints it after the regular output (spec 1129)',
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

    // Spec 980 / FR-001: self-certification gate. The plugin ran a scoped
    // `dart analyze` on every written test file and printed the machine
    // verdict line. Non-compiling output fails the capability — the
    // `zfa test create` grammar exits 1 (never a silent success). Dry runs
    // and empty generations certify nothing and keep the previous
    // semantics.
    final certification = plugin.lastCertification;
    final compilePassed = certification?.compile ?? true;

    return ExecutionResult(
      success: compilePassed,
      files: files.map((f) => f.path).toList(),
      data: {
        'generatedFiles': files,
        if (certification != null) 'certification': certification.toJson(),
        // Spec 1129: the human-readable block, additive to the spec 980
        // data contract (the envelope shape above is untouched — the
        // --json semantics are unchanged). The generic CapabilityCommand
        // prints data['explain'] verbatim (Spec #1131), so MCP clients
        // get the same block the bespoke CLI command prints.
        if (args['explain'] == true)
          'explain': buildTestExplain(
            // The certified entity IS the verdict line's entity
            // (config.name); fall back to the raw invocation name when
            // nothing was certified (dry run / empty generation).
            entity:
                certification?.entity ??
                (args['name']?.toString() ?? 'unknown'),
            files: files,
            certification: certification,
          ),
      },
      message: compilePassed
          ? null
          : 'Generated tests do not compile: ${certification!.verdictLine}',
    );
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final methods = (args['methods'] as List<dynamic>?)?.cast<String>() ?? [];
    final domain = args['domain'] ?? 'general';
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    final analyzed = await plugin.buildConfigFromUseCase(
      name,
      outputDir,
      domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final config =
        analyzed ??
        GeneratorConfig(
          name: name,
          outputDir: outputDir,
          methods: methods,
          domain: domain,
          generateTest: true,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );

    return await plugin.generate(config);
  }
}
