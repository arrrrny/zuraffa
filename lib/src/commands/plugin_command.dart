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
          final status = plugin.enabled ? '[\u2713]' : '[ ]';
          print('$status ${plugin.id} - ${plugin.name} (${plugin.version})');
        }
        return;
      case 'enable':
      case 'disable':
        if (args.length < 2) {
          print('Missing plugin id');
          _printHelp();
          exit(1);
        }
        final id = args[1];
        final exists = plugins.any((p) => p.id == id);
        if (!exists) {
          print('Unknown plugin: $id');
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
      case 'add':
        if (args.length < 2) {
          print('Missing package name');
          _printHelp();
          exit(1);
        }
        _addPlugin(args[1]);
        return;
      default:
        print('Unknown plugin command: $action');
        _printHelp();
        exit(1);
    }
  }

  /// Wires a plugin package into main.dart.
  void _addPlugin(String packageName) {
    final mainFile = File('lib/main.dart');
    if (!mainFile.existsSync()) {
      print(
        'Error: lib/main.dart not found. Run from your Flutter project root.',
      );
      exit(1);
    }

    var content = mainFile.readAsStringSync();

    final importLine = "import 'package:$packageName/$packageName.dart';";

    if (content.contains(importLine)) {
      print('Package $packageName is already imported in lib/main.dart.');
      return;
    }

    // Find the last import line and add the new import after it.
    final importRegex = RegExp(r'^import .+;$', multiLine: true);
    final matches = importRegex.allMatches(content);
    if (matches.isEmpty) {
      print('Error: No import statements found in lib/main.dart.');
      exit(1);
    }
    final lastImport = matches.last;
    final insertPos = lastImport.end;
    content =
        '${content.substring(0, insertPos)}\n$importLine${content.substring(insertPos)}';

    // Normalize package name to derive the plugin class name.
    // Convention: zuraffa_feature_example -> FeatureExamplePlugin
    // Convention: custom_plugin -> CustomPlugin
    var baseName = packageName;
    if (baseName.startsWith('zuraffa_feature_')) {
      baseName = baseName.substring('zuraffa_feature_'.length);
    } else if (baseName.startsWith('zuraffa_')) {
      baseName = baseName.substring('zuraffa_'.length);
    }
    final parts = baseName.split('_');
    final className = parts.map((p) => _capitalize(p)).join('');
    final pluginClass = '${className}Plugin';

    // Find the engine registration block and add the plugin.
    // Pattern: locate engine creation, then find ..register calls before bootstrap.
    final enginePattern = RegExp(
      r'(final|var)\s+engine\s*=\s*ZuraffaEngine\(\)',
      multiLine: true,
    );
    final engineMatch = enginePattern.firstMatch(content);
    final bootstrapPattern = RegExp(
      r'await\s+engine\.bootstrap\(\)',
      multiLine: true,
    );
    final bootstrapMatch = bootstrapPattern.firstMatch(content);

    if (engineMatch == null || bootstrapMatch == null) {
      print(
        'Error: Could not find engine creation or bootstrap call in lib/main.dart.',
      );
      print('Please manually add the plugin registration.');
      exit(1);
    }

    // Search for ..register calls between engine creation and bootstrap.
    final engineBlock = content.substring(
      engineMatch.end,
      bootstrapMatch.start,
    );
    final registerPattern = RegExp(r'\.\.register\(.+?\)');
    final registerMatches = registerPattern.allMatches(engineBlock);

    if (registerMatches.isEmpty) {
      // No existing registrations; insert before bootstrap.
      final lineStart = content.lastIndexOf('\n', bootstrapMatch.start);
      final linePrefix = content.substring(lineStart + 1, lineStart + 5);
      final indent = linePrefix.replaceAll(RegExp(r'\S'), ' ');
      final varName = '${_uncapitalize(className)}Plugin';
      final insertion =
          '$indent  final $varName = $pluginClass();\n'
          '$indent  engine\n'
          '$indent    ..register($varName)\n\n';
      content =
          content.substring(0, bootstrapMatch.start) +
          insertion +
          content.substring(bootstrapMatch.start);
    } else {
      // Append to the last ..register call in the engine block.
      final lastRegister = registerMatches.last;
      final absolutePos = engineMatch.end + lastRegister.end;
      final lineStart = content.lastIndexOf(
        '\n',
        engineMatch.end + lastRegister.start,
      );
      final lineContent = content.substring(lineStart + 1);
      final indentMatch = RegExp(r'^(\s+)\.\.register').firstMatch(lineContent);
      final indent = indentMatch?.group(1) ?? '    ';
      final insertion = '\n$indent..register($pluginClass())';
      content =
          content.substring(0, absolutePos) +
          insertion +
          content.substring(absolutePos);
    }

    mainFile.writeAsStringSync(content);
    print('Added plugin $packageName to lib/main.dart.');
    print('  Import: $importLine');
    print('  Registration: engine..register($pluginClass())');
    print('');
    print('Review the changes and ensure the plugin class is correctly named.');
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _uncapitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toLowerCase() + s.substring(1);
  }

  void _printHelp() {
    print('zfa plugin - Manage ZFA plugins\n');
    print('USAGE:');
    print('  zfa plugin <command> [options]\n');
    print('COMMANDS:');
    print('  list               List available plugins');
    print('  enable <id>        Enable a plugin');
    print('  disable <id>       Disable a plugin');
    print('  add <package>      Wire a plugin package into main.dart');
  }
}
