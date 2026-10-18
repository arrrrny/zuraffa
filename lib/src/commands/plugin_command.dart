import 'dart:convert';
import 'dart:io';

import '../cli/exit_protocol.dart';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../cli/plugin_loader.dart';
import '../plugins/plugin_gate/plugin_catalog.dart';
import '../plugins/plugin_gate/plugin_gate.dart';
import '../plugins/registry/plugin_manifest.dart';
import '../plugins/registry/plugin_registry_index.dart';
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
            // SPEC 1132 / EPIC 1 (FR-1): every `plugin` error path unwinds
            // through `exitCode` — a hard exit() kills the host isolate
            // under in-process (MCP/embedded) dispatch.
            exitCode = ExitProtocol.failure;
            return;
          }
        }
        if (capability != null) {
          final written = await _writeCapability(
            id,
            enabled: action == 'enable',
            root: root,
          );
          if (!written) {
            exitCode = ExitProtocol.failure;
            return;
          }
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
          // Missing required argument = usage class (SPEC 917), returned
          // via exitCode — embedded-dispatch safe (SPEC 1132 FR-1).
          print('Missing package name');
          _printHelp();
          exitCode = ExitProtocol.usage;
          return;
        }
        _addPlugin(rest.first, root: root);
        return;
      case 'mcp':
        // `zfa plugin mcp` is an alias for `zfa mcp scaffold` (issue #369).
        // Delegates to the McpPlugin's ScaffoldMcpServerCapability.
        await _scaffoldMcp(args.sublist(1));
        return;
      case 'search':
        await _search(rest, root: root);
        return;
      case 'install':
        await _install(rest, root: root, dryRun: args.contains('--dry-run'));
        return;
      case 'verify':
        await _verify(rest, root: root);
        return;
      case 'publish':
        await _publish(rest, root: root);
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
  ///
  /// Returns `false` (without touching the file) when `.zfa.json` exists
  /// but cannot be parsed — the caller reports the failure through
  /// `exitCode` rather than hard-exiting (SPEC 1132 FR-1).
  Future<bool> _writeCapability(
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
          return false;
        }
        doc = decoded;
      } on FormatException {
        print('❌ .zfa.json is not valid JSON — fix or re-init it first.');
        return false;
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
    return true;
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
      exitCode = ExitProtocol.failure;
      return;
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

    // SPEC 1132 / EPIC 1 (FR-1): an unresolvable mcp plugin is reported
    // through `exitCode`, not a hard exit() — `firstWhere`'s `orElse`
    // cannot unwind the command, so the miss is handled explicitly.
    final mcpPlugins = registry.plugins.where((p) => p.id == 'mcp');
    if (mcpPlugins.isEmpty) {
      if (PluginConfig.load().disabled.contains('mcp')) {
        print(
          '❌ The mcp plugin is disabled. Run `zfa plugin enable mcp` '
          'to enable it.',
        );
      } else {
        print('❌ McpPlugin is not registered.');
      }
      exitCode = ExitProtocol.failure;
      return;
    }
    final mcpPlugin = mcpPlugins.first;
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
      exitCode = ExitProtocol.failure;
      return;
    }
  }

  /// Wires a plugin package into main.dart.
  ///
  /// [root] is the project root to operate in (defaults to the current
  /// directory). Tests and advanced users pass it explicitly so the command
  /// is hermetic and does not depend on the process working directory.
  ///
  /// Every refusal sets `exitCode` and returns instead of hard-exiting
  /// (SPEC 1132 FR-1) — the caller returns immediately after this call, so
  /// the process exit code carries the failure without killing an
  /// embedded host isolate.
  void _addPlugin(String packageName, {String? root}) {
    final mainFile = File(
      p.join(root ?? Directory.current.path, 'lib', 'main.dart'),
    );
    if (!mainFile.existsSync()) {
      print(
        'Error: lib/main.dart not found. Run from your Flutter project root.',
      );
      exitCode = ExitProtocol.failure;
      return;
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
      exitCode = ExitProtocol.failure;
      return;
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
      exitCode = ExitProtocol.failure;
      return;
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

  Future<void> _search(List<String> rest, {String? root}) async {
    String? registryPath;
    String query = '';
    for (var i = 0; i < rest.length; i++) {
      if (rest[i] == '--registry' && i + 1 < rest.length) {
        registryPath = rest[i + 1];
        i++;
      } else if (!rest[i].startsWith('--')) {
        query = rest[i];
      }
    }
    registryPath ??= _defaultRegistryPath(root);
    final index = PluginRegistryIndex.load(registryPath);
    final q = query.toLowerCase();
    final matches = index.plugins.where((e) {
      if (q.isEmpty) return true;
      return e.id.toLowerCase().contains(q) ||
          e.name.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
    print('Plugin registry ($registryPath):');
    if (matches.isEmpty) {
      print('  (no plugins found)');
      return;
    }
    for (final e in matches) {
      print('  ${e.id} ${e.version} - ${e.name}');
      if (e.description.isNotEmpty) print('      ${e.description}');
    }
  }

  Future<void> _install(
    List<String> rest, {
    String? root,
    bool dryRun = false,
  }) async {
    // Parse flags.
    String? registryPath;
    String? target;
    var dry = dryRun;
    final positional = <String>[];
    for (var i = 0; i < rest.length; i++) {
      final a = rest[i];
      if (a == '--registry' && i + 1 < rest.length) {
        registryPath = rest[i + 1];
        i++;
      } else if (a == '--dry-run') {
        dry = true;
      } else if (!a.startsWith('--')) {
        positional.add(a);
      }
    }
    if (positional.isEmpty) {
      print('Missing plugin name or path');
      _printHelp();
      exitCode = ExitProtocol.usage;
      return;
    }
    target = positional.first;
    final projectRoot = root ?? Directory.current.path;

    // Resolve manifest: path first, then registry.
    PluginManifest? manifest;
    String? manifestSourcePath;
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      manifest = loadManifest(target);
      manifestSourcePath = target;
    }
    if (manifest == null) {
      registryPath ??= _defaultRegistryPath(root);
      final index = PluginRegistryIndex.load(registryPath);
      PluginRegistryEntry? entry;
      for (final e in index.plugins) {
        if (e.id == target || e.name == target) {
          entry = e;
          break;
        }
      }
      if (entry != null && entry.manifestPath.isNotEmpty) {
        // Resolve relative to registry file dir.
        var mp = entry.manifestPath;
        if (!p.isAbsolute(mp)) {
          mp = p.join(p.dirname(registryPath), mp);
        }
        manifest = loadManifest(mp);
        manifestSourcePath = mp;
      }
    }
    if (manifest == null) {
      print('❌ Plugin not found: $target');
      exitCode = ExitProtocol.failure;
      return;
    }

    // Verify signature.
    if (!manifest.verify()) {
      print('❌ Signature verification failed for ${manifest.id}');
      exitCode = ExitProtocol.failure;
      return;
    }
    print('✅ Signature verified: ${manifest.id}');

    // Capability diff.
    print('');
    print('Capability diff for ${manifest.id} (${manifest.version}):');
    print('  Write paths:');
    for (final w in manifest.writePaths) {
      print('    + $w');
    }
    print('  Commands:');
    for (final c in manifest.commands) {
      print('    + $c');
    }
    print('  Tools:');
    for (final t in manifest.tools) {
      print('    + $t');
    }

    // Undeclared write paths check: enumerate files in the plugin's source dir.
    // Runs in dry-run too (read-only) so previews surface undeclared files.
    String? sourceDir;
    if (FileSystemEntity.typeSync(target) == FileSystemEntityType.directory) {
      sourceDir = target;
    } else if (manifestSourcePath != null) {
      final msPath = manifestSourcePath;
      final t = FileSystemEntity.typeSync(msPath);
      if (t == FileSystemEntityType.directory) {
        sourceDir = msPath;
      } else if (t == FileSystemEntityType.file) {
        sourceDir = p.dirname(msPath);
      }
    }
    if (sourceDir != null &&
        FileSystemEntity.typeSync(sourceDir) ==
            FileSystemEntityType.directory) {
      final undeclared = <String>[];
      final dir = Directory(sourceDir);
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: sourceDir);
        if (rel == 'manifest.json') continue;
        final declared = manifest.writePaths.any((wp) {
          final prefix = wp.endsWith('/') ? wp : '$wp/';
          return rel == wp || rel.startsWith(prefix);
        });
        if (!declared) undeclared.add(rel);
      }
      if (undeclared.isNotEmpty) {
        print('');
        print('❌ Installing plugin with undeclared write paths fails:');
        for (final u in undeclared) {
          print('   - $u');
        }
        exitCode = ExitProtocol.failure;
        return;
      }
    }

    if (dry) {
      print('');
      print('(dry run — no changes applied)');
      return;
    }

    // Conflict check: overlapping commands with installed plugins.
    final conflicts = _detectCommandConflicts(manifest, projectRoot);
    if (conflicts.isNotEmpty) {
      print('');
      print('❌ Command conflict detected:');
      for (final c in conflicts) {
        print('   - $c');
      }
      print('');
      print('Resolution report:');
      print('  Overlapping commands must be resolved by disabling one plugin');
      print('  or renaming the conflicting command before install.');
      exitCode = ExitProtocol.failure;
      return;
    }

    // Record provenance in .zfa.json.
    final configFile = File(p.join(projectRoot, '.zfa.json'));
    var doc = <String, dynamic>{};
    if (configFile.existsSync()) {
      try {
        final decoded = jsonDecode(configFile.readAsStringSync());
        if (decoded is Map<String, dynamic>) doc = decoded;
      } catch (_) {}
    }
    final installed = Map<String, dynamic>.from(
      doc['installed_plugins'] is Map ? doc['installed_plugins'] as Map : {},
    );
    installed[manifest.id] = {
      'version': manifest.version,
      'manifest': manifest.toJson(),
    };
    doc['installed_plugins'] = installed;
    configFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(doc),
    );
    print('');
    print('✅ Installed plugin: ${manifest.id}');
  }

  Future<void> _verify(List<String> rest, {String? root}) async {
    String? target;
    for (final a in rest) {
      if (!a.startsWith('--')) target = a;
    }
    if (target == null) {
      print('Missing plugin path or name');
      _printHelp();
      exitCode = ExitProtocol.usage;
      return;
    }
    PluginManifest? manifest;
    if (FileSystemEntity.typeSync(target) != FileSystemEntityType.notFound) {
      manifest = loadManifest(target);
    } else {
      // try registry
      final registryPath = _defaultRegistryPath(root);
      final index = PluginRegistryIndex.load(registryPath);
      for (final e in index.plugins) {
        if (e.id == target || e.name == target) {
          var mp = e.manifestPath;
          if (!p.isAbsolute(mp)) mp = p.join(p.dirname(registryPath), mp);
          manifest = loadManifest(mp);
          break;
        }
      }
    }
    if (manifest == null) {
      print('❌ Plugin not found: $target');
      exitCode = ExitProtocol.failure;
      return;
    }
    if (manifest.verify()) {
      print('✅ Verification passed: ${manifest.id} (${manifest.version})');
    } else {
      print('❌ Verification failed: ${manifest.id}');
      exitCode = ExitProtocol.failure;
    }
  }

  Future<void> _publish(List<String> rest, {String? root}) async {
    print('Publish: not yet implemented in v0');
  }

  List<String> _detectCommandConflicts(
    PluginManifest manifest,
    String projectRoot,
  ) {
    final conflicts = <String>[];
    final configFile = File(p.join(projectRoot, '.zfa.json'));
    if (!configFile.existsSync()) return conflicts;
    try {
      final decoded = jsonDecode(configFile.readAsStringSync());
      if (decoded is! Map<String, dynamic>) return conflicts;
      final installed = decoded['installed_plugins'];
      if (installed is! Map) return conflicts;
      for (final entry in installed.entries) {
        final m = (entry.value as Map?)?['manifest'];
        if (m is! Map<String, dynamic>) continue;
        final other = PluginManifest.fromJson(m);
        for (final cmd in manifest.commands) {
          if (other.commands.contains(cmd)) {
            conflicts.add(
              '$cmd provided by both ${manifest.id} and ${other.id}',
            );
          }
        }
      }
    } catch (_) {}
    return conflicts;
  }

  String _defaultRegistryPath(String? root) {
    final base = root ?? Directory.current.path;
    // Look for registry.json in a few common locations.
    final candidates = [
      p.join(base, 'registry.json'),
      p.join(base, 'plugins', 'registry.json'),
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return p.join(base, 'registry.json');
  }

  void _printHelp() {
    print('zfa plugin - Manage ZFA plugins\n');
    print('USAGE:');
    print('  zfa plugin <command> [options]\n');
    print('COMMANDS:');
    print('  list               List available plugins');
    print('  search [query]     Search the plugin registry');
    print('  install <name>     Install a plugin (--dry-run prints diff)');
    print('  verify <path>      Verify a plugin manifest signature');
    print('  publish            Publish a plugin (v0: stub)');
    print('  enable <id>        Enable a plugin');
    print('  disable <id>       Disable a plugin');
    print('  add <package>      Wire a plugin package into main.dart');
    print(
      '  mcp [--force]      Scaffold a runtime MCP server into the host app',
    );
    print('                     (alias for `zfa mcp scaffold`; issue #369)');
  }
}
