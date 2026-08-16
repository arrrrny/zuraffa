import 'dart:io';

import '../cli/plugin_loader.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../models/generated_file.dart';
import '../plugins/mcp/capabilities/scaffold_mcp_server_capability.dart';

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
      case 'mcp':
        // `zfa plugin mcp` is an alias for `zfa mcp scaffold` (issue #369).
        // Delegates to the McpPlugin's ScaffoldMcpServerCapability.
        await _scaffoldMcp(args.sublist(1));
        return;
      default:
        print('Unknown plugin command: $action');
        _printHelp();
        exit(1);
    }
  }

  /// Scaffolds a runtime MCP server into the host app via the
  /// McpPlugin's ScaffoldMcpServerCapability. Accepts the same flags
  /// as `zfa mcp scaffold`: --force, --dry-run, --verbose, --revert.
  Future<void> _scaffoldMcp(List<String> rest) async {
    // Ensure the McpPlugin is registered in the singleton registry.
    final registry = PluginRegistry.instance;
    if (!registry.plugins.any((p) => p.id == 'mcp')) {
      // Bootstrap the registry if it's empty (e.g. when invoked outside
      // the normal CliRunner._ensureInitialized() path).
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: false,
        force: false,
        verbose: false,
        config: PluginConfig.load(),
      );
      final loaded = loader.buildRegistry();
      for (final plugin in loaded.plugins) {
        if (!registry.plugins.any((p) => p.id == plugin.id)) {
          registry.register(plugin);
        }
      }
    }

    final mcpPlugin = registry.plugins.firstWhere(
      (p) => p.id == 'mcp',
      orElse: () {
        print('❌ McpPlugin is not registered.');
        exit(1);
      },
    );
    final capability = mcpPlugin.capabilities
        .whereType<ScaffoldMcpServerCapability>()
        .first;
    final result = await capability.execute({
      if (rest.contains('--force')) 'force': true,
      if (rest.contains('--dry-run')) 'dryRun': true,
      if (rest.contains('--verbose')) 'verbose': true,
      if (rest.contains('--revert')) 'revert': true,
    });

    if (result.success) {
      final files = result.data?['generatedFiles'];
      if (files is List<GeneratedFile> && files.isNotEmpty) {
        print('✅ MCP server scaffolded:');
        for (final f in files) {
          print('  ✨ ${f.path}');
        }
      } else {
        print('✅ MCP server scaffold complete (no file changes).');
      }
    } else {
      print('❌ MCP scaffold failed: ${result.message}');
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

    if (engineBlock.trim().isEmpty || !engineBlock.contains('..register')) {
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
      // Find the last complete ..register(...) cascade using balanced parenthesis scanner.
      final absolutePos = _findLastRegisterEnd(
        content,
        engineMatch.end,
        bootstrapMatch.start,
      );
      final lineStart = content.lastIndexOf('\n', absolutePos);
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

  /// Scans content from [start] to [end] for all ..register(...) cascades,
  /// returns the position after the last complete register call's closing parenthesis.
  int _findLastRegisterEnd(String content, int start, int end) {
    final block = content.substring(start, end);
    int lastEnd = -1;
    int pos = 0;

    while (pos < block.length) {
      // Find next ..register
      final registerIdx = block.indexOf('..register(', pos);
      if (registerIdx == -1) break;

      // Scan for matching closing parenthesis
      int parenCount = 1;
      int scanPos = registerIdx + '..register('.length;
      while (scanPos < block.length && parenCount > 0) {
        final ch = block[scanPos];
        if (ch == '(') {
          parenCount++;
        } else if (ch == ')') {
          parenCount--;
        }
        scanPos++;
      }

      if (parenCount == 0) {
        // Found complete register call
        lastEnd = scanPos;
        pos = scanPos;
      } else {
        // Unbalanced parentheses, stop
        break;
      }
    }

    return lastEnd == -1 ? end : (start + lastEnd);
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
    print('  mcp [--force]      Scaffold a runtime MCP server into the host app');
    print('                     (alias for `zfa mcp scaffold`; issue #369)');
  }
}
