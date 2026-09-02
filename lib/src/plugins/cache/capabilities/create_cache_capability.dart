import 'package:path/path.dart' as path;

import '../../../core/context/file_system.dart';
import '../../../core/plugin_system/capability.dart';
import '../../../models/generated_file.dart';
import '../../../utils/string_utils.dart';
import '../cache_plugin.dart';
import '../../../models/generator_config.dart';

class CreateCacheCapability implements ZuraffaCapability {
  final CachePlugin plugin;

  CreateCacheCapability(this.plugin);

  @override
  String get name => 'create';

  @override
  String get description => 'Create Cache';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {
        'type': 'string',
        'description': 'Name of the entity (e.g. Product)',
      },

      'policy': {
        'type': 'string',
        'description': 'Cache policy (daily, hourly, etc.)',
        'default': 'daily',
      },
      'storage': {
        'type': 'string',
        'description': 'Storage backend (hive, etc.)',
      },
      'ttl': {'type': 'integer', 'description': 'Time to live in minutes'},
      'dryRun': {
        'type': 'boolean',
        'description': 'Run without writing files',
        'default': false,
      },
      'force': {
        'type': 'boolean',
        'description': 'Force overwrite existing files',
        'default': false,
      },
      'verbose': {
        'type': 'boolean',
        'description': 'Enable verbose logging',
        'default': false,
      },
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'files': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = await _generateFiles(args, dryRun: true);

    return EffectReport(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(file: f.path, action: f.action, diff: null))
          .toList(),
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    try {
      final files = await _generateFiles(args, dryRun: args['dryRun'] ?? false);

      return ExecutionResult(
        success: true,
        files: files.map((f) => f.path).toList(),
        data: {'generatedFiles': files},
      );
    } catch (e) {
      // Mirrors CreateCacheAdapterCapability: validation failures are
      // capability-owned so the CLI renders an actionable message instead of
      // a raw stack trace (and never a false success) — issue #772.
      return ExecutionResult(success: false, message: '$e');
    }
  }

  /// Resolves [entityName] against the workspace, mirroring the sibling
  /// [CreateCacheAdapterCapability]: a regular entity directory or an enum
  /// (index or per-file) counts as found; anything else fails with an
  /// `Available entities:` list (issue #772).
  Future<void> _validateEntityExists(
    String entityName,
    FileSystem fs,
    String outputDir,
  ) async {
    final entitySnake = StringUtils.camelToSnake(entityName);

    final entityFilePath = path.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );
    if (await fs.exists(entityFilePath)) {
      return;
    }

    // Enum fallback — same semantics as cache adapter.
    final enumIndexPath = path.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      'index.dart',
    );
    final enumFilePath = path.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      '$entitySnake.dart',
    );

    var enumExists = false;
    if (await fs.exists(enumIndexPath)) {
      final content = await fs.read(enumIndexPath);
      if (content.contains('enum $entityName')) {
        enumExists = true;
      }
    }
    if (!enumExists && await fs.exists(enumFilePath)) {
      final content = await fs.read(enumFilePath);
      if (content.contains('enum $entityName')) {
        enumExists = true;
      }
    }
    if (enumExists) {
      return;
    }

    // List available entities for a helpful error message (adapter parity).
    final entitiesDir = path.join(outputDir, 'domain', 'entities');
    final available = <String>[];
    if (await fs.exists(entitiesDir)) {
      final items = await fs.list(entitiesDir);
      for (final item in items) {
        if (await fs.isDirectory(item)) {
          final dirName = path.basename(item);
          final entityFile = path.join(item, '$dirName.dart');
          if (dirName == 'enums') {
            if (await fs.exists(enumIndexPath)) {
              final content = await fs.read(enumIndexPath);
              for (final match in RegExp(r'enum\s+(\w+)').allMatches(content)) {
                available.add(match.group(1)!);
              }
            }
            continue;
          }
          if (await fs.exists(entityFile)) {
            available.add(StringUtils.convertToPascalCase(dirName));
          }
        }
      }
    }

    final suggestions = available.isNotEmpty
        ? '\nAvailable entities:\n${available.map((e) => '  - $e').join('\n')}'
        : '';
    throw Exception("Entity '$entityName' not found.$suggestions");
  }

  Future<List<GeneratedFile>> _generateFiles(
    Map<String, dynamic> args, {
    required bool dryRun,
  }) async {
    final name = args['name'];
    final outputDir = plugin.outputDir;
    final policy = args['policy'] ?? 'daily';
    final storage = args['storage'];
    final ttl = args['ttl'];
    final force = args['force'] ?? false;
    final verbose = args['verbose'] ?? false;

    // Validate before generating: a nonexistent entity previously produced
    // zero files and a false `✅ Success! (No changes required)` (issue #772).
    await _validateEntityExists(
      name as String,
      plugin.cacheBuilder.fileSystem,
      outputDir,
    );

    final config = GeneratorConfig(
      name: name,
      outputDir: outputDir,
      enableCache: true,
      cachePolicy: policy,
      cacheStorage: storage,
      ttlMinutes: ttl,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    return await plugin.generate(config);
  }
}
