import 'dart:convert';
import 'dart:io';

import '../config/zfa_config.dart';

/// Config command - Manage ZFA configuration
class ConfigCommand {
  Future<void> execute(List<String> args) async {
    if (args.isEmpty) {
      _printHelp();
      exit(0);
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
        print('❌ Unknown config command: $command\n');
        _printHelp();
        exit(1);
    }
  }

  Future<void> _handleInit(List<String> args) async {
    final projectRoot = args.isEmpty ? null : args[0];

    if (projectRoot != null && !Directory(projectRoot).existsSync()) {
      print('❌ Directory not found: $projectRoot');
      exit(1);
    }

    await ZfaConfig.init(projectRoot: projectRoot);
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
      print('❌ Usage: zfa config set <key> <value>');
      print('   Example: zfa config set diByDefault true');
      exit(1);
    }

    final key = args[0];
    final value = args[1];
    final projectRoot = Directory.current.path;
    final existing = ZfaConfig.load(projectRoot: projectRoot);

    if (existing == null) {
      print('❌ Configuration file not found.');
      print('   Run "zfa config init" to create one first.');
      exit(1);
    }

    final updated = _updatedConfig(existing, key, value);
    if (updated == null) {
      print('❌ Unknown configuration key: $key');
      print('   Valid keys: ${_supportedKeys().join(', ')}');
      exit(1);
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
  --help, -h          Show this help message

CONFIGURATION KEYS:
  buildByDefault      Auto-run build_runner after entity/cache operations
  formatByDefault     Auto-run dart format after generation
  filterByDefault     Enable type-safe filters for entities by default
  entityFirst         Require entities before entity-aware architecture generation
  <plugin>ByDefault   Enable a plugin by default during plan resolution

EXAMPLES:
  zfa config init
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
