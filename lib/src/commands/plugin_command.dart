import 'dart:io';

import '../cli/plugin_loader.dart';

class PluginCommand {
  Future<void> execute(List<String> args) async {
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      _printHelp();
      return;
    }

    final action = args.first;
    final config = PluginConfig.load();
    final loader = PluginLoader(
      outputDir: 'lib/src',
      dryRun: false,
      force: false,
      verbose: false,
      config: config,
    );
    final plugins = loader.listPlugins();

    switch (action) {
      case 'list':
        for (final plugin in plugins) {
          final status = plugin.enabled ? '[✓]' : '[ ]';
          print('$status ${plugin.id} - ${plugin.name} (${plugin.version})');
        }
        return;
      case 'enable':
      case 'disable':
        if (args.length < 2) {
          print('❌ Missing plugin id');
          _printHelp();
          exit(1);
        }
        final id = args[1];
        final exists = plugins.any((p) => p.id == id);
        if (!exists) {
          print('❌ Unknown plugin: $id');
          exit(1);
        }
        if (action == 'enable') {
          config.disabled.remove(id);
        } else {
          config.disabled.add(id);
        }
        config.save();
        final verb = action == 'enable' ? 'Enabled' : 'Disabled';
        print('$verb plugin: $id');
        return;
      default:
        print('❌ Unknown plugin command: $action');
        _printHelp();
        exit(1);
    }
  }

  void _printHelp() {
    print('''
zfa plugin - Manage ZFA plugins

USAGE:
  zfa plugin <command> [options]

COMMANDS:
  list               List available plugins
  enable <id>        Enable a plugin
  disable <id>       Disable a plugin
''');
  }
}
