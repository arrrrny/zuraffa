import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import '../commands/schema_command.dart';
import '../commands/simulate_command.dart';
import '../commands/skin_command.dart';
import '../commands/ui_command.dart';
import '../commands/validate_command.dart';
import '../commands/create_command.dart' as create;
import '../commands/config_command.dart' as config;
import '../commands/corpus_command.dart';
import '../commands/dream_command.dart';
import '../commands/initialize_command.dart' as init;
import '../commands/entity_command.dart';
import '../commands/plugin_command.dart' as plugincmd;
import '../commands/make_command.dart';
import '../commands/doctor_command.dart';
import '../commands/proof_command.dart';
import '../commands/migrate_command.dart';
import '../commands/update_command.dart';
import '../commands/build_command.dart';
import '../commands/manifest_command.dart';
import '../commands/generate_commands_command.dart';
import '../commands/apply_command.dart';
import '../commands/module_command.dart';
import '../commands/xray_command.dart';
import '../commands/setup_command.dart';
import '../commands/replay_command.dart';
import '../commands/tdd_command.dart';
import '../commands/app_shell_command.dart';
import '../commands/package_command.dart';
import '../commands/engine_command.dart';
import '../core/plugin_system/cli_aware_plugin.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../plugins/tdd/tdd_plugin.dart';
import '../core/error/suggestion_engine.dart';
import '../version.dart';
import 'plugin_loader.dart';
import '../commands/agent_command.dart';
import '../commands/zap_command.dart';

/// CLI runner for Zuraffa.
class CliRunner {
  final bool exitOnCompletion;
  late CommandRunner<void> _runner;
  bool _coreInitialized = false;

  /// Plugin commands are registered separately from the core commands so a
  /// prior plugin-free command (e.g. `xray`) that skips the plugin boot does
  /// not prevent a later plugin-backed command from being registered in a
  /// reused [CliRunner] (issue #531 regression).
  bool _pluginsInitialized = false;

  /// Directory the currently-registered commands were initialized against.
  /// When a new invocation targets a different directory (e.g. a reused
  /// [CliRunner] called with another `-C`), the root-bound commands are torn
  /// down and rebuilt so they resolve the correct project root (CodeRabbit
  /// review of #623). `null` until the first initialization.
  String? _initializedDirectory;

  /// Guard against overlapping `run`/`runCapturing` calls on the same instance.
  /// The scoped chdir in [_withDirectory] mutates the process-wide
  /// `Directory.current`; concurrent invocations would race on it. We reject
  /// same-instance re-entrancy with a clear error. Cross-ISOLATE overlaps
  /// (two `dart test` suites, each driving its own [CliRunner] in one VM)
  /// are handled by the lock file in [_withDirectory] — this per-instance
  /// flag cannot see another suite's runner.
  bool _active = false;

  /// The exit code the LAST [runCapturing] invocation on this isolate
  /// dispatched, snapshotted per-isolate.
  ///
  /// `dart:io exitCode` is PROCESS-GLOBAL — `dart test` runs test files
  /// as concurrent isolates of one process, so a sibling suite's command
  /// finishing between this run's teardown and the caller's
  /// `expect(exitCode, ...)` read clobbers the value this invocation
  /// produced (the same cross-suite shared-state family as the
  /// `Directory.current` race, issue #1096). The `finally` re-apply
  /// below narrows that window to a few instructions but cannot close
  /// it. [lastDispatchedExitCode] is a Dart static — per-isolate
  /// storage — so callers that need the HERMETIC value read this
  /// instead of the global. Set on every [runCapturing] exit path.
  static int lastDispatchedExitCode = 0;

  CliRunner({this.exitOnCompletion = true}) : _runner = _buildRunner();

  static CommandRunner<void> _buildRunner() =>
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
  static const Set<String> _noPluginCommands = {'xray', 'proof'};

