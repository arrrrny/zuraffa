import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/plugin_system/capability.dart';
import '../models/generated_file.dart';
import '../plugins/mock/capabilities/create_mock_capability.dart';
import '../plugins/mock/capabilities/dependency_mock_capability.dart';
import '../plugins/mock/capabilities/json_mock_capability.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/mock/services/mock_certification.dart';
import 'base_plugin_command.dart';

class MockCommand extends PluginCommand {
  @override
  final MockPlugin plugin;

  /// `JsonMockCommand` is registered manually below; the auto-registered
  /// `CapabilityCommand` for `JsonMockCapability` (same `json` name) must be
  /// skipped, or the duplicate registration would leave `JsonMockCommand`
  /// unparented and crash `mock json --help` (issue #761). `create` is
  /// manual since issue #970: its `--json` is the OUTPUT envelope flag, not
  /// CapabilityCommand's input-JSON option.
  @override
  Set<String> get manualSubcommandNames => {'create', 'json', 'dependency'};

  MockCommand(this.plugin) : super(plugin) {
    addSubcommand(CreateMockCommand(plugin));
    addSubcommand(DataMockCommand(plugin));
    addSubcommand(JsonMockCommand(plugin));
    addSubcommand(DependencyMockCommand(plugin));
    argParser.addFlag(
      'data-only',
      help: 'Generate only mock data (fixtures)',
      defaultsTo: false,
    );
    argParser.addFlag(
      'json',
      help: 'Generate JSON mock data with fromJson-based helpers',
      defaultsTo: false,
    );
    argParser.addOption('service', help: 'Service name for mock provider');
    argParser.addOption('domain', help: 'Domain folder for the mock provider');
    argParser.addOption('params', help: 'Parameter type for mock methods');
    argParser.addOption('returns', help: 'Return type for mock methods');
  }

  @override
  String get name => 'mock';

  @override
  String get description => 'Generate Mocks';

  @override
  Future<void> run() async {
    final command = argResults?.command;
    if (command != null) {
      return super.run();
    }

    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa mock <EntityName>`) is unreachable through the CLI —
    // package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa mock create|data|json|inject`.
    reportSubcommandUsage();
  }
}

/// `zfa mock create <EntityName>` (issue #970): a manual command (not the
/// auto-registered `CapabilityCommand`) because the A+ contract needs
/// `--json` to be the OUTPUT envelope flag —
/// `{files[], actions, fixturesDir, certification, schema:1}` — instead of
/// CapabilityCommand's input-JSON option. Generation itself is unchanged
/// (CreateMockCapability); only the contract around it moved.
class CreateMockCommand extends Command<void> {
  final MockPlugin plugin;

  CreateMockCommand(this.plugin) {
    argParser.addOption(
      'name',
      help: 'Entity name (alternative to the positional argument)',
    );
    argParser.addMultiOption(
      'methods',
      help:
          'Methods for the mock datasource '
          '(get,update,toggle,create,delete,list,watch,watchList,getList). '
          'Defaults to get,update,toggle in entity mode; none in service '
          'mode (conforms to the service interface).',
    );
    argParser.addFlag(
      'data-only',
      negatable: false,
      help: 'Generate only mock data (fixtures)',
    );
    argParser.addOption(
      'fixtures-dir',
      help:
          'Commit per-entity fixture data under this directory and '
          're-certify it through the #832 fixture registry (spec 893)',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addOption('service', help: 'Service name for mock provider');
    argParser.addOption('domain', help: 'Domain folder for the mock provider');
    argParser.addOption('params', help: 'Parameter type for mock methods');
    argParser.addOption('returns', help: 'Return type for mock methods');
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Machine output: print the generation envelope '
          '{files[], actions, fixturesDir, certification, schema:1} as the '
          'only stdout document (diagnostics go to stderr)',
    );
    argParser.addFlag(
      'certify',
      negatable: false,
      help:
          'After generation, verify the emitted mocks conform to their '
          'interface (scoped dart analyze); drift exits 1 with a '
          '`--> fix:` line naming the missing/incorrect members',
    );
  }

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Mock';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null) {
      print('❌ Usage: zfa mock create <EntityName> [options]');
      exitCode = 64;
      return;
    }
    final entityName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String?;
    if (entityName == null || entityName.isEmpty) {
      print('❌ Usage: zfa mock create <EntityName> [options]');
      // Published-exitCode pattern (issue #767/#970): never a bare exit().
      exitCode = 64;
      return;
    }

    final dataOnly = results['data-only'] == true;
    final dryRun = results['dry-run'] == true;
    final verbose = results['verbose'] == true;
    final service = results['service'] as String?;
    final domain = results['domain'] as String?;
    final rawMethods = (results['methods'] as List?)?.cast<String>();
    // Mirror CreateMockCapability's semantic default (issue #770/#1027):
    // entity mode defaults to the canonical CRUD set; service mode
    // conforms to the declared interface instead.
    final methods = (rawMethods == null || rawMethods.isEmpty)
        ? (service != null
              ? const <String>[]
              : const ['get', 'update', 'toggle'])
        : rawMethods;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    final args = <String, dynamic>{
      'name': entityName,
      if (rawMethods != null && rawMethods.isNotEmpty) 'methods': methods,
      'dataOnly': dataOnly,
      'fixturesDir': ?results['fixtures-dir'],
      'dryRun': dryRun,
      'force': results['force'] == true,
      'verbose': verbose,
      'service': ?service,
      'domain': ?domain,
      'params': ?results['params'],
      'returns': ?results['returns'],
    };

    await _runMockGeneration(
      commandLine: 'zfa mock create $entityName',
      entity: entityName,
      execute: () => capability.execute(args),
      jsonMode: results['json'] == true,
      verbose: verbose,
      dryRun: dryRun,
      dataOnly: dataOnly,
      service: service,
      domain: domain,
      methods: methods,
      certify: results['certify'] == true,
    );
  }
}

