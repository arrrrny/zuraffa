import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class CacheBuilder {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  CacheBuilder({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!config.enableCache || config.cacheStorage != 'hive') {
      return [];
    }

    final files = <GeneratedFile>[];
    files.add(await _generateCacheInitFile(config));
    files.add(await _generateCachePolicyFile(config));
    files.add(await _generateTimestampCacheFile());
    await _regenerateHiveRegistrar();
    await _regenerateCacheIndex();
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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateTimestampCacheFile() async {
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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }

  Future<GeneratedFile> _generateCachePolicyFile(GeneratorConfig config) async {
    final policyType = config.cachePolicy;
    final ttlMinutes = config.ttlMinutes ?? 1440;

    String fileName;
    String policyName;
    String policyClass;
    Expression? ttlExpression;

    if (policyType == 'daily') {
      fileName = 'daily_cache_policy.dart';
      policyName = 'createDailyCachePolicy';
      policyClass = 'DailyCachePolicy';
    } else if (policyType == 'restart') {
      fileName = 'app_restart_cache_policy.dart';
      policyName = 'createAppRestartCachePolicy';
      policyClass = 'AppRestartCachePolicy';
    } else {
      fileName = 'ttl_${ttlMinutes}_minutes_cache_policy.dart';
      policyName = 'createTtl${ttlMinutes}MinutesCachePolicy';
      policyClass = 'TtlCachePolicy';
      ttlExpression = refer(
        'Duration',
      ).constInstance([], {'minutes': literalNum(ttlMinutes)});
    }

    final cachePath = path.join(outputDir, 'cache', fileName);

    final directives = [
      Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
    ];

    final timestampBoxDecl = declareFinal('timestampBox').assign(
      refer('Hive')
          .property('box')
          .call([literalString('cache_timestamps')], const {}, [refer('int')]),
    );

    final getTimestamps = _asyncLambda(
      [],
      refer('Map').newInstanceNamed(
        'from',
        [refer('timestampBox').property('toMap').call([])],
        const {},
        [refer('String'), refer('int')],
      ),
    );

    final setTimestamp = _asyncLambda(
      [
        Parameter((p) => p..name = 'key'),
        Parameter((p) => p..name = 'timestamp'),
      ],
      refer(
        'timestampBox',
      ).property('put').call([refer('key'), refer('timestamp')]).awaited,
    );

    final removeTimestamp = _asyncLambda([
      Parameter((p) => p..name = 'key'),
    ], refer('timestampBox').property('delete').call([refer('key')]).awaited);

    final clearAll = _asyncLambda(
      [],
      refer('timestampBox').property('clear').call([]).awaited,
    );

    final policyArguments = {
      'getTimestamps': getTimestamps,
      'setTimestamp': setTimestamp,
      'removeTimestamp': removeTimestamp,
      'clearAll': clearAll,
      'ttl': ?ttlExpression,
    };

    final policyCall = refer(policyClass).call([], policyArguments);

    final method = Method(
      (m) => m
        ..name = policyName
        ..returns = refer('CachePolicy')
        ..docs.add('Auto-generated cache policy')
        ..body = Block(
          (b) => b
            ..statements.add(timestampBoxDecl.statement)
            ..statements.add(policyCall.returned.statement),
        ),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(specs: [method], directives: directives),
    );

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
        .where(
          (f) =>
              f.path.endsWith('_cache.dart') &&
              !f.path.endsWith('index.dart') &&
              !f.path.endsWith('timestamp_cache.dart'),
        )
        .toList();

    if (files.isEmpty) {
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
      return;
    }

    final imports = <String>[];
    final adapterEntities = <String>[];
    final processedEntities = <String>{};

    final manualAdditionsPath = path.join(
      outputDir,
      'cache',
      'hive_manual_additions.txt',
    );
    final manualAdditionsFile = File(manualAdditionsPath);

    if (manualAdditionsFile.existsSync()) {
      final lines = manualAdditionsFile.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final parts = trimmed.split('|');
        if (parts.length == 2) {
          final importPath = parts[0].trim();
          final entityName = parts[1].trim();

          if (!imports.contains(importPath)) {
            imports.add(importPath);
          }
          if (!processedEntities.contains(entityName)) {
            processedEntities.add(entityName);
            adapterEntities.add(entityName);
          }
        }
      }
    }

    for (final file in files) {
      final fileName = path.basename(file.path);
      final entitySnake = fileName.replaceAll('_cache.dart', '');
      final entityName = StringUtils.convertToPascalCase(entitySnake);
      final importPath = '../domain/entities/$entitySnake/$entitySnake.dart';

      if (!imports.contains(importPath)) {
        imports.add(importPath);
      }
      if (!processedEntities.contains(entityName)) {
        processedEntities.add(entityName);
        adapterEntities.add(entityName);
      }

      await _collectNestedEntitiesForHive(
        entityName,
        imports,
        adapterEntities,
        processedEntities,
      );
    }

    final adapterSpecs = adapterEntities
        .map(
          (entity) => refer('AdapterSpec').call([], const {}, [refer(entity)]),
        )
        .toList();

    final registrationStatements = adapterEntities
        .map(
          (entity) => refer(
            'registerAdapter',
          ).call([refer('${entity}Adapter').call([])]).statement,
        )
        .toList();

    final directives = [
      Directive.import('package:hive_ce_flutter/hive_ce_flutter.dart'),
      ...imports.map(Directive.import),
      Directive.part('hive_registrar.g.dart'),
    ];

    final generateAdapters = refer(
      'GenerateAdapters',
    ).call([literalList(adapterSpecs)]);

    final registerMethod = Method(
      (m) => m
        ..name = 'registerAdapters'
        ..returns = refer('void')
        ..body = Block((b) => b..statements.addAll(registrationStatements)),
    );

    final hiveRegistrarExtension = Extension(
      (e) => e
        ..name = 'HiveRegistrar'
        ..on = refer('HiveInterface')
        ..annotations.add(generateAdapters)
        ..methods.add(registerMethod),
    );

    final isolatedRegistrarExtension = Extension(
      (e) => e
        ..name = 'IsolatedHiveRegistrar'
        ..on = refer('IsolatedHiveInterface')
        ..methods.add(registerMethod),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [hiveRegistrarExtension, isolatedRegistrarExtension],
        directives: directives,
      ),
    );

    await FileUtils.writeFile(
      registrarPath,
      content,
      'hive_registrar',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );

    if (!manualAdditionsFile.existsSync()) {
      final template = '''# Hive Manual Additions
# Add nested entities and enums that need Hive adapters
# Format: import_path|EntityName
# Example: ../domain/entities/enums/index.dart|ParserType

# Uncomment and add your entities below:
# ../domain/entities/enums/index.dart|ParserType
# ../domain/entities/enums/index.dart|HttpClientType
# ../domain/entities/range/range.dart|Range
''';
      await FileUtils.writeFile(
        manualAdditionsFile.path,
        template,
        'hive_manual_additions',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
    }
  }

  Future<void> _collectNestedEntitiesForHive(
    String entityName,
    List<String> imports,
    List<String> adapterEntities,
    Set<String> processedEntities,
  ) async {
    final subtypes = EntityAnalyzer.getPolymorphicSubtypes(
      entityName,
      outputDir,
    );
    for (final subtype in subtypes) {
      if (!processedEntities.contains(subtype)) {
        processedEntities.add(subtype);
        final subtypeSnake = StringUtils.camelToSnake(subtype);
        final importPath =
            '../domain/entities/$subtypeSnake/$subtypeSnake.dart';
        if (!imports.contains(importPath)) {
          imports.add(importPath);
        }
        adapterEntities.add(subtype);

        await _collectNestedEntitiesForHive(
          subtype,
          imports,
          adapterEntities,
          processedEntities,
        );
      }
    }

    final entityFields = EntityAnalyzer.analyzeEntity(entityName, outputDir);

    for (final entry in entityFields.entries) {
      final fieldType = entry.value;
      final baseTypes = _extractEntityTypes(fieldType);

      for (final baseType in baseTypes) {
        if (baseType.isNotEmpty &&
            baseType[0] == baseType[0].toUpperCase() &&
            ![
              'String',
              'int',
              'double',
              'bool',
              'DateTime',
              'Object',
              'dynamic',
            ].contains(baseType) &&
            !processedEntities.contains(baseType)) {
          final nestedSubtypes = EntityAnalyzer.getPolymorphicSubtypes(
            baseType,
            outputDir,
          );
          if (nestedSubtypes.isNotEmpty) {
            final baseTypeSnake = StringUtils.camelToSnake(baseType);
            final abstractImportPath =
                '../domain/entities/$baseTypeSnake/$baseTypeSnake.dart';
            if (!imports.contains(abstractImportPath)) {
              imports.add(abstractImportPath);
            }

            for (final subtype in nestedSubtypes) {
              if (!processedEntities.contains(subtype)) {
                processedEntities.add(subtype);
                final subtypeSnake = StringUtils.camelToSnake(subtype);
                final importPath =
                    '../domain/entities/$subtypeSnake/$subtypeSnake.dart';
                if (!imports.contains(importPath)) {
                  imports.add(importPath);
                }
                adapterEntities.add(subtype);

                await _collectNestedEntitiesForHive(
                  subtype,
                  imports,
                  adapterEntities,
                  processedEntities,
                );
              }
            }
            continue;
          }

          final nestedFields = EntityAnalyzer.analyzeEntity(
            baseType,
            outputDir,
          );
          if (nestedFields.isNotEmpty) {
            processedEntities.add(baseType);
            final baseTypeSnake = StringUtils.camelToSnake(baseType);
            final importPath =
                '../domain/entities/$baseTypeSnake/$baseTypeSnake.dart';
            if (!imports.contains(importPath)) {
              imports.add(importPath);
            }
            adapterEntities.add(baseType);

            await _collectNestedEntitiesForHive(
              baseType,
              imports,
              adapterEntities,
              processedEntities,
            );
          } else if (_isEnum(baseType)) {
            processedEntities.add(baseType);
            final enumImportPath = '../domain/entities/enums/index.dart';
            if (!imports.contains(enumImportPath)) {
              imports.add(enumImportPath);
            }
            adapterEntities.add(baseType);
          }
        }
      }
    }
  }

  bool _isEnum(String typeName) {
    final enumsDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'enums'),
    );
    if (!enumsDir.existsSync()) return false;

    final typeSnake = StringUtils.camelToSnake(typeName);
    final enumFile = File(path.join(enumsDir.path, '$typeSnake.dart'));

    if (enumFile.existsSync()) {
      final content = enumFile.readAsStringSync();
      return content.contains('enum $typeName');
    }

    return false;
  }

  List<String> _extractEntityTypes(String fieldType) {
    final types = <String>[];
    var baseType = fieldType.replaceAll('?', '');

    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      baseType = baseType.substring(5, baseType.length - 1);
    } else if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      final innerTypes = baseType.substring(4, baseType.length - 1);
      final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();
      if (typeParts.length == 2) {
        baseType = typeParts[1];
      } else {
        return types;
      }
    }

    if (baseType.startsWith('\$')) {
      baseType = baseType.substring(1);
    }

    baseType = baseType
        .replaceAll('<', '')
        .replaceAll('>', '')
        .split(',')[0]
        .trim();

    if (baseType.isNotEmpty) {
      types.add(baseType);
    }

    return types;
  }

  Expression _asyncLambda(List<Parameter> params, Expression body) {
    final method = Method(
      (m) => m
        ..requiredParameters.addAll(params)
        ..modifier = MethodModifier.async
        ..lambda = true
        ..body = body.code,
    );
    return method.closure;
  }

  Reference _futureVoidType() {
    return TypeReference(
      (b) => b
        ..symbol = 'Future'
        ..types.add(refer('void')),
    );
  }
}
