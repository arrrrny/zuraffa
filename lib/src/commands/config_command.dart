import 'dart:convert';
import 'dart:io';

import '../cli/exit_protocol.dart';
import '../config/zfa_config.dart';
import '../core/project/project_root.dart';

/// Config command - Manage ZFA configuration
class ConfigCommand {
  Future<void> execute(List<String> args) async {
    // SPEC 1132 (EPIC 1 honesty sweep): a bare invocation is a usage
    // error — the usage block is printed AND the process must exit the
    // canonical SPEC 917 usage code (2), via `exitCode` (never a hard
    // `exit()`: the runner embeds dispatch in-process and a hard exit
    // would kill the host isolate).
    if (args.isEmpty) {
      _printHelp();
      exitCode = ExitProtocol.usage;
      return;
    }

    final command = args[0];

    switch (command) {
      case 'init':
        await _handleInit(args.skip(1).toList());
        break;
      case 'show':
      case 'get':
        await _handleShow(args.skip(1).toList());
        break;
      case 'set':
        await _handleSet(args.skip(1).toList());
        break;
      case 'help':
      case '--help':
      case '-h':
        _printHelp();
        break;
      default:
        // Unknown subcommand = usage error (SPEC 917): the operation
        // could not run as invoked. Exit class 2 (was the failure 1 of
        // the pre-sweep shape) and return via exitCode.
        print('❌ Unknown config command: $command\n');
        _printHelp();
        exitCode = ExitProtocol.usage;
    }
  }

  Future<void> _handleInit(List<String> args) async {
    // Issue #1496: `zfa config init [--minimal] [projectRoot]` — the
    // --minimal flag is positional-agnostic so an optional project root
    // can still be passed in either order.
    //
    // Review fix: the runner feeds this handler raw args
    // (`ArgParser.allowAnything()` in cli_runner.dart), so `--help` and
    // misspelled flags arrive here instead of being consumed by the
    // parser. Handle help first, then reject anything that is not
    // --minimal/-m — a typo must not silently init the current directory.
    if (args.contains('--help') || args.contains('-h')) {
      _printHelp();
      return;
    }
    final unknownOptions = args.where(
      (arg) => arg.startsWith('-') && arg != '--minimal' && arg != '-m',
    );
    if (unknownOptions.isNotEmpty) {
      print('❌ Unknown init option: ${unknownOptions.first}');
      print('   Usage: zfa config init [--minimal] [projectRoot]');
      print(ExitProtocol.fixLine('pass --minimal (or -m), or drop the flag'));
      exitCode = ExitProtocol.usage;
      return;
    }

    final minimal = args.contains('--minimal') || args.contains('-m');
    final positional = args
        .where((arg) => !arg.startsWith('-'))
        .toList(growable: false);
    final projectRoot = positional.isEmpty ? null : positional.first;

    if (projectRoot != null && !Directory(projectRoot).existsSync()) {
      // Invalid invocation target: usage class (SPEC 917), and returned
      // via exitCode — a hard exit() is embedded-dispatch unsafe
      // (SPEC 1132).
      print('❌ Directory not found: $projectRoot');
      exitCode = ExitProtocol.usage;
      return;
    }

    await ZfaConfig.init(projectRoot: projectRoot, minimal: minimal);
  }

