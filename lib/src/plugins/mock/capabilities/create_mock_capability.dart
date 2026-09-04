import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/plugin_system/capability.dart';
import '../../../models/generator_config.dart';
import '../../../models/generated_file.dart';
import '../builders/simulation_fixture_writer.dart';
import '../certification/mock_certifier.dart';
import '../mock_plugin.dart';

class CreateMockCapability implements ZuraffaCapability {
  final MockPlugin plugin;

  CreateMockCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Mock';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'description': 'Name of the mock target'},
      // Issue #770: default to the canonical CRUD method set used by the
      // di/usecase/test/state/controller/datasource/repository plugins and
      // by MockPlugin.generateWithContext (#294). With an empty method set
      // the generated mock datasource implements the datasource interface
      // without any members and fails analyze with
      // non_abstract_class_inherits_abstract_member.
      'methods': {
        'type': 'array',
        'items': {'type': 'string'},
        // No static default here (issue #1027): the effective default is
        // mode-dependent — the canonical CRUD set for entity mode, an empty
        // set for service mode (which conforms to the declared service
        // interface instead). A static schema default would materialize
        // through CapabilityCommand's addMultiOption(defaultsTo:) and the
        // service-mode branch in execute() could never distinguish an
        // explicit --methods from the entity-mode default.
        'description':
            'List of methods for the mock datasource (get,create,update,delete,list,watch,getList,watchList,toggle). Defaults to get,update,toggle for entity mode; none for service mode (conforms to the service interface).',
      },
      'dataOnly': {
        'type': 'boolean',
        'description': 'Generate mock data only',
        'default': false,
      },
      'fixturesDir': {
        'type': 'string',
        'description':
            'Commit per-entity fixture data under this directory (e.g. '
            'specs/<feature>/tdd/fixtures) and re-certify it through the '
            '#832 fixture registry (spec 893)',
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
      'service': {
        'type': 'string',
        'description': 'Service name for mock provider',
      },
      'domain': {
        'type': 'string',
        'description': 'Domain folder for the mock provider',
      },
      'params': {
        'type': 'string',
        'description': 'Parameter type for mock methods',
      },
      'returns': {
        'type': 'string',
        'description': 'Return type for mock methods',
      },
      // Spec 1001 (issue #1001): Tier-1 certified mocks.
      'certify': {
        'type': 'boolean',
        'description':
            'After generating the mock, run the auto-generated contract '
            'test in a temp sandbox (dart analyze + dart test) and write '
            'the mock-cert.<Entity>.json receipt with per-method '
            'satisfied flags and the contract digest (spec 1001)',
        'default': false,
      },
      'seed': {
        'type': 'integer',
        'description':
            'Deterministic generation seed (spec 1001): the same seed '
            'reproduces byte-identical mocks (replayable generation)',
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

    // Spec 1001 (issue #1001): `zfa mock create <Entity> --certify` —
    // after generating the mock, run the auto-generated contract test in
    // a temp sandbox and write the mock-cert.<Entity>.json receipt. A red
    // contract is an honest failure: success=false, exit 1, the receipt
    // still records per-method satisfied: false so the drift is legible.
    if (args['certify'] == true && args['dryRun'] != true) {
      return _certify(args, files);
    }

    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {'generatedFiles': files},
    );
  }

