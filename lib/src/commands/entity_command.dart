import 'dart:convert';
import 'dart:io';
import 'package:zorphy/zorphy.dart';
import '../config/zfa_config.dart';

class EntityCommand {
  Future<void> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      _printHelp();
      if (exitOnCompletion) exit(0);
      return;
    }

    final subCommand = args[0];

    final shouldBuild = args.contains('--build');
    final shouldFormat = args.contains('--dart-format');
    final subArgs = args
        .skip(1)
        .where((arg) => arg != '--build' && arg != '--dart-format')
        .toList();

    final config = ZfaConfig.load();
    final runBuild = shouldBuild || (config?.buildByDefault ?? false);
    final runFormat = shouldFormat || (config?.formatByDefault ?? false);

    try {
      switch (subCommand) {
        case 'create':
        case 'new':
          await _handleCreate(subCommand, subArgs, config);
          break;
        case 'enum':
          await _handleEnum(subArgs);
          break;
        case 'add-field':
          await _handleAddField(subArgs);
          break;
        case 'list':
          await _handleList(subArgs);
          break;
        case 'from-json':
          await _handleFromJson(subArgs, config);
          break;
        default:
          print('Unknown subcommand: $subCommand');
          _printHelp();
          if (exitOnCompletion) exit(1);
      }

      if (runBuild) {
        print('\n🔨 Running build_runner...');
        await _runBuild();
      }

      if (runFormat) {
        print('\n🎨 Formatting generated code...');
        await _runFormat();
      }
    } catch (e) {
      print('❌ Error: $e');
      if (exitOnCompletion) exit(1);
    }
  }

  Future<void> _handleCreate(
    String command,
    List<String> args,
    ZfaConfig? config,
  ) async {
    final parsed = _parseArgs(args);
    final name = parsed['name'] as String?;

    if (name == null || name.isEmpty) {
      print('Error: Entity name is required. Use -n or --name to specify.');
      exit(1);
    }

    final outputDir = parsed['output'] as String? ?? 'lib/src/domain/entities';
    final fields = _parseFields(parsed['field'] as List<String>?);
    final useFilter =
        parsed['filter'] == true || (config?.filterByDefault ?? false);

    final entityConfig = EntityConfig(
      name: name,
      outputDir: outputDir,
      fields: fields,
      generateJson: parsed['json'] as bool? ?? true,
      generateCopyWithFn: parsed['copywith-fn'] as bool? ?? false,
      generateCompareTo: parsed['compare'] as bool? ?? true,
      isSealed: parsed['sealed'] as bool? ?? false,
      isNonSealed: parsed['non-sealed'] as bool? ?? false,
      generateFilter: useFilter,
      extendsInterface: parsed['extends'] as String?,
      explicitSubtypes: (parsed['subtypes'] as List<String>?) ?? [],
      generateSubtypes: parsed['generate-subs'] as bool? ?? false,
      dryRun: parsed['dry-run'] as bool? ?? false,
    );

    final creator = EntityCreator(baseOutputDir: outputDir);
    final result = await creator.create(entityConfig);

    if (result.isSuccess) {
      print('✓ Created entity: ${result.filePath}');
      print('\n📋 Next steps:');
      print('  1. Run: dart run build_runner build');
      print('  2. Import and use your ${entityConfig.className} class');

      if (fields.isNotEmpty) {
        print('\n✨ Generated ${fields.length} fields:');
        for (final field in fields) {
          print('  - ${field.name}: ${field.fullType}');
        }
      }
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Future<void> _handleEnum(List<String> args) async {
    final parsed = _parseArgs(args);
    final name = parsed['name'] as String?;

    if (name == null || name.isEmpty) {
      print('Error: Enum name is required. Use -n or --name to specify.');
      exit(1);
    }

    final values = (parsed['value'] as List<String>?) ?? [];
    if (values.isEmpty) {
      print(
        'Error: Enum values are required. Use --value with comma-separated values.',
      );
      exit(1);
    }

    final enumConfig = EnumConfig(
      name: name,
      outputDir: parsed['output'] as String?,
      values: values,
      dryRun: parsed['dry-run'] as bool? ?? false,
    );

    final creator = EntityCreator(baseOutputDir: parsed['output'] as String?);
    final result = await creator.createEnum(enumConfig);

    if (result.isSuccess) {
      print('✓ Created enum: ${result.filePath}');
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Future<void> _handleAddField(List<String> args) async {
    final parsed = _parseArgs(args);
    final name = parsed['name'] as String?;

    if (name == null || name.isEmpty) {
      print('Error: Entity name is required. Use -n or --name to specify.');
      exit(1);
    }

    final fieldStrings = parsed['field'] as List<String>?;
    if (fieldStrings == null || fieldStrings.isEmpty) {
      print('Error: At least one field is required. Use --field to specify.');
      exit(1);
    }

    final fields = _parseFields(fieldStrings);
    final creator = EntityCreator(baseOutputDir: parsed['output'] as String?);
    final result = await creator.addFields(
      name,
      fields,
      outputDir: parsed['output'] as String?,
      dryRun: parsed['dry-run'] as bool? ?? false,
    );

    if (result.isSuccess) {
      print('✓ Added ${fields.length} field(s) to ${result.className}');
      for (final field in fields) {
        print('  + ${field.name}: ${field.fullType}');
      }
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Future<void> _handleList(List<String> args) async {
    final parsed = _parseArgs(args);
    final outputDir = parsed['output'] as String? ?? 'lib/src/domain/entities';
    final dir = Directory(outputDir);

    if (!await dir.exists()) {
      print('No entities found. Directory does not exist: $outputDir');
      return;
    }

    print('📂 Zorphy Entities in $outputDir:\n');

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final entityName = entity.path.split('/').last;
        final dartFile = File('${entity.path}/$entityName.dart');
        if (await dartFile.exists()) {
          final contents = await dartFile.readAsString();
          print('  📄 $entityName');
          if (contents.contains('generateJson: true'))
            print('     ✓ JSON support');
          if (contents.contains('abstract class \$\$'))
            print('     🔒 Sealed class');
        }
      }
    }
  }

  Future<void> _handleFromJson(List<String> args, ZfaConfig? config) async {
    final rest = args.where((a) => !a.startsWith('-')).toList();
    if (rest.isEmpty) {
      print('Error: JSON file path is required.');
      exit(1);
    }

    final jsonFile = File(rest.first);
    if (!await jsonFile.exists()) {
      print('Error: JSON file not found: ${jsonFile.path}');
      exit(1);
    }

    final parsed = _parseArgs(args);
    final content = await jsonFile.readAsString();
    final json = _parseJsonContent(content);

    final name =
        parsed['name'] as String? ??
        jsonFile.path.split('/').last.replaceAll('.json', '');
    final fields = _extractFieldsFromJson(json);

    final entityConfig = EntityConfig(
      name: name,
      outputDir: parsed['output'] as String?,
      fields: fields,
      generateJson: parsed['json'] as bool? ?? true,
      generateFilter:
          parsed['filter'] == true || (config?.filterByDefault ?? false),
      dryRun: parsed['dry-run'] as bool? ?? false,
    );

    final creator = EntityCreator(baseOutputDir: parsed['output'] as String?);
    final result = await creator.create(entityConfig);

    if (result.isSuccess) {
      print('✓ Created entity: ${result.filePath}');
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Map<String, dynamic> _parseArgs(List<String> args) {
    final result = <String, dynamic>{};
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--')) {
        final parts = arg.substring(2).split('=');
        final key = parts[0].replaceAll('-', '_');
        if (parts.length > 1) {
          final value = parts.sublist(1).join('=');
          _addValue(result, key, value);
        } else if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          _addValue(result, key, args[++i]);
        } else {
          result[key] = true;
        }
      } else if (arg.startsWith('-') && arg.length == 2) {
        final key = _shortFlagToKey(arg[1]);
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          _addValue(result, key, args[++i]);
        } else {
          result[key] = true;
        }
      }
    }
    return result;
  }

  void _addValue(Map<String, dynamic> result, String key, String value) {
    if (result.containsKey(key)) {
      final existing = result[key];
      if (existing is List<String>) {
        existing.add(value);
      } else {
        result[key] = [existing as String, value];
      }
    } else {
      result[key] = value;
    }
  }

  String _shortFlagToKey(String flag) {
    const mapping = {'n': 'name', 'o': 'output', 'p': 'package', 'f': 'field'};
    return mapping[flag] ?? flag;
  }

  List<FieldDefinition> _parseFields(dynamic fieldStrings) {
    if (fieldStrings == null) return [];

    final fields = <FieldDefinition>[];
    List<String> fieldList;
    if (fieldStrings is List<String>) {
      fieldList = fieldStrings;
    } else if (fieldStrings is String) {
      fieldList = [fieldStrings];
    } else {
      return fields;
    }

    for (final group in fieldList) {
      final parts = _smartSplit(group);
      for (final part in parts) {
        try {
          fields.add(FieldDefinition.parse(part));
        } catch (e) {
          print('Warning: $e');
        }
      }
    }
    return fields;
  }

  List<String> _smartSplit(String input) {
    final parts = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (final char in input.split('')) {
      if (char == '<') depth++;
      if (char == '>') depth--;
      if (char == ',' && depth == 0) {
        if (current.toString().trim().isNotEmpty) {
          parts.add(current.toString().trim());
        }
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.toString().trim().isNotEmpty) {
      parts.add(current.toString().trim());
    }
    return parts;
  }

  Map<String, dynamic> _parseJsonContent(String content) {
    return Map<String, dynamic>.from(
      const JsonDecoder().convert(content) as Map,
    );
  }

  List<FieldDefinition> _extractFieldsFromJson(Map<String, dynamic> json) {
    final fields = <FieldDefinition>[];
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      final isNullable = key.endsWith('?');
      final fieldName = isNullable ? key.substring(0, key.length - 1) : key;

      String type;
      if (value is Map<String, dynamic>) {
        final nestedName = NamingUtils.toPascalCase(fieldName);
        type = '\$$nestedName';
      } else if (value is List && value.isNotEmpty && value.first is Map) {
        final nestedName = NamingUtils.toPascalCase(_singularize(fieldName));
        type = 'List<\$$nestedName>';
      } else {
        type = _inferType(value);
      }

      fields.add(
        FieldDefinition(
          name: fieldName,
          type: type,
          nullable: isNullable || value == null,
        ),
      );
    }
    return fields;
  }

  String _inferType(dynamic value) {
    if (value == null) return 'dynamic';
    if (value is String)
      return DateTime.tryParse(value) != null ? 'DateTime' : 'String';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is List) return 'List<dynamic>';
    return 'dynamic';
  }

  String _singularize(String s) {
    if (s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
    if (s.endsWith('es')) return s.substring(0, s.length - 2);
    if (s.endsWith('s')) return s.substring(0, s.length - 1);
    return s;
  }

  Future<void> _runBuild() async {
    final process = await Process.start('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], mode: ProcessStartMode.inheritStdio);

    final exitCode = await process.exitCode;
    if (exitCode != 0) exit(exitCode);
  }

  Future<void> _runFormat() async {
    final process = await Process.start('dart', [
      'format',
      '.',
    ], mode: ProcessStartMode.inheritStdio);
    await process.exitCode;
  }

  void _printHelp() {
    print('''
zfa entity - Zorphy Entity Generation Commands

USAGE:
  zfa entity <subcommand> [options]

SUBCOMMANDS:
  create      Create a new Zorphy entity with fields
  new         Quick-create a simple entity (basic defaults)
  enum        Create a new Zorphy enum
  add-field   Add field(s) to an existing entity
  from-json   Create entity from JSON file
  list        List all Zorphy entities

CREATE COMMAND:
  zfa entity create -n <Name> [options]
  Options:
    -n, --name              Entity name (required)
    -o, --output            Output directory
    --json                  Enable JSON serialization (default: true)
    --filter                Enable type-safe filters
    --copywith-fn           Function-based copyWith
    --compare               Enable compareTo (default: true)
    --sealed                Create sealed class
    --non-sealed            Create non-sealed class
    --field                 Add field(s) "name:type"
    --extends               Interface to extend
    --subtypes              Explicit subtypes
    --generate-subs         Generate subtype files

EXAMPLES:
  zfa entity create -n User --field id:String --field name:String
  zfa entity create -n Product --field name:String --field price:double --filter
  zfa entity enum -n Status --value pending,active,completed
  zfa entity add-field -n User --field email:String?
  zfa entity list

For more information, visit: https://github.com/arrrrny/zorphy
''');
  }
}
