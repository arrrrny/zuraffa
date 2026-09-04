import 'dart:io';

import 'package:args/command_runner.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/mock/capabilities/certify_mock_capability.dart';
import '../plugins/mock/capabilities/create_mock_capability.dart';
import '../plugins/mock/capabilities/dependency_mock_capability.dart';
import '../plugins/mock/capabilities/json_mock_capability.dart';

class MockCommand extends PluginCommand {
  @override
  final MockPlugin plugin;

  /// `JsonMockCommand` is registered manually below; the auto-registered
  /// `CapabilityCommand` for `JsonMockCapability` (same `json` name) must be
  /// skipped, or the duplicate registration would leave `JsonMockCommand`
  /// unparented and crash `mock json --help` (issue #761). Same for
  /// `DependencyMockCommand` (issue #960) and `CertifyMockCommand`
  /// (spec 1001) — both own CLI exit codes.
  @override
  Set<String> get manualSubcommandNames => {'json', 'dependency', 'certify'};

  MockCommand(this.plugin) : super(plugin) {
    addSubcommand(DataMockCommand(plugin));
    addSubcommand(JsonMockCommand(plugin));
    addSubcommand(DependencyMockCommand(plugin));
    addSubcommand(CertifyMockCommand(plugin));
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
      return;
    }

    final entityName = results.rest.first;
    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateMockCapability)
            as CreateMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'dataOnly': true,
      'dryRun': results['dry-run'] == true,
      'force': results['force'] == true,
      'verbose': results['verbose'] == true,
      'outputDir': results['output'] ?? 'lib/src',
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      print('\n✅ Mock data generation complete for: $entityName');
      for (final file in files) {
        if (file.action == 'created') {
          print('  ✨ ${file.path}');
        } else if (file.action == 'overwritten') {
          print('  📝 ${file.path}');
        }
      }
    } else {
      print('❌ Error: ${result.message}');
    }
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
      exit(64);
    }

    final entityName = results.rest.isNotEmpty
        ? results.rest.first
        : results['name'] as String;
    final capability =
        plugin.capabilities.firstWhere((c) => c is JsonMockCapability)
            as JsonMockCapability;

    final result = await capability.execute({
      'name': entityName,
      'domain': results['domain'],
      'outputDir': 'lib/src',
      'dryRun': results['dry-run'] == true,
      'force': results['force'] == true,
      'verbose': results['verbose'] == true,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      print('\n✅ JSON mock data generated for: $entityName');
      for (final file in files) {
        if (file.action == 'created') {
          print('  ✨ ${file.path}');
        } else if (file.action == 'overwritten') {
          print('  📝 ${file.path}');
        }
      }
    } else {
      print('❌ Error: ${result.message}');
    }
  }
}

/// `zfa mock certify <Name>` (spec 1001, issue #1001): re-proves the
/// mock's contract live and registers it in the #832 registry entry.
/// The capability owns exit codes + the machine summary line.
class CertifyMockCommand extends Command<void> {
  final MockPlugin plugin;

  CertifyMockCommand(this.plugin) {
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
    argParser.addOption(
      'fixtures-dir',
      help:
          'Explicit fixtures directory for the #832 registry entry '
          '(default: specs/<feature>/tdd/fixtures)',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing artifacts',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
  }

  @override
  String get name => 'certify';

  @override
  String get description =>
      'Re-certify a mock live (contract test in a sandbox) and add it '
      'to the #832 registry entry (spec 1001)';

  @override
  Future<void> run() async {
    final results = argResults;
    if (results == null || results.rest.isEmpty) {
      print(
        '❌ Usage: zfa mock certify <EntityName> [--feature <f>] '
        '[--project <dir>] [--fixtures-dir <dir>]',
      );
      exitCode = CertifyMockCapability.exitUsage;
      return;
    }
    final argv = <String>[
      results.rest.first,
      if (results['feature'] != null) ...['--feature', results['feature']!],
      if (results['project'] != null) ...['--project', results['project']!],
      if (results['fixtures-dir'] != null) ...[
        '--fixtures-dir',
        results['fixtures-dir']!,
      ],
      if (results['force'] == true) '--force',
      if (results['verbose'] == true) '--verbose',
    ];
    final capability = CertifyMockCapability(plugin);
    exitCode = await capability.run(argv);
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
