/// Emits Dart files from GraphQL schema specifications by delegating entity
/// and enum creation to the `zorphy` CLI.
library;

import 'dart:io';

import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import 'graphql_schema_translator.dart';
import '../core/builder/shared/spec_library.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

/// Emits Dart entity and enum files from GraphQL schema specifications.
class GraphQLEntityEmitter {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  GraphQLEntityEmitter({
    required this.outputDir,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates a Dart entity file from the given [spec].
  ///
  /// Returns the file path if generated, or null if skipped.
  Future<String?> generateEntity(EntitySpec spec) async {
    return _generateEntityViaZorphy(spec);
  }

  /// Generates a Dart enum file from the given [spec].
  ///
  /// Returns the file path if generated, or null if skipped.
  Future<String?> generateEnum(EnumSpec spec) async {
    return _generateEnumViaZorphy(spec);
  }

  /// Generates a GraphQL operation file (query or mutation).
  Future<String?> generateOperation(
    OperationSpec spec, {
    String? domain,
  }) async {
    final snakeName = StringUtils.camelToSnake(spec.name);
    final opType = spec.type;

    // Path: lib/src/data/datasources/[domain]/graphql/[operation_name]_[type].dart
    final domainDir = domain ?? 'graphql';
    final dirPath = path.join(
      outputDir,
      'data',
      'datasources',
      domainDir,
      'graphql',
    );
    final filePath = path.join(dirPath, '${snakeName}_$opType.dart');

    if (!force && await File(filePath).exists()) {
      if (verbose) {
        print('Skipping $filePath (already exists)');
      }
      return filePath;
    }

    final content = _generateOperationContent(spec);

    if (dryRun) {
      print('Would generate: $filePath');
      return filePath;
    }

    await FileUtils.writeFile(
      filePath,
      content,
      'graphql_operation',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );

    if (verbose) {
      print('Generated: $filePath');
    }

    return filePath;
  }

  /// Delegate entity generation to zorphy_cli
  Future<String?> _generateEntityViaZorphy(EntitySpec spec) async {
    // Check if zorphy is available
    final checkResult = await Process.run('which', ['zorphy']);
    if (checkResult.exitCode != 0) {
      print(
        '⚠️  zorphy CLI not found. Install with: dart pub global activate zorphy_annotation',
      );
      return null;
    }

    final args = <String>['create', '-n', spec.name];

    // Add fields
    for (final field in spec.fields) {
      final nullableSuffix = field.isNullable ? '?' : '';
      args.addAll([
        '--field',
        '${field.name}:${field.dartType}$nullableSuffix',
      ]);
    }

    // Add output directory
    args.addAll(['-o', path.join(outputDir, 'domain', 'entities')]);

    // Disable interactive prompts
    args.add('--no-fields');

    if (force) {
      args.add('--force');
    }

    if (dryRun) {
      print('Would run: zorphy ${args.join(' ')}');
      return path.join(
        outputDir,
        'domain',
        'entities',
        StringUtils.camelToSnake(spec.name),
        '${StringUtils.camelToSnake(spec.name)}.dart',
      );
    }

    // Execute zorphy_cli
    final result = await Process.run('zorphy', args);

    if (result.exitCode != 0) {
      print('❌ Failed to generate ${spec.name} via zorphy');
      if (verbose) {
        print('   stdout: ${result.stdout}');
        print('   stderr: ${result.stderr}');
      }
      return null;
    }

    if (verbose) {
      print('✅ Generated ${spec.name} via zorphy');
    }

    return path.join(
      outputDir,
      'domain',
      'entities',
      StringUtils.camelToSnake(spec.name),
      '${StringUtils.camelToSnake(spec.name)}.dart',
    );
  }

  /// Delegate enum generation to zorphy_cli
  Future<String?> _generateEnumViaZorphy(EnumSpec spec) async {
    // Check if zorphy is available
    final checkResult = await Process.run('which', ['zorphy']);
    if (checkResult.exitCode != 0) {
      print(
        '⚠️  zorphy CLI not found. Install with: dart pub global activate zorphy_annotation',
      );
      return null;
    }

    final args = <String>[
      'enum',
      '-n',
      spec.name,
      '--value',
      spec.values.join(','),
      '-o',
      path.join(outputDir, 'domain', 'entities'),
    ];

    if (force) {
      args.add('--force');
    }

    if (dryRun) {
      print('Would run: zorphy ${args.join(' ')}');
      return path.join(
        outputDir,
        'domain',
        'entities',
        'enums',
        '${StringUtils.camelToSnake(spec.name)}.dart',
      );
    }

    // Execute zorphy_cli
    final result = await Process.run('zorphy', args);

    if (result.exitCode != 0) {
      print('❌ Failed to generate enum ${spec.name} via zorphy');
      if (verbose) {
        print('   stdout: ${result.stdout}');
        print('   stderr: ${result.stderr}');
      }
      return null;
    }

    if (verbose) {
      print('✅ Generated enum ${spec.name} via zorphy');
    }

    return path.join(
      outputDir,
      'domain',
      'entities',
      'enums',
      '${StringUtils.camelToSnake(spec.name)}.dart',
    );
  }

  String _generateOperationContent(OperationSpec spec) {
    final typeName = spec.type[0].toUpperCase() + spec.type.substring(1);
    final varName = '${spec.name}$typeName';
    final gqlString = _generateGqlString(spec);
    final field = Field(
      (f) => f
        ..name = varName
        ..type = refer('String')
        ..modifier = FieldModifier.constant
        ..assignment = Code(_graphqlLiteral(gqlString))
        ..docs.add(
          '/// Generated GraphQL ${spec.type} for ${spec.operationName}',
        ),
    );
    final library = specLibrary.library(specs: [field]);
    return specLibrary.emitLibrary(library);
  }

  String _generateGqlString(OperationSpec spec) {
    final opName = spec.operationName;
    final argsSignature = spec.args.isNotEmpty
        ? '(${spec.args.map((arg) => '\$${arg.name}: ${arg.gqlType}').join(', ')})'
        : '';
    final callArgs = spec.args.isNotEmpty
        ? '(${spec.args.map((arg) => '${arg.name}: \$${arg.name}').join(', ')})'
        : '';
    final lines = <String>[];
    lines.add('  ${spec.type} $opName$argsSignature {');
    if (spec.returnFields.isNotEmpty) {
      lines.add('    ${spec.name}$callArgs {');
      for (final field in spec.returnFields) {
        if (field.referencedEntity == null) {
          lines.add('      ${field.name}');
        } else {
          lines.add('      ${field.name} { id }');
        }
      }
      lines.add('    }');
      lines.add('  }');
      lines.add('}');
      return lines.join('\n');
    }
    lines.add('    ${spec.name}$callArgs');
    lines.add('}');
    return lines.join('\n');
  }

  String _graphqlLiteral(String gqlString) {
    final escaped = gqlString.replaceAll(r'$', r'\$');
    return 'r"""$escaped"""';
  }
}