  Future<ExecutionResult> _certify(
    Map<String, dynamic> args,
    List<GeneratedFile> files,
  ) async {
    final name = args['name'] as String;
    final seed = args['seed'] is int ? args['seed'] as int : null;
    final verbose = args['verbose'] == true;
    // The capability runs against the plugin's outputDir which is
    // project-relative (lib/src); the project root is the cwd (the CLI
    // resolves it before dispatch).
    final projectRoot = Directory.current.path;
    final certifier = MockCertifier();
    final outcome = await certifier.certify(
      entityName: name,
      projectRoot: projectRoot,
      outputDir: plugin.outputDir,
      seed: seed,
      // create is the RE-PIN path: the mock was (re)generated against
      // the current interface, so the contract is re-rendered to match.
      rePin: true,
      verbose: verbose,
    );
    final written = await certifier.writeContractArtifacts(
      entityName: name,
      projectRoot: projectRoot,
      outcome: outcome,
    );
    for (final file in written) {
      files.add(
        GeneratedFile(
          path: file.path,
          content: await file.readAsString(),
          action: 'created',
          type: p.basename(file.path).startsWith('mock-cert.')
              ? 'mock_cert_receipt'
              : 'mock_contract_test',
        ),
      );
    }

    final receipt = outcome.receipt;
    if (!outcome.certified) {
      final unsatisfied = receipt == null
          ? outcome.methodNames
          : receipt.methods.where((m) => !m.value).map((m) => m.key).toList();
      final reason = outcome.logs.isNotEmpty
          ? outcome.logs.join('\n')
          : 'contract test did not prove every method satisfied';
      stdout.writeln(
        '❌ mock certification for $name failed — unsatisfied: '
        '${unsatisfied.join(', ')}',
      );
      return ExecutionResult(
        success: false,
        message: 'mock certification failed for $name: $reason',
        files: files.map((f) => f.path).toList(),
        data: {
          'generatedFiles': files,
          'certified': false,
          if (receipt != null) 'mockCertReceipt': receipt.toJson(),
        },
      );
    }

    stdout.writeln(
      '⚙ mock-cert: entity=$name methods=${receipt!.methods.length} '
      'satisfied=${receipt.methods.where((m) => m.value).length} '
      'digest=${receipt.contractDigest.substring(0, 12)}…',
    );
    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {
        'generatedFiles': files,
        'certified': true,
        'mockCertReceipt': receipt.toJson(),
      },
    );
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final dataOnly = args['dataOnly'] ?? false;
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;
    final service = args['service'];
    final domain = args['domain'];
    final params = args['params'];
    final returns = args['returns'];
    final fixturesDir = args['fixturesDir'] as String?;
    final seed = args['seed'] is int ? args['seed'] as int : null;
    // Issue #770: semantic default for direct execute() callers that omit
    // the key — the canonical entity-CRUD set (#294). Explicit values are
    // honored. There is deliberately no static schema default for this key
    // (issue #1027): CapabilityCommand would materialize it and the
    // service-mode branch below could never fire.
    // Issue #1027: service mode has no entity methods — an empty default
    // lets the provider builder conform to the declared service interface
    // (MethodExtractor) instead of crashing on the entity-CRUD set.
    // An EMPTY list is treated as unspecified: CapabilityCommand surfaces
    // a never-provided multi-option as [] (package:args), which must not
    // strip the entity-mode default.
    final rawMethods = (args['methods'] as List?)?.cast<String>();
    final methods = (rawMethods == null || rawMethods.isEmpty)
        ? (service != null
              ? const <String>[]
              : const ['get', 'update', 'toggle'])
        : rawMethods;

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      service: service,
      domain: domain,
      paramsType: params,
      returnsType: returns,
      methods: methods,
      generateMock: !dataOnly,
      generateMockDataOnly: dataOnly,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      // Spec 1001: deterministic, replayable mock generation.
      seed: seed,
    );

    final files = await plugin.generate(config);

    // Spec 893 (T003, FR-003): commit per-entity fixture data under the
    // feature's tdd/fixtures/ directory and re-certify it through the
    // #832 fixture registry. Fixture commitment is part of the standard
    // `zfa mock create` workflow, not a manual step.
    if (fixturesDir != null && fixturesDir.isNotEmpty && !dryRun && !dataOnly) {
      final entityName = config.repo != null
          ? config.repo!.replaceAll('Repository', '')
          : config.name;
      final writer = SimulationFixtureWriter(
        outputDir: outputDir,
        verbose: verbose,
      );
      files.add(
        await writer.write(
          entityName: entityName,
          fixturesDir: fixturesDir,
          commandLine:
              'zfa mock create $entityName --fixtures-dir $fixturesDir',
        ),
      );
    }

    return files;
  }
}
