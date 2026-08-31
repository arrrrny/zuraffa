import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import '../commands/schema_command.dart';
import '../commands/ui_command.dart';
import '../commands/validate_command.dart';
import '../commands/create_command.dart' as create;
import '../commands/config_command.dart' as config;
import '../commands/initialize_command.dart' as init;
import '../commands/entity_command.dart';
import '../commands/plugin_command.dart' as plugincmd;
import '../commands/make_command.dart';
import '../commands/doctor_command.dart';
import '../commands/migrate_command.dart';
import '../commands/update_command.dart';
import '../commands/build_command.dart';
import '../commands/manifest_command.dart';
import '../commands/generate_commands_command.dart';
import '../commands/apply_command.dart';
import '../commands/module_command.dart';
import '../commands/xray_command.dart';
import '../commands/setup_command.dart';
import '../commands/tdd_command.dart';
import '../commands/app_shell_command.dart';
import '../commands/package_command.dart';
import '../core/plugin_system/cli_aware_plugin.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../plugins/tdd/tdd_plugin.dart';
import '../core/error/suggestion_engine.dart';
import '../version.dart';
import 'plugin_loader.dart';

/// CLI runner for Zuraffa.
class CliRunner {
  final bool exitOnCompletion;
  late final CommandRunner<void> _runner;
  bool _coreInitialized = false;

