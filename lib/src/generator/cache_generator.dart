import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/generator_config.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';

class CacheGenerator {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;

  CacheGenerator({
    required this.config,
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

  Future<List<GeneratedFile>> generate() async {
    if (!config.enableCache || config.cacheStorage != 'hive') {
      return [];
    }

    final files = <GeneratedFile>[];
    files.add(await _generateCacheInitFile());
    files.add(await _generateCachePolicyFile());
    files.add(await _generateTimestampCacheFile());
    await _regenerateHiveRegistrar();
    await _regenerateCacheIndex();
    return files;
  }

  Future<GeneratedFile> _generateCacheInitFile() async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final boxName = '${entitySnake}s';
    final fileName = '${entitySnake}_cache.dart';

    final cachePath = path.join(outputDir, 'cache', fileName);

    final content = '''
// Auto-generated cache for $entityName
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../domain/entities/$entitySnake/$entitySnake.dart';

Future<void> init${entityName}Cache() async {
  await Hive.openBox<$entityName>('$boxName');
}
''';

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_init',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateTimestampCacheFile() async {
    final fileName = 'timestamp_cache.dart';
    final cachePath = path.join(outputDir, 'cache', fileName);

    final content = '''
// Auto-generated timestamp cache
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

Future<void> initTimestampCache() async {
  await Hive.openBox<int>('cache_timestamps');
}
''';

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_init',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateCachePolicyFile() async {
    final policyType = config.cachePolicy;
    final ttlMinutes = config.ttlMinutes ?? 1440; // Default 24 hours

    String fileName;
    String policyName;
    String policyImpl;

    if (policyType == 'daily') {
      fileName = 'daily_cache_policy.dart';
      policyName = 'createDailyCachePolicy';
      policyImpl = '''
  final timestampBox = Hive.box<int>('cache_timestamps');
  return DailyCachePolicy(
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async => await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );''';
    } else if (policyType == 'restart') {
      fileName = 'app_restart_cache_policy.dart';
      policyName = 'createAppRestartCachePolicy';
      policyImpl = '''
  final timestampBox = Hive.box<int>('cache_timestamps');
  return AppRestartCachePolicy(
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async => await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );''';
    } else {
      fileName = 'ttl_${ttlMinutes}_minutes_cache_policy.dart';
      policyName = 'createTtl${ttlMinutes}MinutesCachePolicy';
      policyImpl = '''
  final timestampBox = Hive.box<int>('cache_timestamps');
  return TtlCachePolicy(
    ttl: const Duration(minutes: $ttlMinutes),
    getTimestamps: () async => Map<String, int>.from(timestampBox.toMap()),
    setTimestamp: (key, timestamp) async => await timestampBox.put(key, timestamp),
    removeTimestamp: (key) async => await timestampBox.delete(key),
    clearAll: () async => await timestampBox.clear(),
  );''';
    }

    final cachePath = path.join(outputDir, 'cache', fileName);

    final content = '''
// Auto-generated cache policy
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

CachePolicy $policyName() {
$policyImpl
}
''';

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_policy',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateCacheIndex() async {
    final dirPath = path.join(outputDir, 'cache');
    final indexPath = path.join(dirPath, 'index.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('_cache.dart') &&
            !f.path.endsWith('index.dart') &&
            !f.path.endsWith('timestamp_cache.dart'))
        .toList();

    if (files.isEmpty) {
      return;
    }

    final exports = <String>[];
    final imports = <String>[];
    final inits = <String>[];

    // Add timestamp cache first
    final timestampFile = File(path.join(dirPath, 'timestamp_cache.dart'));
    if (timestampFile.existsSync()) {
      exports.add("export 'timestamp_cache.dart';");
      imports.add("import 'timestamp_cache.dart';");
      inits.add('  await initTimestampCache();');
    }

    // Add registrar import
    final registrarFile = File(path.join(dirPath, 'hive_registrar.dart'));
    if (registrarFile.existsSync()) {
      exports.add("export 'hive_registrar.dart';");
      imports.add("import 'package:hive_ce_flutter/hive_ce_flutter.dart';");
      imports.add("import 'hive_registrar.dart';");
      inits.insert(0, '  Hive.registerAdapters();');
    }

    for (final file in files) {
      final fileName = path.basename(file.path);
      exports.add("export '$fileName';");
      imports.add("import '$fileName';");

      final content = file.readAsStringSync();
      final match =
          RegExp(r'Future<void> (init\w+Cache)\(\)').firstMatch(content);
      if (match != null) {
        inits.add('  await ${match.group(1)}();');
      }
    }

    // Check if cache_policy files exist
    final policyFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_cache_policy.dart'))
        .toList();
    for (final policyFile in policyFiles) {
      final fileName = path.basename(policyFile.path);
      exports.add("export '$fileName';");
    }

    final content = '''
// Auto-generated - DO NOT EDIT
${exports.join('\n')}

${imports.join('\n')}

Future<void> initAllCaches() async {
${inits.join('\n')}
}
''';

    await FileUtils.writeFile(
      indexPath,
      content,
      'cache_index',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<void> _regenerateHiveRegistrar() async {
    final dirPath = path.join(outputDir, 'cache');
    final registrarPath = path.join(dirPath, 'hive_registrar.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    // Find all entity cache files
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('_cache.dart') &&
            !f.path.endsWith('index.dart') &&
            !f.path.endsWith('timestamp_cache.dart'))
        .toList();

    if (files.isEmpty) {
      return;
    }

    final imports = <String>[];
    final adapterSpecs = <String>[];
    final registrations = <String>[];

    // Check for manual additions file
    final manualAdditionsPath =
        path.join(outputDir, 'cache', 'hive_manual_additions.txt');
    final manualAdditionsFile = File(manualAdditionsPath);

    if (manualAdditionsFile.existsSync()) {
      final lines = manualAdditionsFile.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // Format: import_path|EntityName
        // Example: ../domain/entities/enums/index.dart|ParserType
        final parts = trimmed.split('|');
        if (parts.length == 2) {
          final importPath = parts[0].trim();
          final entityName = parts[1].trim();

          if (!imports.contains("import '$importPath';")) {
            imports.add("import '$importPath';");
          }
          adapterSpecs.add('AdapterSpec<$entityName>()');
          registrations.add('    registerAdapter(${entityName}Adapter());');
        }
      }
    }

    for (final file in files) {
      final content = file.readAsStringSync();
      // Extract entity name from import
      final importMatch =
          RegExp(r"import '\.\./domain/entities/(\w+)/(\w+)\.dart';")
              .firstMatch(content);
      if (importMatch != null) {
        final entitySnake = importMatch.group(1);
        final entityFile = importMatch.group(2);

        // Convert snake_case to PascalCase
        final entityName = entityFile!
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join('');

        final importPath = '../domain/entities/$entitySnake/$entityFile.dart';
        if (!imports.contains("import '$importPath';")) {
          imports.add("import '$importPath';");
        }
        adapterSpecs.add('AdapterSpec<$entityName>()');
        registrations.add('    registerAdapter(${entityName}Adapter());');
      }
    }

    final content = '''
// Auto-generated Hive registrar
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
${imports.join('\n')}

part 'hive_registrar.g.dart';

@GenerateAdapters([
  ${adapterSpecs.join(',\n  ')}
])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
${registrations.join('\n')}
  }
}

extension IsolatedHiveRegistrar on IsolatedHiveInterface {
  void registerAdapters() {
${registrations.join('\n')}
  }
}
''';

    await FileUtils.writeFile(
      registrarPath,
      content,
      'hive_registrar',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );

    // Create template file if it doesn't exist
    if (!manualAdditionsFile.existsSync() && !dryRun) {
      final template = '''# Hive Manual Additions
# Add nested entities and enums that need Hive adapters
# Format: import_path|EntityName
# Example: ../domain/entities/enums/index.dart|ParserType

# Uncomment and add your entities below:
# ../domain/entities/enums/index.dart|ParserType
# ../domain/entities/enums/index.dart|HttpClientType
# ../domain/entities/range/range.dart|Range
''';
      manualAdditionsFile.writeAsStringSync(template);
    }
  }
}