  void _ensureInitialized(List<String> args, {required String? directory}) {
    // If the active project directory changed since the last initialization
    // (e.g. a reused CliRunner invoked with a different `-C`), the previously
    // constructed root-bound commands (MakeCommand, etc.) still hold the stale
    // project root. Tear them down and rebuild against the new directory.
    //
    // We rebuild the CommandRunner (not re-add to the existing one) so the
    // re-init does not throw "command already exists" — the previous commands
    // remain registered on the old runner instance (CodeRabbit review of #623).
    final effectiveDir = directory ?? Directory.current.path;
    if (effectiveDir != _initializedDirectory) {
      _coreInitialized = false;
      _pluginsInitialized = false;
      _runner = _buildRunner();
      _initializedDirectory = effectiveDir;
    }

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
    _runner.addCommand(EngineCommand());
    _runner.addCommand(DoctorCommand());
    _runner.addCommand(ProofCommand());
    _runner.addCommand(MigrateCommand());
    _runner.addCommand(BuildCommand());
    _runner.addCommand(ManifestCommand(registry));
    _runner.addCommand(GenerateCommandsCommand(registry));
    _runner.addCommand(ApplyCommand(registry));
    _runner.addCommand(ModuleCommand());
    _runner.addCommand(XrayCommand());
    _runner.addCommand(UpdateCommand());
    _runner.addCommand(SetupCommand());
    _runner.addCommand(CorpusCommand());
    _runner.addCommand(TddCommand(TddPlugin()));
    _runner.addCommand(ReplayCommand());
    _runner.addCommand(DreamCommand());
    _runner.addCommand(AppCommand());
    _runner.addCommand(UiCommand());
    _runner.addCommand(PackageCommand());
    _runner.addCommand(SimulateCommand());
    // Issue #1102: runtime skin-contract auditor command group
    // (skin kit / skin verify).
    _runner.addCommand(SkinCommand());
    _runner.addCommand(AgentCommand());
    _runner.addCommand(ZapCommand());
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
    if (_active) {
      throw StateError(
        'CliRunner.run/runCapturing is not reentrant: do not invoke '
        'concurrently on the same instance (overlapping Directory.current '
        'changes would race).',
      );
    }
    _active = true;
    try {
      final directory = _extractDirectory(args);
      // Strip the global `-C`/`--directory` flag before the pre-dispatch checks
      // (empty / version / removed-generate) so that `zfa -C <dir> help` and
      // `zfa -C <dir> generate ...` are classified correctly even though `-C`
      // shifts `args.first` / `args.isEmpty`.
      final commandArgs = _stripDirectory(args);
      await _withDirectory(directory, () async {
        _ensureInitialized(args, directory: directory);

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
    } finally {
      _active = false;
    }
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
  /// The whole chdir window (capture `saved` → chdir → body → restore) is
  /// serialized across isolates through [_cwdLockFile] (issue #1096):
  /// `dart test` runs suites as concurrent isolates of ONE process, and
  /// `Directory.current` is process-wide. Without the lock, suite B can
  /// capture `saved` while suite A's window is open (B then restores the
  /// process into A's temp root), and every relative write A performs while
  /// B's window overlaps lands in B's root — the observed service-verdict
  /// flake. Suites that never pass `-C` never touch the lock, so parallel
  /// execution of other suites is unaffected.
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
    await _acquireCwdLock();
    try {
      final saved = Directory.current;
      Directory.current = p.absolute(directory);
      try {
        await body();
      } finally {
        // `Directory.current` is PROCESS-WIDE while the test runner executes
        // suites as concurrent isolates in one VM. Between the capture above
        // and this restore, another isolate can legitimately delete the saved
        // directory (its own temp-dir teardown) — restoring to it then throws
        // PathNotFoundException inside an UNRELATED test (observed as a flaky
        // U19 in setup_corpus_specs_test once the #767 suites changed suite
        // scheduling). Walk up to the nearest ancestor that still exists
        // instead of failing; the root always exists.
        Directory.current = nearestExistingDirectory(saved.path);
      }
    } finally {
      // Release only AFTER the restore so the next window captures a stable
      // process CWD (the restore is part of the critical section).
      _releaseCwdLock();
    }
  }

  /// Cross-isolate lock guarding the [_withDirectory] chdir window.
  ///
  /// Keyed by PID on purpose: the race only exists WITHIN one process (each
  /// process owns a private working directory), and all dart-test suite
  /// isolates share the runner process's PID, so they contend on one file —
  /// exactly the mutual exclusion needed. A spawned `zfa` CLI runs in its
  /// own process, gets its own lock file, and can never deadlock against
  /// its parent. The lock lives in the system temp dir so it works for any
  /// checkout and needs no writable project state.
  static File get _cwdLockFile =>
      File(p.join(Directory.systemTemp.path, 'zfa_cwd_lock_$pid.lock'));

  /// Acquires the cross-isolate chdir lock, waiting up to 30 seconds for the
  /// current holder. Exclusive-create (`File.createSync(exclusive: true)`)
  /// is the atomic serialization point; it works across isolates AND
  /// processes, unlike `RandomAccessFile.lock` (POSIX fcntl locks are
  /// per-process and cannot arbitrate between isolates of one VM).
  static Future<void> _acquireCwdLock() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var lockBroken = false;
    while (true) {
      try {
        _cwdLockFile.createSync(exclusive: true);
        return;
      } on FileSystemException {
        final expired = DateTime.now().isAfter(deadline);
        if (!expired) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          continue;
        }
        if (!lockBroken) {
          // The holder most likely died mid-window (its isolate killed by a
          // test timeout, leaving a stale file behind for every later
          // window of this process). Break the stale lock once rather than
          // stall the rest of the run.
          lockBroken = true;
          try {
            _cwdLockFile.deleteSync();
          } on FileSystemException {
            // Unbreakable (e.g. a foreign user's file) — fall through to
            // degraded mode below.
          }
          continue;
        }
        // Degraded mode: proceed without exclusivity (the pre-#1096
        // behavior) instead of failing every later invocation forever.
        return;
      }
    }
  }