  /// Plugin commands are registered separately from the core commands so a
  /// prior plugin-free command (e.g. `xray`) that skips the plugin boot does
  /// not prevent a later plugin-backed command from being registered in a
  /// reused [CliRunner] (issue #531 regression).
  bool _pluginsInitialized = false;

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
          )
          // Global `-C/--directory <dir>`: run as if zfa was started in
          // <dir> instead of the current working directory. The directory is
          // applied as a scoped chdir (restored after the invocation), so
          // tests can target a temp fixture project WITHOUT mutating the
          // process-global Directory.current — which concurrent tests share
          // and can corrupt (issue #441 / TDD CWD race). Most commands
          // resolve their root from Directory.current, so they inherit the
          // override automatically; commands with their own `--project-root`
          // flag (ui, tdd *) take precedence via that flag when supplied.
          ..argParser.addOption(
            'directory',
            abbr: 'C',
            help:
                'Run as if zfa was started in <dir> (scoped; the process '
                'working directory is restored afterward).',
          );
  }

  /// Top-level commands whose execution path never consumes the plugin
  /// registry (no plugin-provided subcommands, no generator plugins needed).
  ///
  /// Every spawned `dart bin/zfa.dart` process used to pay the cost of
  /// [PluginLoader.buildRegistry] (27 plugin constructions + registry walk)
  /// even for these commands. Under parallel `dart test -j 4` CPU contention
  /// that redundant per-launch work compounded and blew the 2-minute
  /// per-test timeout on the `xray` integration tests (issue #531). We skip
  /// the heavy plugin boot for them; the core commands below are always
  /// registered regardless.
  static const Set<String> _noPluginCommands = {'xray'};

  void _ensureInitialized([List<String> args = const []]) {
    // Strip the global `-C`/`--directory` flag (if present) before the
    // plugin-skip decision so `zfa -C <dir> xray` still skips the plugin
    // boot (issue #531).
    final effectiveArgs = _stripDirectory(args);
    final skipPlugins =
        effectiveArgs.isNotEmpty &&
        _noPluginCommands.contains(effectiveArgs.first);

    // Load plugins BEFORE the core commands so that `MakeCommand`'s
    // `argParser` is built against the fully-populated registry. Otherwise
    // `_addPluginOptions` iterates an empty `registry.plugins` and never
    // registers plugin-derived options (e.g. graphql's `--type`, cache's
    // `--cache-storage`/`--ttl`). `PluginManager.buildContext` later calls
    // `argResults.wasParsed(key)` for every active plugin's schema property
    // and throws "Could not find an option named --type" when such an option
    // is missing.
    if (!_pluginsInitialized && !skipPlugins) {
      _pluginsInitialized = true;
      _loadAndRegisterPlugins();
    }

    // Plugin-backed commands are tracked separately, so a prior `xray`
    // invocation (which skips the plugin boot) cannot leave a later non-xray
    // command without its plugin commands in a reused runner.
    if (!_coreInitialized) {
      _coreInitialized = true;
      _addCoreCommands();
    }
  }

  void _addCoreCommands() {
    // The registry is a process-global singleton, always available so
    // registry-consuming core commands (make/manifest/apply) can bind to it.
    final registry = PluginRegistry.instance;
    _runner.addCommand(SchemaCommand());
    _runner.addCommand(ValidateCommand());
    _runner.addCommand(_CreateCommand());
    _runner.addCommand(_ConfigCommand());
    _runner.addCommand(_InitializeCommand());
    _runner.addCommand(_EntityCommand());
    _runner.addCommand(_PluginCommand());
    _runner.addCommand(MakeCommand(registry));
    _runner.addCommand(DoctorCommand());
    _runner.addCommand(MigrateCommand());
    _runner.addCommand(BuildCommand());
    _runner.addCommand(ManifestCommand(registry));
    _runner.addCommand(GenerateCommandsCommand(registry));
    _runner.addCommand(ApplyCommand(registry));
    _runner.addCommand(ModuleCommand());
    _runner.addCommand(XrayCommand());
    _runner.addCommand(UpdateCommand());
    _runner.addCommand(SetupCommand());
    _runner.addCommand(TddCommand(TddPlugin()));
    _runner.addCommand(AppCommand());
    _runner.addCommand(UiCommand());
    _runner.addCommand(PackageCommand());
  }

  void _loadAndRegisterPlugins() {
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
  }

  /// Run CLI with arguments.
  Future<void> run(List<String> args) async {
    final directory = _extractDirectory(args);
    // Strip the global `-C`/`--directory` flag before the pre-dispatch checks
    // (empty / version / removed-generate) so that `zfa -C <dir> help` and
    // `zfa -C <dir> generate ...` are classified correctly even though `-C`
    // shifts `args.first` / `args.isEmpty`.
    final commandArgs = _stripDirectory(args);
    await _withDirectory(directory, () async {
      _ensureInitialized(args);

      if (commandArgs.isEmpty) {
        _printHelp();
        _exit(0);
        return;
      }

      if (_isVersionCommand(commandArgs)) {
        print('zfa v$version');
        print('Zuraffa Code Generator');
        _exit(0);
        return;
      }

      if (_isRemovedGenerateCommand(commandArgs)) {
        _printRemovedGenerateMessage();
        _exit(64);
        return;
      }

      await _runDispatched(args);
    });
  }

  /// Run the dispatched command, honoring a failure exit code set by the
  /// command (dart:io `exitCode`); calling `exit(0)` unconditionally would
  /// clobber it.
  Future<void> _runDispatched(List<String> args) async {
    try {
      await _runner.run(args);
      _exit(exitCode);
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

  /// If [directory] is non-null, scope [body] to a temporary working
  /// directory (restored afterward). This is the safe replacement for tests
  /// assigning `Directory.current` directly: the change is confined to this
  /// invocation and never leaks into the shared process-global CWD.
  ///
  /// Crucially, command construction (`_ensureInitialized`) must happen
  /// *inside* this scope: commands resolve their project root from
  /// `Directory.current` in their constructors, so the chdir must be in
  /// place before they are built (otherwise they bake in the wrong root).
  Future<void> _withDirectory(
    String? directory,
    Future<void> Function() body,
  ) async {
    if (directory == null) {
      await body();
      return;
    }
    final saved = Directory.current;
    Directory.current = p.absolute(directory);
    try {
      await body();
    } finally {
      Directory.current = saved;
    }
  }

  /// Extract the global `-C`/`--directory` value from [args] (manual scan so
  /// we can apply the scoped chdir before the command runs). The root
  /// argParser also defines the option, so `_runner.run` still parses it.
  String? _extractDirectory(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '--directory' || a == '-C') {
        if (i + 1 < args.length) return args[i + 1];
      } else if (a.startsWith('--directory=')) {
        return a.substring('--directory='.length);
      }
    }
    return null;
  }

  /// Remove the global `-C`/`--directory` flag from [args] (value and its
  /// preceding flag) so downstream logic (plugin-skip decision) sees the
  /// real command name first.
  List<String> _stripDirectory(List<String> args) {
    final result = <String>[];
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (a == '--directory' || a == '-C') {
        i++; // skip the value too
        continue;
      }
      if (a.startsWith('--directory=')) continue;
      result.add(a);
    }
    return result;
  }

  /// Run CLI and capture output as string.
  Future<String> runCapturing(List<String> args) async {
    final output = <String>[];

    final directory = _extractDirectory(args);
    // Strip the global `-C`/`--directory` flag so the empty / version /
    // removed-generate pre-checks classify correctly (see [run]).
    final commandArgs = _stripDirectory(args);
    await _withDirectory(directory, () async {
      _ensureInitialized(args);

      if (commandArgs.isEmpty) {
        _printHelpTo(output.add);
        return;
      }

      if (_isVersionCommand(commandArgs)) {
        output.add('zfa v$version');
        output.add('Zuraffa Code Generator');
        return;
      }

      if (_isRemovedGenerateCommand(commandArgs)) {
        _printRemovedGenerateMessageTo(output.add);
        return;
      }

      await runZoned(
        () async {
          try {
            await _runner.run(args);
          } on UsageException catch (e) {
            output.add('❌ ${e.message}');
            output.add(e.usage);
          } catch (e, stack) {
            output.add('❌ Error: $e');
            _addSuggestionsTo(output.add, e.toString());
            if (args.contains('--verbose') || args.contains('-v')) {
              output.add('\nStack trace:\n$stack');
            }
          }
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );
    });

    return output.isEmpty ? '' : '${output.join('\n')}\n';
  }

  bool _isVersionCommand(List<String> args) {
    return args.length == 1 &&
        (args[0] == '--version' || args[0] == '-v' || args[0] == 'version');
  }

  bool _isRemovedGenerateCommand(List<String> args) {
    return args.isNotEmpty && args.first == 'generate';
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

BOOTSTRAP:
  setup <name>        Create a new Flutter/Dart app with zuraffa deps wired in
  init                Alias of initialize — wire deps + scaffold a test entity
  package create <name>  Create a Zuraffa-native reusable package (spec 025)

CORE COMMANDS:
  make <Name>         Canonical architecture/code generation command
  feature <Name>      Wrapper over `make --preset=feature`
  initialize          Wire zuraffa dependencies + scaffold a test entity
  entity              Create and manage Zorphy entities
  config              Manage ZFA configuration
  doctor              Check your environment and v5 migration readiness
  schema              Output JSON schema
  validate <file>     Validate JSON configuration
  migrate <target>     Migrate v5 artifacts to v6 (state, gql, di)
  build               Run build_runner to generate code from annotations
  update              Check for updates and update the installed CLI

MODULAR COMMANDS:
  module <Name>      Scaffold a new feature package with plugin orchestrator
  feature <Name>      Wrapper over `make --preset=feature`
  route <Name>        Generate route definitions
  view <Name>         Generate View/Presenter/Controller
  di <Name>           Generate dependency injection
  test <Name>         Generate unit tests
  app shell           Generate app shell (main.dart + MyApp + app_router.dart)

OPTIONS:
  -v, --version       Print version
  -h, --help          Show help

Run "zfa <command> --help" for more information.
''');
  }

  void _printRemovedGenerateMessage() {
    _printRemovedGenerateMessageTo(print);
  }

  void _printRemovedGenerateMessageTo(void Function(String) printFn) {
    printFn("❌ The 'generate' command was removed in Zuraffa v5.");
    printFn('   Use `zfa make <Name> ...` for canonical generation.');
    printFn(
      '   Use `zfa feature <Name>` or `zfa feature scaffold <Name>` for the feature wrapper.',
    );
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
  List<String> get aliases => ['init'];

  @override
  String get description =>
      'Wire zuraffa dependencies into pubspec.yaml + scaffold a test entity';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<void> run() async {
    await init.InitializeCommand().execute(argResults!.arguments);
  }
}

class _PluginCommand extends Command<void> {
  @override
  String get name => 'plugin';

  @override
  String get description => 'Manage plugins';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<void> run() async {
    // Use .arguments (not .rest) so flags like `--force` pass through
    // to PluginCommand.execute() — required by `zfa plugin mcp --force`.
    await plugincmd.PluginCommand().execute(argResults!.arguments.toList());
  }
}

class _EntityCommand extends Command<void> {
  @override
  String get name => 'entity';

  @override
  String get description =>
      'Create and manage Zorphy entities (passthrough to zorphy_cli)';

  @override
  List<String> get aliases => ['z'];

  @override
  ArgParser get argParser {
    final parser = ArgParser.allowAnything();
    return parser;
  }

  @override
  Future<void> run() async {
    final allArgs = argResults!.arguments;
    await EntityCommand().execute(allArgs);
  }
}
