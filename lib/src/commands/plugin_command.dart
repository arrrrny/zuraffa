import 'dart:convert';
import 'dart:io';

import '../cli/exit_protocol.dart';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../cli/plugin_loader.dart';
import '../plugins/plugin_gate/plugin_catalog.dart';
import '../plugins/plugin_gate/plugin_gate.dart';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../models/generated_file.dart';
import '../plugins/mcp/capabilities/scaffold_mcp_server_capability.dart';

class PluginCommand {
  Future<void> execute(List<String> args) async {
    // SPEC 1132 (EPIC 1 honesty sweep): a bare invocation is a usage
    // error (SPEC 917 canonical 2) — the usage block prints AND the
    // exit code says 2. Explicit --help/-h stays a success (exit 0).
    if (args.isEmpty) {
      _printHelp();
      exitCode = ExitProtocol.usage;
      return;
    }
    if (args.first == '--help' || args.first == '-h') {
      _printHelp();
      return;
    }

    final action = args.first;
    // Extract an optional --root so tests (and advanced users) can target an
    // explicit project root instead of relying on the process working
    // directory (issue: non-hermetic CLI tests under `dart test`). Shared by
    // the `add`, `enable` and `disable` arms; `mcp` parses its own flags.
    String? root;
    final rest = <String>[];
    for (var i = 1; i < args.length; i++) {
      if (args[i] == '--root' && i + 1 < args.length) {
        root = args[i + 1];
        i++;
      } else {
        rest.add(args[i]);
      }
    }
    final config = PluginConfig.load(projectRoot: root);
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
        // Spec 1653 (issue #1661): the optional heavy capabilities and
        // their companion packages — always listed, never a failure.
        print('');
        print('Optional capabilities:');
        for (final entry in PluginCatalog.all) {
          final enabled = PluginGate.isEnabled(entry.name, projectRoot: root);
          final resolvable = PluginGate.isResolvable(
            entry.package,
            projectRoot: root,
          );
          final state = enabled ? 'enabled ' : 'disabled';
          final pkg = resolvable ? 'resolvable' : 'not added';
          print('$state  ${entry.name}  package: ${entry.package}  ($pkg)');
        }
        return;
      case 'enable':
      case 'disable':
        if (rest.isEmpty) {
          // Missing required argument: usage class (SPEC 917), returned
          // via exitCode — a hard exit() is embedded-dispatch unsafe
          // (SPEC 1132).
          print('Missing plugin id');
          _printHelp();
          exitCode = ExitProtocol.usage;
          return;
        }
        final id = rest.first;
        final capability = PluginCatalog.find(id);
        final exists = plugins.any((p) => p.id == id);
        if (capability == null && !exists) {
          print('Unknown plugin: $id');
          final names = PluginCatalog.all.map((e) => e.name).join(', ');
          print('   Optional capabilities: $names');
          // Embedded-dispatch safe (the runner unwinds via exitCode):
          exitCode = ExitProtocol.usage;
          return;
        }
        // Spec 1653 (issue #1661): the capability facet — persisted in
        // `.zfa.json` `capabilities:` additively, idempotent on enable.
        if (capability != null) {
          final caps = PluginGate.readCapabilities(projectRoot: root);
          if (action == 'enable' && caps[id] == true) {
            print('already enabled: $id');
            final refusal = PluginGate.refusalFor(
              id,
              projectRoot: root,
              capabilities: caps,
            );
            if (refusal != null) {
              print('   $refusal');
            }
            return;
          }
        }
        if (exists) {
          if (action == 'enable') {
            config.disabled.remove(id);
          } else {
            config.disabled.add(id);
          }
          // Issue #1586: the save is asynchronous and the CLI runner exits
          // immediately after this command returns — it must be awaited or
          // the persisted `.zfa.json` never sees the mutation. A refused save
          // (an existing `.zfa.json` that could not be parsed) must not be
          // reported as success.
          if (!await config.save(projectRoot: root)) {
            exit(1);
          }
        }
        if (capability != null) {
          await _writeCapability(id, enabled: action == 'enable', root: root);
        }
        final verb = action == 'enable' ? 'Enabled' : 'Disabled';
        print('$verb plugin: $id');
        if (capability != null && action == 'enable') {
          final resolvable = PluginGate.isResolvable(
            capability.package,
            projectRoot: root,
          );
          if (!resolvable) {
            print(
              '   Add package:${capability.package} to pubspec.yaml and '
              'run dart pub get to finish enabling ${capability.name}.',
            );
          }
        }
        return;
      case 'add':
        if (rest.isEmpty) {
          print('Missing package name');
          _printHelp();
          exit(1);
        }
        _addPlugin(rest.first, root: root);
        return;
      case 'mcp':
        // `zfa plugin mcp` is an alias for `zfa mcp scaffold` (issue #369).
        // Delegates to the McpPlugin's ScaffoldMcpServerCapability.
        await _scaffoldMcp(args.sublist(1));
        return;
      default:
        // Unknown subcommand = usage error (SPEC 917): exit class 2
        // (was the failure 1 of the pre-sweep shape).
        print('Unknown plugin command: $action');
        _printHelp();
        exitCode = ExitProtocol.usage;
    }
  }

  /// Spec 1653 (issue #1661): persist `capabilities.<name>` in the
  /// project's `.zfa.json` — a RAW additive read-modify-write so every
  /// other key survives untouched.
  Future<void> _writeCapability(
    String name, {
    required bool enabled,
    String? root,
  }) async {
    final dir = root ?? Directory.current.path;
    final file = File(p.join(dir, '.zfa.json'));
    var doc = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        final Object? decoded = jsonDecode(file.readAsStringSync());
        if (decoded is! Map<String, dynamic>) {
          print('❌ .zfa.json is not valid JSON — fix or re-init it first.');
          exit(1);
        }
        doc = decoded;
      } on FormatException {
        print('❌ .zfa.json is not valid JSON — fix or re-init it first.');
        exit(1);
      }
    }
    final rawSection = doc['capabilities'];
    final section = Map<String, dynamic>.from(
      rawSection is Map<String, dynamic> ? rawSection : <String, dynamic>{},
    );
    section[name] = enabled;
    doc['capabilities'] = section;
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync(encoder.convert(doc));
  }

  /// Scaffolds a runtime MCP server into the host app via the
  /// McpPlugin's ScaffoldMcpServerCapability. Accepts the same flags
  /// as `zfa mcp scaffold`: --force, --dry-run, --verbose, --revert,
  /// plus --name.
  Future<void> _scaffoldMcp(List<String> rest) async {
    // Parse rest with the same ArgParser convention as the zfa mcp
    // scaffold entrypoint, so equivalent short/long/boolean-value and
    // name-value forms are all accepted.
    final parser = ArgParser()
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite existing files',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Preview without writing files',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Enable detailed logging',
      )
      ..addFlag('revert', negatable: false, help: 'Delete the scaffolded files')
      ..addOption('name', help: 'Optional name for the MCP server')
      ..addOption(
        'root',
        help:
            'Project root to scaffold the MCP server in (default: current '
            'directory). Lets tests run against an explicit sandbox instead of '
            'relying on the process working directory.',
      );
    ArgResults parsed;
    try {
      parsed = parser.parse(rest);
    } on FormatException catch (e) {
      print('❌ Invalid mcp scaffold arguments: ${e.message}');
      exit(1);
    }
    final dryRun = parsed['dry-run'] == true;
    final force = parsed['force'] == true;
    final verbose = parsed['verbose'] == true;
    final root = parsed['root'] as String?;

    // Ensure the McpPlugin is registered in the singleton registry.
    final registry = PluginRegistry.instance;
    if (!registry.plugins.any((p) => p.id == 'mcp')) {
      // Bootstrap the registry if it's empty (e.g. when invoked outside
      // the normal CliRunner._ensureInitialized() path), forwarding the
      // caller's parsed flags so the registered McpPlugin's
      // GeneratorOptions and output path match the invocation.
      final loader = PluginLoader(
        outputDir: 'lib/src',
        dryRun: dryRun,
        force: force,
        verbose: verbose,
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
        if (PluginConfig.load().disabled.contains('mcp')) {
          print(
            '❌ The mcp plugin is disabled. Run `zfa plugin enable mcp` '
            'to enable it.',
          );
          exit(1);
        }
        print('❌ McpPlugin is not registered.');
        exit(1);
      },
    );
    final capability = mcpPlugin.capabilities
        .whereType<ScaffoldMcpServerCapability>()
        .first;
    // Issue #1138: route the standalone invocation through the
    // CapabilityInvocationWrapper so a successful run persists its
    // proof.v1 receipt (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: mcpPlugin.id,
    );
    final result = await wrapper.execute({
      if (force) 'force': true,
      if (dryRun) 'dryRun': true,
      if (verbose) 'verbose': true,
      'root': root,
      if (parsed['revert'] == true) 'revert': true,
      if (parsed['name'] != null) 'name': parsed['name'] as String,
    });

    if (result.success) {
      final files =
          (result.data?['generatedFiles'] as List<GeneratedFile>?) ??
          const <GeneratedFile>[];
      if (files.isNotEmpty) {
        if (dryRun) {
          print('✅ MCP server plan (dry run) — would scaffold:');
        } else {
          print('✅ MCP server scaffolded:');
        }
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
  ///
  /// [root] is the project root to operate in (defaults to the current
  /// directory). Tests and advanced users pass it explicitly so the command
  /// is hermetic and does not depend on the process working directory.
  void _addPlugin(String packageName, {String? root}) {
    final mainFile = File(
      p.join(root ?? Directory.current.path, 'lib', 'main.dart'),
    );
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
    print(
      '  mcp [--force]      Scaffold a runtime MCP server into the host app',
    );
    print('                     (alias for `zfa mcp scaffold`; issue #369)');
  }
}
