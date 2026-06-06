import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';
import 'mock_entity_helper.dart';
import 'mock_entity_graph_builder.dart';
import 'mock_value_builder.dart';
import 'mock_type_helper.dart';
import 'mock_json_helper_builder.dart';

class MockJsonBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;
  final MockValueBuilder valueBuilder;
  final MockEntityHelper entityHelper;
  final MockTypeHelper typeHelper;
  final MockJsonHelperBuilder helperBuilder;
  final MockEntityGraphBuilder entityGraphBuilder;
  final FileSystem fileSystem;

  MockJsonBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    SpecLibrary? specLibrary,
    MockValueBuilder? valueBuilder,
    MockEntityHelper? entityHelper,
    MockTypeHelper? typeHelper,
    MockJsonHelperBuilder? helperBuilder,
    MockEntityGraphBuilder? entityGraphBuilder,
    FileSystem? fileSystem,
  }) : specLibrary = specLibrary ?? const SpecLibrary(),
       valueBuilder = valueBuilder ?? MockValueBuilder(outputDir: outputDir),
       entityHelper = entityHelper ?? const MockEntityHelper(),
       typeHelper = typeHelper ?? const MockTypeHelper(),
       helperBuilder =
           helperBuilder ?? MockJsonHelperBuilder(outputDir: outputDir),
       entityGraphBuilder =
           entityGraphBuilder ??
           MockEntityGraphBuilder(outputDir: outputDir, fileSystem: fileSystem),
       fileSystem = fileSystem ?? FileSystem.create();

  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    final files = <GeneratedFile>[];
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;

    final domain = domainForEntity(
      entityName,
      explicitDomain: config.mockJsonDomain ?? config.domain,
    );
    final entityFields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );

    final jsonValues = valueBuilder.generateMockValuesForJson(
      entityName,
      entityFields,
    );

    final jsonContent = const JsonEncoder.withIndent('  ').convert(jsonValues);

    final jsonOutputDir = p.join(outputDir, 'data', 'mock_json', domain);
    await io.Directory(jsonOutputDir).create(recursive: true);

    final jsonPath = jsonFilePathFor(entityName, domain);
    files.add(await _writeJsonFile(jsonPath, jsonContent, config));

    final helperContent = helperBuilder.generateHelperContent(
      entityName: entityName,
      domain: domain,
      jsonFilePath: jsonPath,
    );
    final helperPath = helperFilePathFor(entityName, domain);
    files.add(await _writeDartFile(helperPath, helperContent, config));

    final metaContent = _buildMetaContent(jsonContent, entityFields);
    final metaPath = metaFilePathFor(entityName, domain);

    _checkFieldMismatch(metaPath, entityFields, config.verbose);

    files.add(await _writeJsonFile(metaPath, metaContent, config));

    final nestedNames = await entityGraphBuilder.generateNestedEntityJsonNames(
      entityName: entityName,
      entityFields: entityFields,
    );

    for (final nestedName in nestedNames) {
      final nestedConfig = GeneratorConfig(
        name: nestedName,
        outputDir: outputDir,
        generateMockJson: true,
        mockJsonDomain: domain,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      );
      files.addAll(await generate(nestedConfig));
    }

    return files;
  }

  Future<GeneratedFile> _writeJsonFile(
    String filePath,
    String content,
    GeneratorConfig config,
  ) async {
    if (config.revert) {
      return GeneratedFile(
        path: filePath,
        type: 'mock_json',
        action: 'skipped',
      );
    }

    if (config.dryRun) {
      return GeneratedFile(
        path: filePath,
        type: 'mock_json',
        action: 'would_create',
      );
    }

    final exists = await fileSystem.exists(filePath);
    if (exists && !config.force) {
      if (config.verbose) {
        print(
          '  ⏭ Skipping existing file (use --force to overwrite): $filePath',
        );
      }
      return GeneratedFile(
        path: filePath,
        type: 'mock_json',
        action: 'skipped',
      );
    }

    final dir = p.dirname(filePath);
    await fileSystem.createDir(dir, recursive: true);
    await fileSystem.write(filePath, content);

    return GeneratedFile(
      path: filePath,
      type: 'mock_json',
      action: exists ? 'overwritten' : 'created',
    );
  }

  Future<GeneratedFile> _writeDartFile(
    String filePath,
    String content,
    GeneratorConfig config,
  ) async {
    if (config.revert) {
      return GeneratedFile(
        path: filePath,
        type: 'mock_json_helper',
        action: 'skipped',
      );
    }

    if (config.dryRun) {
      return GeneratedFile(
        path: filePath,
        type: 'mock_json_helper',
        action: 'would_create',
      );
    }

    final exists = await fileSystem.exists(filePath);
    if (exists && !config.force) {
      if (config.verbose) {
        print(
          '  ⏭ Skipping existing file (use --force to overwrite): $filePath',
        );
      }
      return GeneratedFile(
        path: filePath,
        type: 'mock_json_helper',
        action: 'skipped',
      );
    }

    final dir = p.dirname(filePath);
    await fileSystem.createDir(dir, recursive: true);

    return FileUtils.writeFile(
      filePath,
      content,
      'mock_json_helper',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }

  String _buildMetaContent(String jsonContent, Map<String, String> fields) {
    final hash = jsonContent.hashCode.toRadixString(16);
    final fieldSignature =
        fields.entries.map((e) => '${e.key}:${e.value}').toList()..sort();
    return const JsonEncoder.withIndent('  ').convert({
      'generatedHash': hash,
      'generatedAt': DateTime.now().toIso8601String(),
      'fieldSignature': fieldSignature.join(','),
    });
  }

  void _checkFieldMismatch(
    String metaPath,
    Map<String, String> currentFields,
    bool verbose,
  ) {
    try {
      final metaFile = io.File(metaPath);
      if (!metaFile.existsSync()) return;

      final meta =
          jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final storedSig = meta['fieldSignature'] as String?;

      if (storedSig == null) return;

      final currentSig =
          currentFields.entries.map((e) => '${e.key}:${e.value}').toList()
            ..sort();
      final currentSigStr = currentSig.join(',');

      if (storedSig != currentSigStr) {
        final storedFields = storedSig
            .split(',')
            .map((s) => s.split(':')[0])
            .toSet();
        final currentFieldNames = currentFields.keys.toSet();
        final removed = storedFields.difference(currentFieldNames);
        final added = currentFieldNames.difference(storedFields);

        print('⚠️  Field mismatch detected for ${p.basename(metaPath)}');
        if (added.isNotEmpty) {
          print('   New fields: ${added.join(', ')}');
        }
        if (removed.isNotEmpty) {
          print('   Removed fields: ${removed.join(', ')}');
        }
        print('   Run with --force to regenerate.');
      }
    } catch (_) {}
  }

  String domainForEntity(String entityName, {String? explicitDomain}) {
    if (explicitDomain != null) return explicitDomain;

    final entitySnake = StringUtils.camelToSnake(entityName);
    final entitiesDir = p.join(outputDir, 'domain', 'entities');

    try {
      final dir = io.Directory(entitiesDir);
      if (!dir.existsSync()) return entitySnake;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is io.File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('.g.dart') &&
            !entity.path.endsWith('.zorphy.dart')) {
          try {
            final content = entity.readAsStringSync();
            if (RegExp(
              r'^\s*(?:(?:abstract|sealed|base|final|interface)\s+)*class\s+\$?' +
                  RegExp.escape(entityName) +
                  r'\b',
              multiLine: true,
            ).hasMatch(content)) {
              final relative = p.relative(entity.path, from: entitiesDir);
              final parts = relative.split(p.separator);
              if (parts.length >= 2) {
                return parts[0];
              }
              return entitySnake;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return entitySnake;
  }

  String jsonFilePathFor(String entityName, String domain) {
    final entitySnake = StringUtils.camelToSnake(entityName);
    return p.join(
      outputDir,
      'data',
      'mock_json',
      domain,
      '$entitySnake.mock.json',
    );
  }

  String helperFilePathFor(String entityName, String domain) {
    final entitySnake = StringUtils.camelToSnake(entityName);
    return p.join(
      outputDir,
      'data',
      'mock_json',
      domain,
      '${entitySnake}_mock_json.dart',
    );
  }

  String metaFilePathFor(String entityName, String domain) {
    final entitySnake = StringUtils.camelToSnake(entityName);
    return p.join(
      outputDir,
      'data',
      'mock_json',
      domain,
      '$entitySnake.mock.json.meta',
    );
  }
}