  Future<void> _handleShow(List<String> args) async {
    final projectRoot = args.isEmpty ? null : args[0];
    final config = ZfaConfig.load(projectRoot: projectRoot);

    if (config == null) {
      print('ℹ️  No configuration file found.');
      print('   Run "zfa config init" to create one with defaults.');
      return;
    }

    const encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(config.toJson()));
  }

  Future<void> _handleSet(List<String> args) async {
    if (args.length < 2) {
      // Missing required arguments: usage class (SPEC 917 — the
      // operation could not run as invoked).
      print('❌ Usage: zfa config set <key> <value>');
      print('   Example: zfa config set diByDefault true');
      exitCode = ExitProtocol.usage;
      return;
    }

    final key = args[0];
    final value = args[1];
    final projectRoot = ProjectRoot.safeCurrentPath();
    final existing = ZfaConfig.load(projectRoot: projectRoot);

    if (existing == null) {
      // State precondition (a missing config is not an invocation
      // error): honest failure 1, returned via exitCode (SPEC 1132).
      print('❌ Configuration file not found.');
      print('   Run "zfa config init" to create one first.');
      exitCode = ExitProtocol.failure;
      return;
    }

    // Issue #1596 review: `load` returns a non-null config for an existing but
    // unparseable `.zfa.json` too, so without this guard the write below would
    // replace the user's file with defaults built from `_updatedConfig`.
    final refusal = ZfaConfig.unparseableConfigMessage(
      projectRoot: projectRoot,
    );
    if (refusal != null) {
      // Corrupt/unparseable state: honest failure 1 via exitCode.
      print(refusal);
      exitCode = ExitProtocol.failure;
      return;
    }

    final updated = _updatedConfig(existing, key, value);
    if (updated == null) {
      // Unknown key = an invalid argument: usage class (SPEC 917).
      print('❌ Unknown configuration key: $key');
      print('   Valid keys: ${_supportedKeys().join(', ')}');
      exitCode = ExitProtocol.usage;
      return;
    }

    await ZfaConfig.save(updated, projectRoot: projectRoot);
    print('✅ Updated configuration:');
    print('   • $key: ${_displayValue(updated, key)}');
  }

  ZfaConfig? _updatedConfig(ZfaConfig config, String key, String value) {
    final boolValue = value.toLowerCase() == 'true';
    switch (key) {
      case 'buildByDefault':
        return config.copyWith(buildByDefault: boolValue);
      case 'formatByDefault':
        return config.copyWith(formatByDefault: boolValue);
      case 'filterByDefault':
        return config.copyWith(filterByDefault: boolValue);
      case 'entityFirst':
        return config.copyWith(entityFirst: boolValue);
    }

    final pluginId = ZfaConfig.pluginIdForConfigKey(key);
    if (pluginId == null) {
      return null;
    }

    final defaults = Map<String, bool>.from(config.pluginDefaults);
    defaults[pluginId] = boolValue;
    return config.copyWith(pluginDefaults: defaults);
  }

  dynamic _displayValue(ZfaConfig config, String key) {
    switch (key) {
      case 'buildByDefault':
        return config.buildByDefault;
      case 'formatByDefault':
        return config.formatByDefault;
      case 'filterByDefault':
        return config.filterByDefault;
      case 'entityFirst':
        return config.entityFirst;
      default:
        final pluginId = ZfaConfig.pluginIdForConfigKey(key);
        return pluginId == null
            ? null
            : config.isPluginEnabledByDefault(pluginId);
    }
  }

  List<String> _supportedKeys() {
    final pluginKeys =
        ZfaConfig().pluginDefaults.keys
            .map(ZfaConfig.configKeyForPlugin)
            .toList()
          ..sort();

    return [
      'buildByDefault',
      'entityFirst',
      'filterByDefault',
      'formatByDefault',
      ...pluginKeys,
    ];
  }

  void _printHelp() {
    print('''
zfa config - Manage ZFA configuration

USAGE:
  zfa config <command> [options]

COMMANDS:
  init                Create default configuration file (.zfa.json)
  show, get           Show current configuration
  set <key> <value>   Update a configuration value
  help                Show this help message

OPTIONS:
  init --minimal, -m  Keep every plugin default off (the pre-#1496
                      behaviour) — select plugins per command with
                      --preset=crud or --with=<plugin>
  --help, -h          Show this help message

CONFIGURATION KEYS:
  buildByDefault      Auto-run build_runner after entity/cache operations
  formatByDefault     Auto-run dart format after generation
  filterByDefault     Enable type-safe filters for entities by default
  entityFirst         Require entities before entity-aware architecture generation
  <plugin>ByDefault   Enable a plugin by default during plan resolution

EXAMPLES:
  zfa config init
  zfa config init --minimal
  zfa config show
  zfa config set diByDefault true
  zfa config set repositoryByDefault true
  zfa config set entityFirst true
  zfa config set filterByDefault true

NOTES:
  - Zuraffa v5 is Zorphy-only on public config surfaces.
  - The domain root is fixed to lib/src/domain in v5.
  - Entity output is fixed to lib/src/domain/entities.
  - Plugin defaults are stored under plugins.defaults in .zfa.json.
''');
  }
}