  /// Releases the cross-isolate chdir lock. Best-effort: a lost release
  /// only costs the next window one 30s wait before it breaks the stale
  /// file.
  static void _releaseCwdLock() {
    try {
      _cwdLockFile.deleteSync();
    } on FileSystemException {
      // Already gone (another waiter broke a stale lock).
    }
  }

  /// Returns [path] if it exists on disk, otherwise the nearest ancestor
  /// that does (falling back to the filesystem root). Used by the `-C`
  /// scope restore so a concurrently-deleted working directory cannot
  /// crash an unrelated invocation.
  static String nearestExistingDirectory(String path) {
    var dir = Directory(path);
    while (!dir.existsSync()) {
      final parentPath = dir.parent.path;
      if (parentPath == dir.path) break; // filesystem root reached
      dir = Directory(parentPath);
    }
    return dir.path;
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
    if (_active) {
      throw StateError(
        'CliRunner.run/runCapturing is not reentrant: do not invoke '
        'concurrently on the same instance (overlapping Directory.current '
        'changes would race).',
      );
    }
    _active = true;
    // Reset the global exitCode so each runCapturing invocation is
    // hermetic — `dart:io exit(N)` inside the dispatched command sets
    // exitCode and would otherwise leak across runs (a prior test
    // calling `exit(2)` from `create_command.dart` would poison every
    // later test that reads `exitCode`). The runner's own exit status
    // is preserved through the `_runDispatched` path, which uses its
    // own `_exit(exitCode)` to honor whatever the command set.
    exitCode = 0;
    // Spec 1008: dart:io's exitCode is PROCESS-GLOBAL, not per-isolate —
    // `dart test` runs test files as concurrent isolates of one process,
    // so a sibling isolate's command finishing between this run's
    // dispatch and the caller's `exitCode` read clobbers the value this
    // invocation produced. Snapshot the dispatched code and re-apply it
    // as the last operation before returning, restoring the hermeticity
    // the reset above promises (the residual window is a few
    // instructions instead of the whole teardown).
    var dispatchedExitCode = 0;
    final output = <String>[];
    try {
      final directory = _extractDirectory(args);
      // Strip the global `-C`/`--directory` flag so the empty / version /
      // removed-generate pre-checks classify correctly (see [run]).
      final commandArgs = _stripDirectory(args);
      await _withDirectory(directory, () async {
        _ensureInitialized(args, directory: directory);

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
              dispatchedExitCode = exitCode;
            } on UsageException catch (e) {
              output.add('❌ ${e.message}');
              output.add(e.usage);
              dispatchedExitCode = 64;
            } catch (e, stack) {
              output.add('❌ Error: $e');
              _addSuggestionsTo(output.add, e.toString());
              if (args.contains('--verbose') || args.contains('-v')) {
                output.add('\nStack trace:\n$stack');
              }
              dispatchedExitCode = 1;
            }
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              output.add(line);
            },
          ),
        );
      });
    } finally {
      _active = false;
      // Re-apply this invocation's own exit code AFTER the teardown (the
      // CWD restore, the zone unwind) — the narrowest window a sibling
      // isolate can clobber.
      exitCode = dispatchedExitCode;
      // The hermetic snapshot: per-isolate static, immune to the sibling
      // clobber the global re-apply above stays exposed to (bug #1107).
      lastDispatchedExitCode = dispatchedExitCode;
    }

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
  corpus import <dir> Import an extracted spec corpus (spec 050, issue #627)
  corpus catalog      Classify a corpus target's specs CORE/SKIN (epic #1017)
  corpus run          Walk the corpus under a failure budget (epic #1017)
  corpus ledger       Record the walk ledger; regressions are CI failures

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
