import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/plugin_system/plugin_registry.dart';
import '../feature_flags/feature_flag_cli.dart';
import '../plugins/feature/feature_plugin.dart';
import 'make_command.dart';

class FeatureCommand extends Command<void> {
  static const String fixedOutputDir = 'lib/src';

  FeatureCommand(FeaturePlugin plugin) {
    argParser.addOption(
      'name',
      help: 'Feature name (alternative to the positional argument)',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Output directory for generated files (fixed to lib/src in v5; custom values are ignored)',
      defaultsTo: fixedOutputDir,
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
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
    argParser.addFlag(
      'plan',
      negatable: false,
      help: 'Print the normalized execution plan and exit',
    );
    argParser.addFlag(
      'explain',
      negatable: false,
      help: 'Explain the normalized execution plan and exit',
    );
    argParser.addFlag(
      'vpcs',
      help: 'Generate View, Presenter, Controller, State',
      defaultsTo: true,
    );
    argParser.addFlag(
      'repository',
      help: 'Generate Repository',
      defaultsTo: true,
    );
    argParser.addFlag(
      'datasource',
      help: 'Generate DataSource (Remote and/or Local)',
      defaultsTo: true,
    );
    argParser.addFlag(
      'local',
      help: 'Generate local data source (instead of remote)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'mock',
      help: 'Generate Mock data',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'di',
      help: 'Generate Dependency Injection setup',
      defaultsTo: true,
    );
    argParser.addFlag(
      'cache',
      help: 'Enable Caching (generates local + remote datasources)',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'use-service',
      help: 'Use service and provider instead of repository and datasource',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'route',
      help: 'Generate Routing definitions',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'test',
      help: 'Generate Tests',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addMultiOption(
      'usecases',
      abbr: 'u',
      help: 'List of custom usecases to generate',
      defaultsTo: [],
      splitCommas: true,
    );
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      help:
          'List of entity methods to generate (e.g. get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: ['get', 'update'],
      splitCommas: true,
    );
    argParser.addOption(
      'query-field',
      help: 'Query field name for get/watch methods',
    );
    argParser.addOption(
      'query-field-type',
      help: 'Query field type for get/watch methods',
    );
    argParser.addOption('id-field', help: 'ID field name');
    argParser.addOption('id-field-type', help: 'ID field type');
  }

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Wrapper over zfa make using the normalized feature preset.';

  @override
  String get invocation =>
      'zfa feature [scaffold|route|di|mock|test|view|presenter|controller|state] <Name> [options]'
      ' | zfa feature list [--format=json] | zfa feature enable|disable <name>';

  static const Set<String> _supportedModes = {
    'scaffold',
    'route',
    'di',
    'mock',
    'test',
    'view',
    'presenter',
    'controller',
    'state',
  };

  /// Spec 030 (FR-002): feature-FLAG management tokens intercepted before
  /// the scaffold-mode dispatch. `list`/`enable`/`disable` are reserved
  /// words for the scaffold path (entity names are PascalCase, so no real
  /// collision exists).
  static const Set<String> _flagManagementTokens = {
    'list',
    'enable',
    'disable',
  };

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      printUsage();
      return;
    }

    // ── Spec 030: feature-flag management (zfa feature list/enable/disable)
    if (_flagManagementTokens.contains(rest.first)) {
      _runFlagManagement(rest);
      return;
    }

    var mode = 'scaffold';
    var nameIndex = 0;
    if (_supportedModes.contains(rest.first)) {
      mode = rest.first;
      nameIndex = 1;
    }

    // Issue #771: the manifest inputSchema declares `name` as a required
    // property for every feature capability — a manifest-driven client
    // sends `--name <value>` and the CLI must accept it (or the schema
    // should describe a positional arg; the flag keeps both callers
    // working). The positional argument keeps precedence.
    final flagName = argResults?['name'] as String?;
    if (rest.length <= nameIndex && (flagName == null || flagName.isEmpty)) {
      print('❌ Missing feature name.');
      printUsage();
      return;
    }

    final featureName = rest.length > nameIndex ? rest[nameIndex] : flagName!;
    final translatedArgs = _buildMakeArgs(featureName, mode: mode);

    final runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
      ..addCommand(MakeCommand(PluginRegistry.instance));
    await runner.run(translatedArgs);
  }

  /// Dispatches the feature-flag management subcommands. Handled failures
  /// set the dart:io exitCode global (honored by CliRunner._runDispatched).
  void _runFlagManagement(List<String> rest) {
    final format = (argResults?['format'] as String?) ?? 'text';
    switch (rest.first) {
      case 'list':
        FeatureFlagCli.list(format: format);
        return;
      case 'enable':
      case 'disable':
        if (rest.length < 2) {
          print('❌ Usage: zfa feature ${rest.first} <name>');
          exitCode = 1;
          return;
        }
        if (rest.first == 'enable') {
          FeatureFlagCli.enable(rest[1]);
        } else {
          FeatureFlagCli.disable(rest[1]);
        }
        return;
    }
  }

  List<String> _buildMakeArgs(String featureName, {required String mode}) {
    final args = <String>[
      'make',
      featureName,
      '--format=${argResults!["format"]}',
    ];

    if (argResults!["dry-run"] == true) args.add('--dry-run');
    if (argResults!["force"] == true) args.add('--force');
    if (argResults!["verbose"] == true) args.add('--verbose');
    if (argResults!["revert"] == true) args.add('--revert');
    if (argResults!["plan"] == true) args.add('--plan');
    if (argResults!["explain"] == true) args.add('--explain');

    final methods = (argResults!["methods"] as List<String>)
        .where((method) => method.isNotEmpty)
        .toList();
    if (methods.isNotEmpty) {
      args.add('--methods=${methods.join(",")}');
    }

    final usecases = (argResults!["usecases"] as List<String>)
        .where((usecase) => usecase.isNotEmpty)
        .toList();
    if (usecases.isNotEmpty) {
      args.add('--usecases=${usecases.join(",")}');
    }

    void addOptionIfParsed(String name) {
      if (argResults!.wasParsed(name)) {
        final value = argResults![name];
        if (value is String && value.isNotEmpty) {
          args.add('--$name=$value');
        }
      }
    }

    addOptionIfParsed('query-field');
    addOptionIfParsed('query-field-type');
    addOptionIfParsed('id-field');
    addOptionIfParsed('id-field-type');

    switch (mode) {
      case 'scaffold':
        args.add('--preset=feature');
        final excluded = <String>['test'];

        if (argResults!["repository"] != true) {
          excluded.add('repository');
        }
        if (argResults!["datasource"] != true) {
          excluded.add('datasource');
        }
        if (argResults!["vpcs"] != true) {
          excluded.addAll(['view', 'presenter', 'controller', 'state']);
        }
        if (argResults!["di"] != true) {
          excluded.add('di');
        }
        if (argResults!["test"] == true) {
          excluded.remove('test');
        }
        if (argResults!["use-service"] == true) {
          args.add('--use-service');
          excluded.addAll(['repository', 'datasource']);
        }
        if (argResults!["local"] == true) args.add('--local');
        if (argResults!["mock"] == true) args.add('--mock');
        if (argResults!["cache"] == true) args.add('--cache');
        if (argResults!["route"] == true) args.add('--route');

        if (excluded.isNotEmpty) {
          args.add('--without=${excluded.toSet().join(",")}');
        }
        break;
      default:
        args.add('--with=$mode');
        break;
    }

    return args;
  }
}
