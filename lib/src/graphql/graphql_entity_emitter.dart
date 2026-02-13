/// Generates Zorphy-annotated Dart entity files from EntitySpec and EnumSpec.
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
  final bool useZorphy;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final SpecLibrary specLibrary;

  GraphQLEntityEmitter({
    required this.outputDir,
    this.useZorphy = true,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  /// Generates a Dart entity file from the given [spec].
  ///
  /// Returns the file path if generated, or null if skipped.
  Future<String?> generateEntity(EntitySpec spec) async {
    if (useZorphy) {
      return _generateEntityViaZorphy(spec);
    } else {
      return _generateEntityManually(spec);
    }
  }

  /// Generates a Dart enum file from the given [spec].
  ///
  /// Returns the file path if generated, or null if skipped.
  Future<String?> generateEnum(EnumSpec spec) async {
    if (useZorphy) {
      return _generateEnumViaZorphy(spec);
    } else {
      return _generateEnumManually(spec);
    }
  }

  /// Generates a GraphQL operation file (query or mutation).
  Future<String?> generateOperation(
    OperationSpec spec, {
    String? domain,
  }) async {
    final snakeName = StringUtils.camelToSnake(spec.name);
    final opType = spec.type;

    // Path: lib/src/data/data_sources/[domain]/graphql/[operation_name]_[type].dart
    final domainDir = domain ?? 'graphql';
    final dirPath = path.join(
      outputDir,
      'data',
      'data_sources',
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
      print('   Falling back to manual generation...');
      return _generateEntityManually(spec);
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
      print('   Falling back to manual generation...');
      return _generateEnumManually(spec);
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

  /// Fallback: Generate entity manually (when useZorphy is false)
  Future<String?> _generateEntityManually(EntitySpec spec) async {
    final snakeName = StringUtils.camelToSnake(spec.name);
    final dirPath = path.join(outputDir, 'domain', 'entities', snakeName);
    final filePath = path.join(dirPath, '$snakeName.dart');

    if (!force && await File(filePath).exists()) {
      if (verbose) {
        print('Skipping $filePath (already exists)');
      }
      return null;
    }

    final content = _generateEntityContent(spec, snakeName);

    if (dryRun) {
      print('Would generate: $filePath');
      if (verbose) {
        print(content);
      }
      return filePath;
    }

    await Directory(dirPath).create(recursive: true);
    await FileUtils.writeFile(
      filePath,
      content,
      'graphql_entity',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );

    if (verbose) {
      print('Generated: $filePath');
    }

    return filePath;
  }

  /// Fallback: Generate enum manually (when useZorphy is false)
  Future<String?> _generateEnumManually(EnumSpec spec) async {
    final snakeName = StringUtils.camelToSnake(spec.name);
    final dirPath = path.join(outputDir, 'domain', 'entities', 'enums');
    final filePath = path.join(dirPath, '$snakeName.dart');

    if (!force && await File(filePath).exists()) {
      if (verbose) {
        print('Skipping $filePath (already exists)');
      }
      return null;
    }

    final content = _generateEnumContent(spec, snakeName);

    if (dryRun) {
      print('Would generate: $filePath');
      if (verbose) {
        print(content);
      }
      return filePath;
    }

    await Directory(dirPath).create(recursive: true);
    await FileUtils.writeFile(
      filePath,
      content,
      'graphql_entity',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
    );

    if (verbose) {
      print('Generated: $filePath');
    }

    return filePath;
  }

  String _generateEntityContent(EntitySpec spec, String snakeName) {
    final directives = <Directive>[];
    final referencedEntities = <String>{};
    for (final field in spec.fields) {
      if (field.referencedEntity != null) {
        referencedEntities.add(field.referencedEntity!);
      }
    }

    if (useZorphy) {
      directives.add(
        Directive.import('package:zorphy_annotation/zorphy_annotation.dart'),
      );
    }

    for (final entity in referencedEntities) {
      final entitySnake = StringUtils.camelToSnake(entity);
      directives.add(Directive.import('../$entitySnake/$entitySnake.dart'));
    }
    if (useZorphy) {
      directives.add(Directive.part('$snakeName.zorphy.dart'));
    }

    final classSpec = useZorphy
        ? _buildZorphyEntityClass(spec)
        : _buildEntityClass(spec);
    final library = specLibrary.library(
      specs: [classSpec],
      directives: directives,
    );
    return specLibrary.emitLibrary(library);
  }

  String _generateFromJsonField(FieldSpec field) {
    final jsonKey = "json['${field.name}']";

    if (field.referencedEntity != null) {
      if (field.isList) {
        if (field.isNullable) {
          return "$jsonKey != null ? ($jsonKey as List).map((e) => ${field.referencedEntity}.fromJson(e as Map<String, dynamic>)).toList() : null";
        } else {
          return "($jsonKey as List).map((e) => ${field.referencedEntity}.fromJson(e as Map<String, dynamic>)).toList()";
        }
      } else {
        if (field.isNullable) {
          return "$jsonKey != null ? ${field.referencedEntity}.fromJson($jsonKey as Map<String, dynamic>) : null";
        } else {
          return "${field.referencedEntity}.fromJson($jsonKey as Map<String, dynamic>)";
        }
      }
    }

    // Handle primitives and built-in types
    final baseType = field.isList
        ? field.dartType.replaceFirst('List<', '').replaceFirst('>', '')
        : field.dartType;

    if (field.isList) {
      final castType = _getCastType(baseType);
      if (field.isNullable) {
        return "$jsonKey != null ? ($jsonKey as List).map((e) => e as $castType).toList() : null";
      } else {
        return "($jsonKey as List).map((e) => e as $castType).toList()";
      }
    }

    if (baseType == 'DateTime') {
      if (field.isNullable) {
        return "$jsonKey != null ? DateTime.parse($jsonKey as String) : null";
      } else {
        return "DateTime.parse($jsonKey as String)";
      }
    }

    final castType = _getCastType(baseType);
    if (field.isNullable) {
      return "$jsonKey as $castType?";
    } else {
      return "$jsonKey as $castType";
    }
  }

  String _generateToJsonField(FieldSpec field) {
    final fieldAccess = field.name;

    if (field.referencedEntity != null) {
      if (field.isList) {
        if (field.isNullable) {
          return "$fieldAccess?.map((e) => e.toJson()).toList()";
        } else {
          return "$fieldAccess.map((e) => e.toJson()).toList()";
        }
      } else {
        if (field.isNullable) {
          return "$fieldAccess?.toJson()";
        } else {
          return "$fieldAccess.toJson()";
        }
      }
    }

    // Handle DateTime
    final baseType = field.isList
        ? field.dartType.replaceFirst('List<', '').replaceFirst('>', '')
        : field.dartType;

    if (baseType == 'DateTime') {
      if (field.isList) {
        if (field.isNullable) {
          return "$fieldAccess?.map((e) => e.toIso8601String()).toList()";
        } else {
          return "$fieldAccess.map((e) => e.toIso8601String()).toList()";
        }
      } else {
        if (field.isNullable) {
          return "$fieldAccess?.toIso8601String()";
        } else {
          return "$fieldAccess.toIso8601String()";
        }
      }
    }

    return fieldAccess;
  }

  String _getCastType(String dartType) {
    switch (dartType) {
      case 'int':
      case 'double':
      case 'bool':
      case 'String':
        return dartType;
      case 'Map<String, dynamic>':
        return 'Map<String, dynamic>';
      default:
        return 'dynamic';
    }
  }

  String _generateEnumContent(EnumSpec spec, String snakeName) {
    final directives = <Directive>[];
    if (useZorphy) {
      directives.add(
        Directive.import('package:zorphy_annotation/zorphy_annotation.dart'),
      );
    }

    final enumSpec = Enum((e) {
      e
        ..name = spec.name
        ..values.addAll(
          spec.values.map(
            (value) => EnumValue((v) => v..name = _toEnumCase(value)),
          ),
        );
      if (useZorphy) {
        e.annotations.add(refer('ZorphyEnum').call([]));
      }
      if (spec.description != null && spec.description!.isNotEmpty) {
        e.docs.add('/// ${spec.description}');
      }
    });
    final library = specLibrary.library(
      specs: [enumSpec],
      directives: directives,
    );
    return specLibrary.emitLibrary(library);
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

  String _fieldType(FieldSpec field) {
    final nullableSuffix = field.isNullable ? '?' : '';
    return '${field.dartType}$nullableSuffix';
  }

  Class _buildZorphyEntityClass(EntitySpec spec) {
    final getters = spec.fields.map((field) {
      return Method((m) {
        m
          ..name = field.name
          ..returns = refer(_fieldType(field))
          ..type = MethodType.getter;
        if (field.description != null && field.description!.isNotEmpty) {
          m.docs.add('/// ${field.description}');
        }
      });
    }).toList();

    return Class((c) {
      c
        ..name = spec.name
        ..abstract = true
        ..annotations.add(
          refer('Zorphy').call([], {'generateJson': literalBool(true)}),
        )
        ..methods.addAll(getters);
      if (spec.description != null && spec.description!.isNotEmpty) {
        c.docs.add('/// ${spec.description}');
      }
    });
  }

  Class _buildEntityClass(EntitySpec spec) {
    final fields = spec.fields.map((field) {
      return Field((f) {
        f
          ..modifier = FieldModifier.final$
          ..type = refer(_fieldType(field))
          ..name = field.name;
        if (field.description != null && field.description!.isNotEmpty) {
          f.docs.add('/// ${field.description}');
        }
      });
    }).toList();

    final constructor = Constructor(
      (c) => c
        ..constant = true
        ..optionalParameters.addAll(
          spec.fields.map(
            (field) => Parameter(
              (p) => p
                ..name = field.name
                ..toThis = true
                ..named = true
                ..required = !field.isNullable,
            ),
          ),
        ),
    );

    final fromJson = Constructor(
      (c) => c
        ..factory = true
        ..name = 'fromJson'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'json'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = Code(_buildFromJsonBody(spec)),
    );

    final toJson = Method(
      (m) => m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code(_buildToJsonBody(spec)),
    );

    return Class((c) {
      c
        ..name = spec.name
        ..fields.addAll(fields)
        ..constructors.addAll([constructor, fromJson])
        ..methods.add(toJson);
      if (spec.description != null && spec.description!.isNotEmpty) {
        c.docs.add('/// ${spec.description}');
      }
    });
  }

  String _buildFromJsonBody(EntitySpec spec) {
    final lines = <String>['return ${spec.name}('];
    for (final field in spec.fields) {
      final jsonAccess = _generateFromJsonField(field);
      lines.add('  ${field.name}: $jsonAccess,');
    }
    lines.add(');');
    return lines.join('\n');
  }

  String _buildToJsonBody(EntitySpec spec) {
    final lines = <String>['return {'];
    for (final field in spec.fields) {
      final jsonValue = _generateToJsonField(field);
      lines.add("  '${field.name}': $jsonValue,");
    }
    lines.add('};');
    return lines.join('\n');
  }

  /// Converts SCREAMING_SNAKE_CASE to camelCase.
  ///
  /// Examples:
  /// - ACTIVE → active
  /// - SOME_VALUE → someValue
  /// - MY_LONG_ENUM_VALUE → myLongEnumValue
  String _toEnumCase(String value) {
    if (value.isEmpty) return value;

    final parts = value.toLowerCase().split('_');
    if (parts.isEmpty) return value.toLowerCase();
    final tail = parts
        .skip(1)
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1));
    return parts.first + tail.join();
  }
}