class DataMockCommand extends Command<void> {
  final MockPlugin plugin;

  DataMockCommand(this.plugin) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Machine output: print the generation envelope '
          '{files[], actions, fixturesDir, certification, schema:1} as the '
          'only stdout document (diagnostics go to stderr)',
    );
  }

  @override
  String get name => 'data';

  @override
  String get description => 'Generate only mock data (fixtures) for an entity';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      print('❌ Usage: zfa mock data <EntityName> [options]');
      exitCode = 64;
      return;
    }

    final entityName = results.rest.first;
    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    await _runMockGeneration(
      commandLine: 'zfa mock data $entityName',
      entity: entityName,
      execute: () => capability.execute({
        'name': entityName,
        'dataOnly': true,
        'dryRun': results['dry-run'] == true,
        'force': results['force'] == true,
        'verbose': results['verbose'] == true,
        'outputDir': results['output'] ?? 'lib/src',
      }),
      jsonMode: results['json'] == true,
      verbose: results['verbose'] == true,
      dryRun: results['dry-run'] == true,
      dataOnly: true,
    );
  }
}

class JsonMockCommand extends Command<void> {
  final MockPlugin plugin;

  JsonMockCommand(this.plugin) {
    argParser.addOption(
      'name',
      help: 'Entity name (alternative to the positional argument)',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder for grouping JSON files',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing JSON files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Machine output: print the generation envelope '
          '{files[], actions, fixturesDir, certification, schema:1} as the '
          'only stdout document (diagnostics go to stderr)',
    );
  }

  @override
  String get name => 'json';

  @override
  String get description =>
      'Generate JSON mock data with fromJson-based Dart helpers';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null || (results.rest.isEmpty && results['name'] == null)) {
      print('❌ Usage: zfa mock json <EntityName> [options]');
      // Issue #970 (T001, same bug class as #767): a bare exit(64) here
      // killed the ENTIRE host process — fatal for in-process hosts (MCP
      // server, embedded runner, dart test). Publish the usage-error code
      // and return; the host observes it through dart:io exitCode.
      exitCode = 64;
      return;
    }

    final entityName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String;
    final capability =
        plugin.capabilities.firstWhere((c) => c is JsonMockCapability)
            as JsonMockCapability;

    await _runMockGeneration(
      commandLine: 'zfa mock json $entityName',
      entity: entityName,
      execute: () => capability.execute({
        'name': entityName,
        'domain': results['domain'],
        'outputDir': 'lib/src',
        'dryRun': results['dry-run'] == true,
        'force': results['force'] == true,
        'verbose': results['verbose'] == true,
      }),
      jsonMode: results['json'] == true,
      verbose: results['verbose'] == true,
      dryRun: results['dry-run'] == true,
      jsonMock: true,
      domain: results['domain'] as String?,
    );
  }
}

