import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:zorphy/zorphy.dart';
import '../config/zfa_config.dart';
import '../utils/entity_type_validator.dart';
import '../utils/entity_utils.dart';
import '../utils/string_utils.dart';

class EntityCommand {
  static const String fixedEntityOutput = ZfaConfig.fixedEntityOutput;

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

    // Check dependencies before any entity operation
    final depCheck = _checkDependencies();
    if (depCheck != null) {
      print(depCheck);
      if (exitOnCompletion) exit(1);
      return;
    }

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
        case 'build':
          await _handleBuild(subArgs);
          break;
        case 'watch':
          await _handleWatch();
          break;
        case 'validate':
          await _handleValidate(subArgs);
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

  /// Check for required dependencies in pubspec.yaml
  /// Returns null if OK, or error message if dependencies missing
  String? _checkDependencies() {
    final pubspecFile = File('pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      return '''
❌ No pubspec.yaml found in current directory.

   Make sure you are in a Flutter/Dart project root.
   Run this command in the directory containing pubspec.yaml.
''';
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final missing = <String>[];

      if (!content.contains('zorphy_annotation:')) {
        missing.add('zorphy_annotation');
      }

      if (!content.contains('build_runner:')) {
        // Check in dev_dependencies section
        if (!content.contains('build_runner:')) {
          missing.add('build_runner (dev)');
        }
      }

      if (missing.isNotEmpty) {
        return '''
⚠️  Missing required dependencies in pubspec.yaml:

${missing.map((d) => '   • $d').join('\n')}

   Add them with:
   ${missing.contains('zorphy_annotation') ? 'dart pub add zorphy_annotation' : ''}
   ${missing.contains('build_runner (dev)') ? 'dart pub add dev:build_runner' : ''}

   Or run: zfa doctor
''';
      }

      return null;
    } catch (e) {
      return '❌ Could not read pubspec.yaml: $e';
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

    final outputDir = fixedEntityOutput;
    final fields = _parseFields([
      ..._asStringList(parsed['field']),
      ..._asStringList(parsed['fields']),
    ]);

    // Issue #303: refuse raw Dart-keyword field names (e.g. `in:String`)
    // up front — without this guard the CLI emits `String get in;`, which
    // is invalid Dart and only fails later at `zfa build` with a misleading
    // analyzer error. The user must remap the wire name with
    // `:json=<wire>` (e.g. `in_:String:json=in`).
    final bareKeywords = _findBareKeywordFields(fields);
    if (bareKeywords.isNotEmpty) {
      print('❌ Cannot create entity "$name": field name(s) are Dart keywords.');
      print('');
      for (final field in bareKeywords) {
        print(
          '  • ${field.name} — reserved word; cannot be used as a Dart '
          'identifier.',
        );
        print(
          '    Remap with the \'name:type:json=<wire>\' syntax, e.g. '
          "'${field.name}_:${field.type}:json=${field.name}'",
        );
      }
      print('');
      print('No files were written. See \'zfa entity --help\' for details.');
      exit(1);
    }

    // Validate field types BEFORE writing anything (issue #296):
    // if a referenced type is neither a primitive, an existing entity,
    // nor an existing enum, abort with a clear error so the entity is
    // never written with a bogus `$`-prefixed `InvalidType`.
    // `--allow-forward-refs` opts out for batch generation of cyclic schemas
    // (issue #308): the referenced entity will exist by build time.
    final allowForwardRefs = parsed['allow_forward_refs'] == true;
    final typeErrors = allowForwardRefs
        ? const <UnresolvedTypeError>[]
        : EntityTypeValidator.validate(
            fields: fields,
            outputDir: outputDir,
            selfEntityName: name,
          );
    if (typeErrors.isNotEmpty) {
      print(
        '❌ Cannot create entity "$name": field type(s) could not be resolved.',
      );
      print('');
      for (final err in typeErrors) {
        print('  • ${err.message}');
      }
      print('');
      print('No files were written. Resolve the above and re-run.');
      exit(1);
    }

    final useFilter =
        parsed['filter'] == true || (config?.filterByDefault ?? false);

    final entityConfig = EntityConfig(
      name: name,
      outputDir: outputDir,
      fields: fields,
      generateJson: parsed['json'] as bool? ?? true,
      generateCopyWithFn: parsed['copywith_fn'] as bool? ?? false,
      generateCompareTo: parsed['compare'] as bool? ?? true,
      isSealed: parsed['sealed'] as bool? ?? false,
      isNonSealed: parsed['non_sealed'] as bool? ?? false,
      generateFilter: useFilter,
      extendsInterface: parsed['extends'] as String?,
      explicitSubtypes: _asStringList(parsed['subtypes']),
      generateSubtypes: parsed['generate_subs'] as bool? ?? false,
      dryRun: parsed['dry_run'] as bool? ?? false,
      autoId: parsed['auto_id'] == true,
      kind: _parseKind(parsed['kind'] as String?),
      typeKey: parsed['type_key'] as String?,
      subtypeWireValue: parsed['subtype_wire_value'] as String?,
      staticMembers: _asStringList(parsed['static']),
    );

    final creator = EntityCreator(baseOutputDir: outputDir);
    final result = await creator.create(entityConfig);

    if (result.isSuccess) {
      await _fixEntityImports(result.filePath, fields, outputDir);

      // Add imports for explicit subtypes so the zorphy builder can resolve
      // them for polymorphic dispatch (fromJson/toJson with typeKey).
      if (entityConfig.explicitSubtypes.isNotEmpty) {
        await _addSubtypeImports(result.filePath, entityConfig.explicitSubtypes, outputDir);
      }

      print('✓ Created entity: ${result.filePath}');
      print('\n📋 Next steps:');
      print('  1. Run: zfa build');
      print('  2. Import and use your ${entityConfig.className} class');

      if (entityConfig.autoId) {
        _warnIfUuidMissing();
      }

      if (fields.isNotEmpty) {
        print('\n✨ Generated ${fields.length} fields:');
        for (final field in fields) {
          print('  - ${_formatFieldDisplay(field)}');
        }
      }
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  /// autoId entities reference `package:uuid/uuid.dart` in the generated
  /// code — warn when the app does not depend on it yet.
  void _warnIfUuidMissing() {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) return;
    try {
      final content = pubspecFile.readAsStringSync();
      if (content.contains(RegExp(r'^\s*uuid\s*:', multiLine: true))) return;
      print(
        '⚠️  Generated id uses package:uuid — add it with: dart pub add uuid',
      );
    } catch (_) {
      // Best-effort hint only.
    }
  }

  /// Parses the `--kind` flag: `entity` (default) or
  /// `value_object` / `valueObject`. Anything else aborts with a clear
  /// message.
  ZorphyKind _parseKind(String? kind) {
    switch (kind) {
      case null:
      case 'entity':
        return ZorphyKind.entity;
      case 'value_object':
      case 'valueObject':
      case 'value-object':
        return ZorphyKind.valueObject;
      default:
        print('❌ Unknown kind "$kind". Expected: entity | value_object.');
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

    final values = _asStringList(parsed['value']);
    if (values.isEmpty) {
      print(
        'Error: Enum values are required. Use --value with comma-separated values.',
      );
      exit(1);
    }

    final enumConfig = EnumConfig(
      name: name,
      outputDir: fixedEntityOutput,
      values: values,
      dryRun: parsed['dry_run'] as bool? ?? false,
    );

    final creator = EntityCreator(baseOutputDir: fixedEntityOutput);
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

    final fieldStrings = [
      ..._asStringList(parsed['field']),
      ..._asStringList(parsed['fields']),
    ];
    if (fieldStrings.isEmpty) {
      print(
        'Error: At least one field is required. Use --field or --fields to specify.',
      );
      exit(1);
    }

    final fields = _parseFields(fieldStrings);

    // Issue #303: same raw-keyword guard as `entity create` — refuse to
    // add a field whose Dart name is a reserved word without an explicit
    // `:json=<wire>` remap.
    final bareKeywords = _findBareKeywordFields(fields);
    if (bareKeywords.isNotEmpty) {
      print(
        '❌ Cannot add field(s) to "$name": field name(s) are Dart keywords.',
      );
      print('');
      for (final field in bareKeywords) {
        print(
          '  • ${field.name} — reserved word; cannot be used as a Dart '
          'identifier.',
        );
        print(
          '    Remap with the \'name:type:json=<wire>\' syntax, e.g. '
          "'${field.name}_:${field.type}:json=${field.name}'",
        );
      }
      print('');
      print('No files were modified. See \'zfa entity --help\' for details.');
      exit(1);
    }

    // Validate field types BEFORE writing anything (issue #296):
    // same guard as `entity create` — refuse to add fields whose types
    // cannot be resolved against the on-disk entity/enum layout.
    // `--allow-forward-refs` opts out (issue #308), same as `entity create`.
    final allowForwardRefs = parsed['allow_forward_refs'] == true;
    final typeErrors = allowForwardRefs
        ? const <UnresolvedTypeError>[]
        : EntityTypeValidator.validate(
            fields: fields,
            outputDir: fixedEntityOutput,
            selfEntityName: name,
          );
    if (typeErrors.isNotEmpty) {
      print(
        '❌ Cannot add field(s) to "$name": field type(s) could not be resolved.',
      );
      print('');
      for (final err in typeErrors) {
        print('  • ${err.message}');
      }
      print('');
      print('No files were modified. Resolve the above and re-run.');
      exit(1);
    }

    final creator = EntityCreator(baseOutputDir: fixedEntityOutput);
    final result = await creator.addFields(
      name,
      fields,
      outputDir: fixedEntityOutput,
      dryRun: parsed['dry_run'] as bool? ?? false,
    );

    if (result.isSuccess) {
      await _fixEntityImports(result.filePath, fields, fixedEntityOutput);
      print('✓ Added ${fields.length} field(s) to ${result.className}');
      for (final field in fields) {
        print('  + ${_formatFieldDisplay(field)}');
      }
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Future<void> _addSubtypeImports(
    String entityPath,
    List<String> explicitSubtypes,
    String outputDir,
  ) async {
    final file = File(entityPath);
    var content = await file.readAsString();

    for (final subtype in explicitSubtypes) {
      final stName = subtype.split(':').first.replaceAll(r'$', '').trim();
      if (stName.isEmpty) continue;
      final stSnake = StringUtils.camelToSnake(stName);
      final imp = "import '../$stSnake/$stSnake.dart';";
      if (!content.contains(imp)) {
        // Insert after the last import line
        final lastImportIdx = content.lastIndexOf('import ');
        final eolIdx = content.indexOf('\n', lastImportIdx);
        if (eolIdx != -1) {
          content = '${content.substring(0, eolIdx + 1)}$imp\n${content.substring(eolIdx + 1)}';
        }
      }
    }

    await file.writeAsString(content);
  }

  Future<void> _fixEntityImports(
    String filePath,
    List<FieldDefinition> fields,
    String outputDir,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    var content = await file.readAsString();
    final imports = <String>{};
    bool hasEnums = false;

    // Process field types
    for (final field in fields) {
      // External types (issue #349) are never entity/enum - skip import resolution.
      // External types (marked with ! prefix, e.g. url:!WebUri?) reference types
      // from external libraries (plugin wrappers, SDK classes, etc). The type name
      // is kept as-is (no $ prefix), and NO import is automatically emitted because
      // the CLI doesn't know which library defines the type. The user must manually
      // add the required import (e.g. import 'package:webview_flutter/webview_flutter.dart';)
      // to the generated entity file after generation, or include it in a custom template.
      if (field.isExternal) continue;
      final types = EntityUtils.extractEntityTypes(field.fullType);
      for (final type in types) {
        final typeSnake = StringUtils.camelToSnake(type);
        final potentialEntityPath = Directory(p.join(outputDir, typeSnake));

        if (await potentialEntityPath.exists()) {
          imports.add("import '../$typeSnake/$typeSnake.dart';");
        } else {
          // If not a primitive and not an entity directory, assume it's an enum
          hasEnums = true;
        }
      }
    }

    // Check for extends/implements clause and add transitive imports
    final parentMatches = RegExp(
      r'(?:extends|implements)\s+([\$\w\s,]+)',
    ).allMatches(content);

    for (final match in parentMatches) {
      final parentsList = match.group(1)!;
      final parents = parentsList
          .split(',')
          .map((s) => s.trim().replaceAll('\$', ''))
          .where((s) => s.isNotEmpty);

      for (final parentType in parents) {
        final parentSnake = StringUtils.camelToSnake(parentType);
        final parentEntityPath = p.join(
          outputDir,
          parentSnake,
          '$parentSnake.dart',
        );
        final parentFile = File(parentEntityPath);

        // Add import for parent entity
        imports.add("import '../$parentSnake/$parentSnake.dart';");

        // Parse parent entity to find its implements clauses
        if (await parentFile.exists()) {
          final parentContent = await parentFile.readAsString();
          final parentImplementsMatches = RegExp(
            r'implements\s+([\$\w\s,]+)',
          ).allMatches(parentContent);

          for (final implMatch in parentImplementsMatches) {
            final implementsList = implMatch.group(1)!;
            final interfaces = implementsList
                .split(',')
                .map((s) => s.trim().replaceAll('\$', ''))
                .where((s) => s.isNotEmpty);

            for (final interface in interfaces) {
              final interfaceSnake = StringUtils.camelToSnake(interface);
              final interfacePath = Directory(
                p.join(outputDir, interfaceSnake),
              );

              if (await interfacePath.exists()) {
                imports.add(
                  "import '../$interfaceSnake/$interfaceSnake.dart';",
                );
              }
            }
          }
        }
      }
    }

    if (hasEnums) {
      imports.add("import '../enums/index.dart';");
    }

    // Import explicit subtypes so the zorphy builder can resolve them
    // for polymorphic dispatch (fromJson/toJson with typeKey).
    // This is handled by the entity creation flow, not here.

    if (imports.isEmpty) return;

    var updated = content;
    for (final import in imports) {
      if (!updated.contains(import)) {
        // Insert after existing imports or at the top
        final lastImportMatch = RegExp(
          r'^import .*;',
          multiLine: true,
        ).allMatches(updated).toList();

        if (lastImportMatch.isEmpty) {
          updated = "$import\n$updated";
        } else {
          final insertPos = lastImportMatch.last.end;
          updated =
              "${updated.substring(0, insertPos)}\n$import${updated.substring(insertPos)}";
        }
      }
    }

    if (updated != content) {
      await file.writeAsString(updated);
    }
  }

  Future<void> _handleList(List<String> args) async {
    final outputDir = fixedEntityOutput;
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
          if (contents.contains('generateJson: true')) {
            print('     ✓ JSON support');
          }
          if (contents.contains('abstract class \$\$')) {
            print('     🔒 Sealed class');
          }
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
      outputDir: fixedEntityOutput,
      fields: fields,
      generateJson: parsed['json'] as bool? ?? true,
      generateFilter:
          parsed['filter'] == true || (config?.filterByDefault ?? false),
      dryRun: parsed['dry_run'] as bool? ?? false,
    );

    final creator = EntityCreator(baseOutputDir: fixedEntityOutput);
    final result = await creator.create(entityConfig);

    if (result.isSuccess) {
      print('✓ Created entity: ${result.filePath}');
      if (fields.isNotEmpty) {
        print('\n✨ Generated ${fields.length} fields:');
        for (final field in fields) {
          print('  - ${_formatFieldDisplay(field)}');
        }
      }
    } else {
      print('❌ ${result.error}');
      exit(1);
    }
  }

  Map<String, dynamic> _parseArgs(List<String> args) {
    final result = <String, dynamic>{};
    String? currentKey;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('--')) {
        final parts = arg.substring(2).split('=');
        final key = parts[0].replaceAll('-', '_');
        currentKey = key;
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
        currentKey = key;
        if (i + 1 < args.length && !args[i + 1].startsWith('-')) {
          _addValue(result, key, args[++i]);
        } else {
          result[key] = true;
        }
      } else {
        if (currentKey != null) {
          _addValue(result, currentKey, arg);
        } else {
          _addValue(result, 'rest', arg);
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
      } else if (existing is List) {
        result[key] = [...existing.map((e) => e.toString()), value];
      } else {
        result[key] = [existing.toString(), value];
      }
    } else {
      result[key] = value;
    }
  }

  String _shortFlagToKey(String flag) {
    const mapping = {
      'n': 'name',
      'o': 'output',
      'p': 'package',
      'f': 'field',
      'F': 'fields',
    };
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

  /// Dart reserved words (contextual + built-in) that cannot be used as a
  /// field identifier in generated entity source. Issue #303: when a user
  /// writes `--field in:String` the CLI used to emit `String get in;` —
  /// invalid Dart — and `zfa build` later failed with
  /// `'in' can't be used as an identifier because it's a keyword.`
  ///
  /// The intended workflow for a Dart-keyword JSON wire name is to pick a
  /// Dart-safe field name and remap the wire name via `:json=<wire>`
  /// (e.g. `in_:String:json=in`). [_findBareKeywordFields] refuses the
  /// bare-keyword form up front with an actionable error.
  /// Dart reserved words that CANNOT be used as a field identifier.
  /// Built-in identifiers (async, get, set, etc.) and contextual keywords
  /// (yield, required, etc.) are legal field names — only hard reserved words
  /// and true reserved-for-future-use words are rejected.
  /// See: https://dart.dev/language/keywords
  static const Set<String> _dartKeywords = {
    // Hard reserved words — cannot be identifiers.
    'abstract', 'as', 'assert', 'break', 'case', 'catch', 'class', 'const',
    'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic', 'else',
    'enum', 'export', 'extends', 'external', 'false', 'final', 'finally',
    'for', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late',
    'library', 'mixin', 'new', 'null', 'part', 'rethrow', 'return', 'static',
    'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void',
    'while', 'with',
    // Reserved for future use — may become reserved words in later Dart versions.
    'base', 'sealed', 'when', 'record', 'view',
  };

  bool _isDartKeyword(String name) => _dartKeywords.contains(name);

  /// Maps a raw JSON wire key to a Dart-safe (name, jsonName) pair.
  ///
  /// Rules (issue #303):
  /// - Dart keyword (`in`, `required`, ...): Dart name = `<key>_`, jsonName
  ///   = `<key>` (preserves the wire contract while keeping the Dart source
  ///   compilable). Example: `in` -> (`in_`, `in`).
  /// - Leading underscore (`_and`, `_or`): Dart name = `<key>` without the
  ///   leading underscore (a leading `_` would mark the member private),
  ///   jsonName = `<key>`. Example: `_and` -> (`and`, `_and`).
  /// - Anything else: returned as-is with a null jsonName (no `@JsonKey`
  ///   needed — the Dart name already matches the wire name).
  ///
  /// Used by `zfa entity from-json` (which has no field-string syntax to
  /// lean on) so that JSON payloads carrying Dart-keyword or `_`-prefixed
  /// keys produce compilable entities with the correct wire names.
  ({String dartName, String? jsonName}) _resolveFieldName(String jsonKey) {
    if (_isDartKeyword(jsonKey)) {
      return (dartName: '${jsonKey}_', jsonName: jsonKey);
    }
    if (jsonKey.startsWith('_') && jsonKey.length > 1) {
      return (dartName: jsonKey.substring(1), jsonName: jsonKey);
    }
    return (dartName: jsonKey, jsonName: null);
  }

  /// Issue #303 guard: refuses field definitions whose Dart name is a raw
  /// Dart keyword AND that do not carry an explicit `jsonName`. The user
  /// must use the `name:type:json=<wire>` syntax (e.g. `in_:String:json=in`)
  /// so the generated source stays compilable and the wire name is
  /// preserved. Returns the list of offending field definitions.
  List<FieldDefinition> _findBareKeywordFields(List<FieldDefinition> fields) {
    return fields
        .where((f) => f.jsonName == null && _isDartKeyword(f.name))
        .toList();
  }

  /// Pretty-prints a single field for success messages, appending
  /// `(json: '<wire>')` when the field carries an explicit json wire name
  /// (issue #303 — makes the remap visible to the caller).
  String _formatFieldDisplay(FieldDefinition field) {
    final base = '${field.name}: ${field.fullType}';
    if (field.jsonName != null && field.jsonName != field.name) {
      return "$base (json: '${field.jsonName}')";
    }
    return base;
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) return [];
    final List<String> result = [];
    if (value is List) {
      for (final item in value) {
        result.addAll(_smartSplit(item.toString()));
      }
    } else if (value is String) {
      result.addAll(_smartSplit(value));
    }

    return result.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _smartSplit(String input) {
    final parts = <String>[];
    var depth = 0;
    var current = <String>[];

    for (final char in input.split('')) {
      if (char == '<') depth++;
      if (char == '>') depth--;
      if (char == ',' && depth == 0) {
        if (current.join().trim().isNotEmpty) {
          parts.add(current.join().trim());
        }
        current = <String>[];
      } else {
        current.add(char);
      }
    }
    if (current.join().trim().isNotEmpty) {
      parts.add(current.join().trim());
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
      final rawKey = isNullable ? key.substring(0, key.length - 1) : key;

      // Issue #303: a JSON key may be a Dart keyword (`in`, `required`) or
      // carry a leading underscore (`_and`, `_or`) — neither is a valid
      // Dart identifier. Resolve to a Dart-safe (name, jsonName) pair so
      // the generated source compiles AND the wire contract is preserved.
      final resolved = _resolveFieldName(rawKey);
      final fieldName = resolved.dartName;
      final jsonName = resolved.jsonName;

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
          jsonName: jsonName,
        ),
      );
    }
    return fields;
  }

  String _inferType(dynamic value) {
    if (value == null) return 'dynamic';
    if (value is String) {
      return DateTime.tryParse(value) != null ? 'DateTime' : 'String';
    }
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

  Future<void> _handleBuild(List<String> subArgs) async {
    final args = ['run', 'build_runner', 'build'];
    if (subArgs.contains('--clean') || subArgs.contains('-c')) {
      args.insert(2, '--delete-conflicting-outputs');
    }
    if (subArgs.contains('--force')) {
      args.addAll(['--build-filter=**']);
    }
    final process = await Process.start('dart', args,
        mode: ProcessStartMode.inheritStdio);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      print('Build failed with exit code $exitCode');
    }
  }

  Future<void> _handleWatch() async {
    await Process.start(
      'dart',
      ['run', 'build_runner', 'watch', '--delete-conflicting-outputs'],
      mode: ProcessStartMode.inheritStdio,
    );
  }

  Future<void> _handleValidate(List<String> subArgs) async {
    // Scan entity dirs for missing generated files
    final dir = Directory(fixedEntityOutput);
    if (!await dir.exists()) {
      print('No entities found at $fixedEntityOutput');
      return;
    }
    int issues = 0;
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      final mainFile = File(p.join(entity.path, '$name.dart'));
      if (!await mainFile.exists()) continue;
      final content = await mainFile.readAsString();
      if (content.contains("part '$name.zorphy.dart'")) {
        final zorphy = File(p.join(entity.path, '$name.zorphy.dart'));
        if (!await zorphy.exists()) {
          print('  MISSING: $name.zorphy.dart');
          issues++;
        }
      }
      if (content.contains("part '$name.g.dart'")) {
        final g = File(p.join(entity.path, '$name.g.dart'));
        if (!await g.exists()) {
          print('  MISSING: $name.g.dart');
          issues++;
        }
      }
    }
    if (issues == 0) {
      print('✅ All entity files valid');
    } else {
      print('❌ $issues issue(s) found — run zfa build');
    }
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
        --output            Ignored in v5 (entities always generate under lib/src/domain/entities)
    --json                  Enable JSON serialization (default: true)
    --filter                Enable type-safe filters
    --copywith-fn           Function-based copyWith
    --compare               Enable compareTo (default: true)
    --sealed                Create sealed class
    --non-sealed            Create non-sealed class
    --type-key <key>        Custom JSON key for polymorphic dispatch (default: __typename)
    --subtype-wire-value    Custom wire value for this subtype in polymorphic JSON
    --field                 Add field "name:type"
    -F, --fields            Add multiple fields "name:type,name:type"
    --extends               Interface to extend
    --subtypes              Explicit subtypes
    --generate-subs         Generate subtype files
    --auto-id               Auto-generate a String id (uuid v4). The id
                            field is optional at construction and defaults
                            to a fresh uuid (adds uuid to your pubspec).
    --kind=<entity|value_object>
                            Semantic kind. value_object marks an immutable
                            composition type: no id required and `zfa make`
                            generates no repository/usecase/controller/
                            presenter for it.
    --static                Add static member "name:type:value" (e.g.
                            'DEFAULT_CLIENT:MyClass:MyClass(name: "default")')
    --allow-forward-refs    Skip on-disk type validation (batch generation of
                            cyclic schemas — referenced entity is created later).
                            For types that are NEVER entities (external classes
                            like plugin wrappers), use the `!Type` prefix
                            instead (see FIELD SYNTAX below).

ADD-FIELD COMMAND:
  zfa entity add-field -n <Name> [options]
  Options:
    -n, --name              Entity name (required)
    --field                 Add field "name:type"
    -F, --fields            Add multiple fields "name:type,name:type"
    --allow-forward-refs    Skip on-disk type validation (batch generation of
                            cyclic schemas — referenced entity is created later).
                            For types that are NEVER entities (external classes
                            like plugin wrappers), use the `!Type` prefix
                            instead (see FIELD SYNTAX below).

FIELD SYNTAX:
  name:type                 Basic field, Dart name = JSON wire name
                            (e.g. `id:String`, `note:String?`)
  name:!type                External type - the `!` prefix marks a type as
                            external (non-entity, non-enum). The type name is
                            kept as-is (no `\$` prefix), on-disk validation is
                            skipped, and no entity/enum import is emitted.
                            Use for types that live outside the entity tree,
                            e.g. plugin wrappers (`WebUri`), SDK classes, etc.
                            Example:
                              url:!WebUri?              # external WebUri type
  name:type:json=<wire>     Dart name differs from the JSON wire name.
                            Required when the wire name is a Dart keyword
                            (`in`, `required`) or starts with `_`
                            (Vendure `_and` / `_or`). Emits
                            `@JsonKey(name: '<wire>')` on the getter so
                            json_serializable serializes with the wire name.
                            Examples:
                              in_:String:json=in            # `in` wire key
                              and:ProductFilterParameter:json=_and
                              required:ConfigArgDef:json=required

  The same syntax is accepted by `--field` (single) and `-F/--fields`
  (comma-separated). `zfa entity from-json` resolves Dart-keyword and
  `_`-prefixed JSON keys automatically (no manual `:json=` needed).

EXAMPLES:
  zfa entity create -n User --field id:String --field name:String
  zfa entity create -n Product --field name:String --field price:double --filter
  zfa entity create -n ChatMessage --auto-id --field role:ChatMessageRole
    --field content:String --field timestamp:DateTime
  zfa entity create -n ParserConfig --kind=value_object
    --field separator:String --field trimWhitespace:bool
  # Vendure-style filter parameter with nested _and/_or composition:
  zfa entity create -n ProductFilterParameter --allow-forward-refs
    --field and:ProductFilterParameter:json=_and
    --field or:ProductFilterParameter:json=_or
  # External (non-entity) type - no \$ prefix, no import, no validation:
  zfa entity create -n JsAlertRequest --kind=value_object
    --field url:!WebUri? --field message:String?
  # IdOperators with `in` (Dart keyword) remapped to `in_`:
  zfa entity create -n IdOperators --field in_:String:json=in --field eq:String
  zfa entity enum -n Status --value pending,active,completed
  zfa entity add-field -n User --field email:String?
  zfa entity list

NOTES:
  - Entities always live under lib/src/domain/entities in Zuraffa v5.
  - Legacy --output values are accepted for compatibility but ignored.
  - Raw Dart-keyword field names (e.g. `--field in:String`) are rejected;
    remap with `:json=<wire>` so the generated source compiles.

For more information, visit: https://github.com/arrrrny/zorphy
''');
  }
}
