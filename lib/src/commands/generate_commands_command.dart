import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/plugin_system/plugin_registry.dart';

/// Maps a plugin id to the extension command category subdirectory.
///
/// Mirrors the on-disk layout under `.specify/extensions/zuraffa/commands/`
/// (data, domain, presentation, graphql, testing, scaffolding, utilities,
/// integration, tooling, entity). Capabilities whose plugin is not listed
/// fall back to `utilities` so every generated file still lands in a known
/// category directory (FR-007).
const Map<String, String> _pluginCategory = {
  'datasource': 'data',
  'repository': 'data',
  'sqlite': 'data',
  'provider': 'domain',
  'service': 'domain',
  'strategy': 'domain',
  'usecase': 'domain',
  'method_append': 'domain',
  'route': 'presentation',
  'view': 'presentation',
  'presenter': 'presentation',
  'controller': 'presentation',
  'state': 'presentation',
  'tui': 'presentation',
  'shadcn': 'presentation',
  'graphql': 'graphql',
  'gql': 'graphql',
  'test': 'testing',
  'mock': 'testing',
  'feature': 'scaffolding',
  'module': 'scaffolding',
  'di': 'utilities',
  'cache': 'utilities',
  'api': 'integration',
  'sync': 'integration',
  'observer': 'integration',
  'mcp': 'tooling',
  'gym': 'tooling',
  'cli': 'tooling',
  'entity': 'entity',
};

/// A single generated command entry.
class _CommandEntry {
  const _CommandEntry({
    required this.commandName,
    required this.description,
    required this.category,
    required this.capabilityName,
    required this.pluginId,
  });

  final String commandName;
  final String description;
  final String category;
  final String capabilityName;
  final String pluginId;
}

/// Regenerates the speckit extension command `.md` files from the live
/// [PluginRegistry] capabilities.
///
/// Implements `zfa generate-commands` (FR-005..FR-010, SC-002, SC-005 of
/// feature `005-speckit-extension-enhancements`). For every plugin capability
/// it emits a `.md` file with YAML frontmatter + usage/flags sections, grouped
/// into per-category subdirectories, plus a `command_registry.json`. Supports
/// `--output` and `--dry-run`, and is idempotent (overwrites the same paths).
class GenerateCommandsCommand extends Command<void> {
  static const String commandName = 'generate-commands';

  final PluginRegistry registry;

  GenerateCommandsCommand([PluginRegistry? registry])
    : registry = registry ?? PluginRegistry.instance {
    argParser.addOption(
      'output',
      abbr: 'o',
      defaultsTo: '.specify/extensions/zuraffa/commands/',
      help: 'Output directory for generated .md files',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview without writing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose logging',
    );
  }

  @override
  String get name => commandName;

  @override
  String get description =>
      'Regenerate speckit extension command files from zfa manifest';

  @override
  Future<void> run() async {
    final outputDir = argResults!['output'] as String;
    final dryRun = argResults!['dry-run'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final entries = <_CommandEntry>[];
    for (final plugin in registry.plugins) {
      for (final capability in plugin.capabilities) {
        entries.add(
          _CommandEntry(
            commandName: 'speckit.zuraffa.${capability.name}',
            description: capability.description,
            category: _pluginCategory[plugin.id] ?? 'utilities',
            capabilityName: capability.name,
            pluginId: plugin.id,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      print('No plugin capabilities found — nothing to generate.');
      return;
    }

    if (dryRun) {
      for (final entry in entries) {
        print('${entry.category}/${entry.capabilityName}.md');
      }
      print('command_registry.json');
      if (verbose) {
        print('Would write ${entries.length} command files to $outputDir');
      }
      return;
    }

    final base = Directory(outputDir);
    if (!base.existsSync()) base.createSync(recursive: true);

    final writtenPaths = <String>[];
    for (final entry in entries) {
      final categoryDir = Directory('${base.path}/${entry.category}');
      if (!categoryDir.existsSync()) categoryDir.createSync(recursive: true);
      final file = File('${categoryDir.path}/${entry.capabilityName}.md');
      file.writeAsStringSync(_renderMarkdown(entry));
      writtenPaths.add(file.path);
      if (verbose) print('wrote ${file.path}');
    }

    final registryFile = File('${base.path}/command_registry.json');
    registryFile.writeAsStringSync(_renderRegistry(entries));
    writtenPaths.add(registryFile.path);
    if (verbose) print('wrote ${registryFile.path}');

    print(
      'Generated ${entries.length} command files (+ registry) in $outputDir',
    );
  }

  String _renderMarkdown(_CommandEntry entry) {
    final title = _titleCase(entry.capabilityName);
    final name = _yamlEscape(entry.commandName);
    final description = _yamlEscape(entry.description);
    final category = _yamlEscape(entry.category);
    return '''
---
name: "$name"
description: "$description"
category: "$category"
---

# $title: ${entry.description}

## Usage

```bash
zfa ${entry.capabilityName}
```

## When to Use

${entry.description}

## Required Parameters

- **name**: Name of the target (e.g. Product)

## Flags

| Flag | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `--name` | string | No | - | Name of the target (e.g. Product) |
| `--force` | bool | No | False | Force overwrite existing files |
| `--dry-run` | bool | No | False | Preview without writing files |
| `--verbose` | bool | No | False | Enable verbose logging |

## Output

Supports `--dry-run` to preview without writing files.
''';
  }

  String _renderRegistry(List<_CommandEntry> entries) {
    final commands = entries
        .map(
          (e) => {
            'name': e.commandName,
            'file': '${e.category}/${e.capabilityName}.md',
            'category': e.category,
            'plugin': e.pluginId,
            'capability': e.capabilityName,
          },
        )
        .toList();
    commands.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );
    return JsonEncoder.withIndent('  ').convert({'commands': commands});
  }
}

String _titleCase(String name) => name
    .split('_')
    .map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1);
    })
    .join(' ');

/// Escapes double quotes so untrusted capability metadata can't break the
/// double-quoted YAML frontmatter emitted by [_renderMarkdown].
String _yamlEscape(String value) => value.replaceAll('"', r'\"');