/// `zfa mock dependency <Name>` (issue #960): the certified mock for a
/// declared External Dependencies & Contracts row. The capability owns
/// exit codes + the machine summary line.
class DependencyMockCommand extends Command<void> {
  final MockPlugin plugin;

  DependencyMockCommand(this.plugin) {
    argParser.addOption(
      'feature',
      help:
          'Feature directory under specs/ (defaults to the pinned '
          '.specify/feature.json)',
    );
    argParser.addOption(
      'project',
      help:
          'Project root containing specs/ (defaults to the current '
          'working directory)',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing artifacts',
    );
  }

  @override
  String get name => 'dependency';

  @override
  String get description =>
      'Generate the certified mock for a declared dependency row '
      '(issue #960)';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      print(
        '❌ Usage: zfa mock dependency <Name> [--feature <f>] '
        '[--project <dir>] [--force]',
      );
      exitCode = DependencyMockCapability.exitUndeclared;
      return;
    }
    final argv = <String>[
      results.rest.first,
      if (results['feature'] != null) ...['--feature', results['feature']!],
      if (results['project'] != null) ...['--project', results['project']!],
      if (results['force'] == true) '--force',
    ];
    final capability = DependencyMockCapability(plugin);
    exitCode = await capability.run(argv);
  }
}

// ---------------------------------------------------------------------------
// Shared generation contract (issue #970 T002/T003)
// ---------------------------------------------------------------------------

/// Runs one mock generation (create/data/json) through the shared
/// contract: capability execution, the certification record, the receipt,
/// and either the `--json` machine envelope (stdout = exactly one JSON
/// document, diagnostics on stderr) or the human summary.
///
/// Refusal semantics (issue #769 parity): an execution failure or a run
/// that emits ZERO files refuses with exit 1 — never a lying exit 0.
Future<void> _runMockGeneration({
  required String commandLine,
  required String entity,
  required Future<ExecutionResult> Function() execute,
  required bool jsonMode,
  required bool verbose,
  required bool dryRun,
  bool dataOnly = false,
  bool jsonMock = false,
  String? service,
  String? domain,
  List<String> methods = const [],
  bool certify = false,
}) async {
  final projectRoot = Directory.current.path;

  // `--json` output mode: route EVERY diagnostic print (generator skip
  // notes, warnings, failure lines) to stderr so stdout stays exactly one
  // machine-readable document. The envelope itself is printed after the
  // zone ends.
  Future<ExecutionResult> run() =>
      jsonMode ? _withDiagnosticsOnStderr(execute) : execute();

  final ExecutionResult result;
  try {
    result = await run();
  } catch (e, stack) {
    _emit(jsonMode, '❌ Error: $e');
    if (verbose) {
      _emit(jsonMode, '\nStack trace:\n$stack');
    }
    exitCode = 1;
    return;
  }

  if (!result.success) {
    _emit(jsonMode, '❌ Error: ${result.message}');
    exitCode = 1;
    return;
  }

  final files = result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];

  if (files.isEmpty) {
    // Issue #769: zero files means the request produced nothing — a
    // refusal, not a success.
    _emit(
      jsonMode,
      '⚠️ No files were generated (nothing changed). If the generator '
      'printed a skip note above, re-run inside a project that satisfies '
      'its guard; otherwise re-run with --verbose to inspect the resolved '
      'arguments.',
    );
    exitCode = 1;
    return;
  }

  // The mock certification (issue #970 T003): computed from the FINAL
  // on-disk bytes — a dry run certifies nothing.
  MockCertification? certification;
  String? receiptPath;
  if (!dryRun) {
    try {
      certification = await MockCertificationService.certify(
        entity: entity,
        outputDir: 'lib/src',
        files: files,
        projectRoot: projectRoot,
        dataOnly: dataOnly,
        jsonMode: jsonMock,
        service: service,
        domain: domain,
        methods: methods,
      );
      receiptPath = await MockCertificationService.writeReceipt(
        projectRoot: projectRoot,
        entity: entity,
        commandLine: commandLine,
        certification: certification,
        files: files,
      );
    } catch (e) {
      // Best-effort (issue #807 convention): the artifacts already exist,
      // so a receipt failure degrades to a warning instead of failing the
      // run.
      _emit(jsonMode, '⚠️  Mock-certification receipt not written: $e');
    }
  }

  // The --certify gate (issue #970 T004): structural conformance + scoped
  // dart analyze over the emitted mock files; drift → exit 1 with fix
  // lines naming the missing/incorrect members.
  if (certify && certification != null) {
    final report = await MockCertifier().gate(
      certification: certification,
      projectRoot: projectRoot,
    );
    if (!report.passed) {
      _emit(
        jsonMode,
        '❌ mock certification: $entity does not conform to '
        '${certification.interfaceClass ?? 'its contract'}',
      );
      for (final fix in report.fixLines) {
        _emit(jsonMode, fix);
      }
      exitCode = 1;
    } else {
      _emit(
        jsonMode,
        '✅ mock certification: $entity conforms to '
        '${certification.interfaceClass ?? 'its contract'} '
        '(${certification.registryId})',
      );
    }
  }

  if (jsonMode) {
    final envelope = _buildEnvelope(
      files: files,
      fixturesDir: _fixturesDirFor(files, jsonMock: jsonMock),
      certification: certification?.withReceipt(receiptPath),
    );
    print(jsonEncode(envelope));
    return;
  }

  // Human output (unchanged shape: the summary the CLI always printed).
  final created = files.where((f) => f.action == 'created').toList();
  final overwritten = files.where((f) => f.action == 'overwritten').toList();
  final updated = files.where((f) => f.action == 'updated').toList();
  final skipped = files.where((f) => f.action == 'skipped').toList();
  final deleted = files.where((f) => f.action == 'deleted').toList();

  if (created.isNotEmpty ||
      overwritten.isNotEmpty ||
      updated.isNotEmpty ||
      deleted.isNotEmpty) {
    print('✅ Success! Created/Modified:');
    for (final file in created) {
      print('  ✨ ${file.path}');
    }
    for (final file in overwritten) {
      print('  📝 ${file.path}');
    }
    for (final file in updated) {
      print('  📝 ${file.path}');
    }
    for (final file in deleted) {
      print('  🗑 ${file.path}');
    }
  }
  if (skipped.isNotEmpty) {
    print('\n⏭ Skipped (use --force to overwrite):');
    for (final file in skipped) {
      print('  ${file.path}');
    }
  }
  if (certification != null) {
    print(
      '📜 mock-certification: ${certification.registryId} '
      '(${certification.conformance ? 'conforms' : 'DRIFT'})'
      '${receiptPath == null ? '' : ' → $receiptPath'}',
    );
  }
}

