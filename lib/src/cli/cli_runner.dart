import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../commands/generate_command.dart';
import '../commands/schema_command.dart';
import '../commands/validate_command.dart';
import '../commands/create_command.dart' as create;
import '../commands/config_command.dart' as config;
import '../commands/initialize_command.dart' as init;
import '../commands/entity_command.dart';
import '../commands/plugin_command.dart' as plugincmd;
import '../commands/make_command.dart';
import '../commands/doctor_command.dart';
import '../core/plugin_system/cli_aware_plugin.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../core/error/suggestion_engine.dart';
import '../version.dart';
import 'plugin_loader.dart';

/// CLI runner for Zuraffa.
class CliRunner {
  final bool exitOnCompletion;
  late final CommandRunner<void> _runner;
  bool _initialized = false;

  CliRunner({this.exitOnCompletion = true}) {
    _runner =
        CommandRunner<void>(
            'zfa',
            'Zuraffa Code Generator - Clean Architecture for Flutter',
          )
          ..argParser.addFlag(
            'version',
            negatable: false,
            abbr: 'v',
            help: 'Print version',
          );
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    final registry = PluginRegistry.instance;
    final loader = PluginLoader(
      outputDir: 'lib/src',
      dryRun: false,
      force: false,
      verbose: false,
      config: PluginConfig(),
    );
    final loadedRegistry = loader.buildRegistry();
    for (final plugin in loadedRegistry.plugins) {
      if (!registry.plugins.any((p) => p.id == plugin.id)) {
        registry.register(plugin);
      }
    }

    // Add all commands from the registry
    for (final plugin in registry.plugins.whereType<CliAwarePlugin>()) {
      _runner.addCommand(plugin.createCommand());
    }

    // Add core commands that aren't plugins
    _runner.addCommand(GenerateCommand());
    _runner.addCommand(SchemaCommand());
    _runner.addCommand(ValidateCommand());
    _runner.addCommand(_CreateCommand());
    _runner.addCommand(_ConfigCommand());
    _runner.addCommand(_InitializeCommand());
    _runner.addCommand(_EntityCommand());
    _runner.addCommand(_PluginCommand());
    _runner.addCommand(MakeCommand(registry));
    _runner.addCommand(DoctorCommand());
  }

  /// Run CLI with arguments.
  Future<void> run(List<String> args) async {
    _ensureInitialized();

    if (args.isEmpty) {
      _printHelp();
      _exit(0);
      return;
    }

    if (_isVersionCommand(args)) {
      print('zfa v$version');
      print('Zuraffa Code Generator');
      _exit(0);
      return;
    }

    try {
      await _runner.run(args);
      _exit(0);
    } on UsageException catch (e) {
      print('❌ ${e.message}');
      print(e.usage);
      _exit(64);
    } catch (e, stack) {
      print('❌ Error: $e');
      _addSuggestions(e.toString());
      if (args.contains('--verbose') || args.contains('-v')) {
        print('\nStack trace:\n$stack');
      }
      _exit(1);
    }
  }

  /// Run CLI and capture output as string.
  Future<String> runCapturing(List<String> args) async {
    _ensureInitialized();

    final output = StringBuffer();

    if (args.isEmpty) {
      _printHelpTo(output.writeln);
      return output.toString();
    }

    if (_isVersionCommand(args)) {
      output.writeln('zfa v$version');
      output.writeln('Zuraffa Code Generator');
      return output.toString();
    }

    await runZoned(
      () async {
        try {
          await _runner.run(args);
        } on UsageException catch (e) {
          output.writeln('❌ ${e.message}');
          output.writeln(e.usage);
        } catch (e, stack) {
          output.writeln('❌ Error: $e');
          _addSuggestionsTo(output.writeln, e.toString());
          if (args.contains('--verbose') || args.contains('-v')) {
            output.writeln('\nStack trace:\n$stack');
          }
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          output.writeln(line);
        },
      ),
    );

    return output.toString();
  }

  bool _isVersionCommand(List<String> args) {
    return args.length == 1 &&
        (args[0] == '--version' || args[0] == '-v' || args[0] == 'version');
  }

  void _addSuggestions(String error) {
    final suggestions = SuggestionEngine().suggestionsFor(errors: [error]);
    if (suggestions.isNotEmpty) {
      print('');
      print('💡 Suggestions:');
      for (final suggestion in suggestions) {
        print('   • $suggestion');
      }
    }
  }

  void _addSuggestionsTo(void Function(String) printFn, String error) {
    final suggestions = SuggestionEngine().suggestionsFor(errors: [error]);
    if (suggestions.isNotEmpty) {
      printFn('');
      printFn('💡 Suggestions:');
      for (final suggestion in suggestions) {
        printFn('   • $suggestion');
      }
    }
  }

  void _printHelp() {
    _printHelpTo(print);
  }

  void _printHelpTo(void Function(String) printFn) {
    printFn('''
zfa - Zuraffa Code Generator v$version

USAGE:
  zfa <command> [options]

CORE COMMANDS:
  generate <Name>     Generate Clean Architecture code
  initialize          Initialize a test entity
  entity              Create and manage Zorphy entities
  config              Manage ZFA configuration
  doctor              Check your environment
  schema              Output JSON schema
  validate <file>     Validate JSON configuration

MODULAR COMMANDS:
  route <Name>        Generate route definitions
  view <Name>         Generate View/Presenter/Controller
  di <Name>           Generate dependency injection
  test <Name>         Generate unit tests

OPTIONS:
  -v, --version       Print version
  -h, --help          Show help

Run "zfa <command> --help" for more information.
''');
  }

  void _exit(int code) {
    if (exitOnCompletion) {
      exit(code);
    }
  }
}

class _CreateCommand extends Command<void> {
  @override
  String get name => 'create';

  @override
  String get description => 'Create architecture folders or pages';

  @override
  Future<void> run() async {
    await create.CreateCommand().execute(argResults!.rest.toList());
  }
}

class _ConfigCommand extends Command<void> {
  @override
  String get name => 'config';

  @override
  String get description => 'Manage ZFA configuration';

  @override
  Future<void> run() async {
    await config.ConfigCommand().execute(argResults!.rest.toList());
  }
}

class _InitializeCommand extends Command<void> {
  @override
  String get name => 'initialize';

  @override
  String get description => 'Initialize a test entity';

  @override
  Future<void> run() async {
    await init.InitializeCommand().execute(argResults!.rest.toList());
  }
}

class _PluginCommand extends Command<void> {
  @override
  String get name => 'plugin';

  @override
  String get description => 'Manage plugins';

  @override
  Future<void> run() async {
    await plugincmd.PluginCommand().execute(argResults!.rest.toList());
  }
}

class _EntityCommand extends Command<void> {
  @override
  String get name => 'entity';

  @override
  String get description => 'Create and manage Zorphy entities';

  @override
  Future<void> run() async {
    await EntityCommand().execute(argResults!.rest.toList());
  }
}
