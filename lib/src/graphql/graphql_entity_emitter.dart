/// Generates Zorphy-annotated Dart entity files from EntitySpec and EnumSpec.
library;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'graphql_schema_translator.dart';
import '../utils/string_utils.dart';

/// Emits Dart entity and enum files from GraphQL schema specifications.
class GraphQLEntityEmitter {
  final String outputDir;
  final bool useZorphy;
  final bool dryRun;
  final bool force;
  final bool verbose;

  GraphQLEntityEmitter({
    required this.outputDir,
    this.useZorphy = true,
    this.dryRun = false,
    this.force = false,
    this.verbose = false,
  });

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

    await Directory(dirPath).create(recursive: true);
    await File(filePath).writeAsString(content);

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
    await File(filePath).writeAsString(content);

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
    await File(filePath).writeAsString(content);

    if (verbose) {
      print('Generated: $filePath');
    }

    return filePath;
  }

  String _generateEntityContent(EntitySpec spec, String snakeName) {
    final buffer = StringBuffer();

    // Collect referenced entities for imports
    final referencedEntities = <String>{};
    for (final field in spec.fields) {
      if (field.referencedEntity != null) {
        referencedEntities.add(field.referencedEntity!);
      }
    }

    if (useZorphy) {
      buffer.writeln(
        "import 'package:zorphy_annotation/zorphy_annotation.dart';",
      );
      buffer.writeln();

      // Import referenced entities
      for (final entity in referencedEntities) {
        final entitySnake = StringUtils.camelToSnake(entity);
        buffer.writeln("import '../$entitySnake/$entitySnake.dart';");
      }
      if (referencedEntities.isNotEmpty) {
        buffer.writeln();
      }

      buffer.writeln("part '$snakeName.zorphy.dart';");
      buffer.writeln();

      // Add description as doc comment
      if (spec.description != null && spec.description!.isNotEmpty) {
        buffer.writeln('/// ${spec.description}');
      }

      buffer.writeln('@Zorphy(generateJson: true)');
      buffer.writeln('abstract class ${spec.name} {');

      for (final field in spec.fields) {
        if (field.description != null && field.description!.isNotEmpty) {
          buffer.writeln('  /// ${field.description}');
        }
        final nullableSuffix = field.isNullable ? '?' : '';
        buffer.writeln('  ${field.dartType}$nullableSuffix get ${field.name};');
      }

      buffer.writeln('}');
    } else {
      // Generate concrete immutable class without Zorphy

      // Import referenced entities
      for (final entity in referencedEntities) {
        final entitySnake = StringUtils.camelToSnake(entity);
        buffer.writeln("import '../$entitySnake/$entitySnake.dart';");
      }
      if (referencedEntities.isNotEmpty) {
        buffer.writeln();
      }

      // Add description as doc comment
      if (spec.description != null && spec.description!.isNotEmpty) {
        buffer.writeln('/// ${spec.description}');
      }

      buffer.writeln('class ${spec.name} {');

      // Fields
      for (final field in spec.fields) {
        if (field.description != null && field.description!.isNotEmpty) {
          buffer.writeln('  /// ${field.description}');
        }
        final nullableSuffix = field.isNullable ? '?' : '';
        buffer.writeln(
          '  final ${field.dartType}$nullableSuffix ${field.name};',
        );
      }

      buffer.writeln();

      // Constructor
      buffer.writeln('  const ${spec.name}({');
      for (final field in spec.fields) {
        final requiredPrefix = field.isNullable ? '' : 'required ';
        buffer.writeln('    ${requiredPrefix}this.${field.name},');
      }
      buffer.writeln('  });');

      buffer.writeln();

      // fromJson factory
      buffer.writeln(
        '  factory ${spec.name}.fromJson(Map<String, dynamic> json) {',
      );
      buffer.writeln('    return ${spec.name}(');
      for (final field in spec.fields) {
        final jsonAccess = _generateFromJsonField(field);
        buffer.writeln('      ${field.name}: $jsonAccess,');
      }
      buffer.writeln('    );');
      buffer.writeln('  }');

      buffer.writeln();

      // toJson method
      buffer.writeln('  Map<String, dynamic> toJson() {');
      buffer.writeln('    return {');
      for (final field in spec.fields) {
        final jsonValue = _generateToJsonField(field);
        buffer.writeln("      '${field.name}': $jsonValue,");
      }
      buffer.writeln('    };');
      buffer.writeln('  }');

      buffer.writeln('}');
    }

    return buffer.toString();
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
    final buffer = StringBuffer();

    if (useZorphy) {
      buffer.writeln(
        "import 'package:zorphy_annotation/zorphy_annotation.dart';",
      );
      buffer.writeln();

      // Add description as doc comment
      if (spec.description != null && spec.description!.isNotEmpty) {
        buffer.writeln('/// ${spec.description}');
      }

      buffer.writeln('@ZorphyEnum()');
      buffer.writeln('enum ${spec.name} {');

      for (var i = 0; i < spec.values.length; i++) {
        final value = spec.values[i];
        final camelValue = _toEnumCase(value);
        final comma = i < spec.values.length - 1 ? ',' : '';
        buffer.writeln('  $camelValue$comma');
      }

      buffer.writeln('}');
    } else {
      // Add description as doc comment
      if (spec.description != null && spec.description!.isNotEmpty) {
        buffer.writeln('/// ${spec.description}');
      }

      buffer.writeln('enum ${spec.name} {');

      for (var i = 0; i < spec.values.length; i++) {
        final value = spec.values[i];
        final camelValue = _toEnumCase(value);
        final comma = i < spec.values.length - 1 ? ',' : '';
        buffer.writeln('  $camelValue$comma');
      }

      buffer.writeln('}');
    }

    return buffer.toString();
  }

  String _generateOperationContent(OperationSpec spec) {
    final buffer = StringBuffer();
    final typeName = spec.type[0].toUpperCase() + spec.type.substring(1);
    final varName = '${spec.name}$typeName';

    buffer.writeln(
      '/// Generated GraphQL ${spec.type} for ${spec.operationName}',
    );
    buffer.writeln('const String $varName = r\'\'\'');
    buffer.writeln(_generateGqlString(spec));
    buffer.writeln('\'\'\';');

    return buffer.toString();
  }

  String _generateGqlString(OperationSpec spec) {
    final buf = StringBuffer();
    final opName = spec.operationName;

    buf.write('  ${spec.type} $opName');

    if (spec.args.isNotEmpty) {
      buf.write('(');
      for (var i = 0; i < spec.args.length; i++) {
        final arg = spec.args[i];
        buf.write('\$${arg.name}: ${arg.gqlType}');
        if (i < spec.args.length - 1) buf.write(', ');
      }
      buf.write(')');
    }

    buf.writeln(' {');
    buf.write('    ${spec.name}');

    if (spec.args.isNotEmpty) {
      buf.write('(');
      for (var i = 0; i < spec.args.length; i++) {
        final arg = spec.args[i];
        buf.write('${arg.name}: \$${arg.name}');
        if (i < spec.args.length - 1) buf.write(', ');
      }
      buf.write(')');
    }

    if (spec.returnFields.isNotEmpty) {
      buf.writeln(' {');
      for (final field in spec.returnFields) {
        if (field.referencedEntity == null) {
          buf.writeln('      ${field.name}');
        } else {
          buf.writeln('      ${field.name} { id }');
        }
      }
      buf.writeln('    }');
    }

    buf.writeln('  }');
    buf.write('}');

    return buf.toString();
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

    final buffer = StringBuffer(parts.first);
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isNotEmpty) {
        buffer.write(part[0].toUpperCase());
        buffer.write(part.substring(1));
      }
    }

    return buffer.toString();
  }
}