/// The `--json` envelope (issue #970 order 2):
/// `{files[], actions, fixturesDir, certification, schema:1}`.
Map<String, dynamic> _buildEnvelope({
  required List<GeneratedFile> files,
  required String? fixturesDir,
  required MockCertification? certification,
}) {
  final actions = <String, int>{
    'created': 0,
    'overwritten': 0,
    'updated': 0,
    'skipped': 0,
    'deleted': 0,
  };
  for (final file in files) {
    final key = actions.containsKey(file.action) ? file.action : null;
    if (key != null) actions[key] = actions[key]! + 1;
  }
  return {
    'schema': 1,
    'files': [
      for (final file in files)
        {'path': file.path, 'action': file.action, 'type': file.type},
    ],
    'actions': actions,
    'fixturesDir': fixturesDir,
    'certification': certification?.toEnvelopeJson(),
  };
}

/// Where this run's mock fixtures landed: the directory of the first
/// emitted fixture (mock data for create/data, .mock.json for json).
String? _fixturesDirFor(List<GeneratedFile> files, {required bool jsonMock}) {
  final type = jsonMock ? 'mock_json' : 'mock_data';
  for (final file in files) {
    if (file.type == type && file.path.isNotEmpty) {
      return p.dirname(file.path).replaceAll('\\', '/');
    }
  }
  return jsonMock ? null : null;
}

/// Prints [line] to stdout (human mode) or stderr (`--json` mode).
void _emit(bool jsonMode, String line) {
  if (jsonMode) {
    stderr.writeln(line);
  } else {
    print(line);
  }
}

/// Runs [body] with every `print` routed to stderr, keeping stdout a
/// single machine document for `--json` consumers (issue #970 T002).
Future<T> _withDiagnosticsOnStderr<T>(Future<T> Function() body) {
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => stderr.writeln(line),
    ),
  );
}
