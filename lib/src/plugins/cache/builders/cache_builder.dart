import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/constants/known_types.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

part 'cache_policy_builder.dart';
part 'cache_builder_registrar.dart';

/// Generates cache support files for Hive-backed storage.
///
/// Produces cache initialization, policy, and registrar helpers to wire
/// local data sources with cache policies.
///
/// Example:
/// ```dart
/// final builder = CacheBuilder(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await builder.generate(GeneratorConfig(name: 'Product'));
/// ```
class CacheBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  /// Creates a [CacheBuilder].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param specLibrary Optional spec library override.
  CacheBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates cache support files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated cache files.
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableCache || config.cacheStorage != 'hive') {
      return [];
    }

    final files = <GeneratedFile>[];
    files.add(await _generateCacheInitFile(config));
    files.add(await _generateCachePolicyFile(config));
    files.add(await _generateTimestampCacheFile(config));
    await _regenerateHiveRegistrar(config);
    await _regenerateCacheIndex(config);
    return files;
  }

  Future<GeneratedFile> _generateCacheInitFile(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final boxName = '${entitySnake}s';
    final fileName = '${entitySnake}_cache.dart';

    final cachePath = path.join(outputDir, 'cache', fileName);

    final directives = [
      Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      Directive.import('../domain/entities/$entitySnake/$entitySnake.dart'),
    ];

    final method = Method(
      (m) => m
        ..name = 'init${entityName}Cache'
        ..returns = _futureVoidType()
        ..modifier = MethodModifier.async
        ..docs.add('Auto-generated cache for $entityName')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('Hive')
                  .property('openBox')
                  .call([literalString(boxName)], const {}, [refer(entityName)])
                  .awaited
                  .statement,
            ),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_init',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  Future<GeneratedFile> _generateTimestampCacheFile(
    GeneratorConfig config,
  ) async {
    final fileName = 'timestamp_cache.dart';
    final cachePath = path.join(outputDir, 'cache', fileName);

    final directives = [
      Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
    ];

    final method = Method(
      (m) => m
        ..name = 'initTimestampCache'
        ..returns = _futureVoidType()
        ..modifier = MethodModifier.async
        ..docs.add('Auto-generated timestamp cache')
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('Hive')
                  .property('openBox')
                  .call(
                    [literalString('cache_timestamps')],
                    const {},
                    [refer('int')],
                  )
                  .awaited
                  .statement,
            ),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

    return FileUtils.writeFile(
      cachePath,
      content,
      'cache_init',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
    );
  }

  Future<void> _regenerateCacheIndex(GeneratorConfig config) async {
    final dirPath = path.join(outputDir, 'cache');
    final indexPath = path.join(dirPath, 'index.dart');

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return;
    }

    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('_cache.dart') &&
              !f.path.endsWith('index.dart') &&
              !f.path.endsWith('timestamp_cache.dart'),
        )
        .toList();

    if (files.isEmpty) {
      if (File(indexPath).existsSync()) {
        if (options.dryRun) {
          if (options.verbose) print('  Dry run: Deleting $indexPath');
        } else {
          File(indexPath).deleteSync();
        }
      }
      return;
    }

    final exports = <String>[];
    final imports = <String>[];
    final statements = <Code>[];

    final timestampFile = File(path.join(dirPath, 'timestamp_cache.dart'));
    if (timestampFile.existsSync()) {
      exports.add('timestamp_cache.dart');
      imports.add('timestamp_cache.dart');
      statements.add(refer('initTimestampCache').call([]).awaited.statement);
    }

    final registrarFile = File(path.join(dirPath, 'hive_registrar.dart'));
    if (registrarFile.existsSync()) {
      exports.add('hive_registrar.dart');
      imports.add('package:hive_ce_flutter/hive_ce_flutter.dart');
      imports.add('hive_registrar.dart');
      statements.insert(
        0,
        refer('Hive').property('registerAdapters').call([]).statement,
      );
    }

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entitySnake = fileName.replaceAll('_cache.dart', '');
      final entityName = StringUtils.convertToPascalCase(entitySnake);
      exports.add(fileName);
      imports.add(fileName);
      statements.add(
        refer('init${entityName}Cache').call([]).awaited.statement,
      );
    }

    final policyFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_cache_policy.dart'))
        .toList();
    for (final policyFile in policyFiles) {
      exports.add(path.basename(policyFile.path));
    }

    final directives = [
      ...exports.map(Directive.export),
      ...imports.map(Directive.import),
    ];

    final initAllCaches = Method(
      (m) => m
        ..name = 'initAllCaches'
        ..returns = _futureVoidType()
        ..modifier = MethodModifier.async
        ..docs.add('Auto-generated - DO NOT EDIT')
        ..body = Block((b) => b..statements.addAll(statements)),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [initAllCaches], directives: directives),
    );

    await FileUtils.writeFile(
      indexPath,
      content,
      'cache_index',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );
  }
}
