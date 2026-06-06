import '../core/plugin_system/discovery_engine.dart';
import '../core/context/file_system.dart';
import 'string_utils.dart';
import 'package:path/path.dart' as p;

class EntityAnalyzer {
  /// Analyzes an entity file to extract field information for mock data generation
  static Map<String, String> analyzeEntity(
    String entityName,
    String outputDir, {
    Set<String>? visited,
    FileSystem? fileSystem,
  }) {
    // This method is called synchronously in many places,
    // so we need a synchronous version of discovery/filesystem or use cached results.
    // For now, we'll try to use sync methods if available on the provided FileSystem.
    final fs = fileSystem ?? const DefaultFileSystem();
    final entitySnake = StringUtils.camelToSnake(entityName);
    visited ??= {};

    if (visited.contains(entityName)) return {};
    visited.add(entityName);

    final entityFilePath = _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fs,
    );

    try {
      if (entityFilePath == null) {
        return _getDefaultFields();
      }

      final content = fs.readSync(entityFilePath);
      final fields = <String, String>{};

      // Check if this is a Zorphy entity (contains @Zorphy annotation)
      if (content.contains('@Zorphy')) {
        // Try to parse from the generated .zorphy.dart file first
        final zorphyPath = p.join(
          outputDir,
          'domain',
          'entities',
          entitySnake,
          '$entitySnake.zorphy.dart',
        );
        if (fs.existsSync(zorphyPath)) {
          final zorphyContent = fs.readSync(zorphyPath);
          final zorphyFields = _parseEntityFields(zorphyContent, entityName);
          if (zorphyFields.isNotEmpty) {
            fields.addAll(zorphyFields);
          }
        }
      }

      // Parse current entity fields
      var currentFields = _parseEntityFields(content, entityName);
      if (currentFields.isEmpty) {
        currentFields = _parseEntityFields(content, '\$$entityName');
      }
      fields.addAll(currentFields);

      // Parse inheritance/implements
      final superTypes = _parseSuperTypes(content, entityName);
      if (superTypes.isEmpty) {
        superTypes.addAll(_parseSuperTypes(content, '\$$entityName'));
      }

      for (var superType in superTypes) {
        // Remove $ prefix if present for analysis
        final cleanSuperType = superType.startsWith('\$')
            ? superType.substring(1)
            : superType;
        final superFields = analyzeEntity(
          cleanSuperType,
          outputDir,
          visited: visited,
          fileSystem: fs,
        );
        // Add super fields if they don't overwrite existing ones
        for (final entry in superFields.entries) {
          if (!fields.containsKey(entry.key)) {
            fields[entry.key] = entry.value;
          }
        }
      }

      if (fields.isNotEmpty && !_hasOnlyDefaultFields(fields)) {
        return fields;
      }
    } catch (e) {
      // Continue to fallback
    }

    // Fallback to default fields if parsing fails
    return _getDefaultFields();
  }

  /// Checks if a type is an enum by looking for the enum keyword in its file.
  static bool isEnum(
    String typeName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final typeSnake = StringUtils.camelToSnake(typeName);
    final enumDir = p.join(outputDir, 'domain', 'entities', 'enums');
    final indexFile = p.join(enumDir, 'index.dart');
    if (fs.existsSync(indexFile)) {
      final content = fs.readSync(indexFile);
      if (content.contains('enum $typeName')) return true;
    }

    final enumPath = p.join(enumDir, '$typeSnake.dart');
    if (fs.existsSync(enumPath)) {
      final content = fs.readSync(enumPath);
      return content.contains('enum $typeName');
    }

    final entityPath = p.join(
      outputDir,
      'domain',
      'entities',
      typeSnake,
      '$typeSnake.dart',
    );
    if (fs.existsSync(entityPath)) {
      final content = fs.readSync(entityPath);
      return content.contains('enum $typeName');
    }

    return false;
  }

  static List<String> getEnumValues(
    String enumName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final typeSnake = StringUtils.camelToSnake(enumName);

    final pathsToCheck = <String>[
      p.join(outputDir, 'domain', 'entities', 'enums', 'index.dart'),
      p.join(outputDir, 'domain', 'entities', 'enums', '$typeSnake.dart'),
      p.join(outputDir, 'domain', 'entities', typeSnake, '$typeSnake.dart'),
    ];

    for (final path in pathsToCheck) {
      if (fs.existsSync(path)) {
        final content = fs.readSync(path);
        if (content.contains('enum $enumName')) {
          final valuesMatch = RegExp(
            r'enum\s+' + RegExp.escape(enumName) + r'\s*\{([^}]+)\}',
            dotAll: true,
          ).firstMatch(content);

          if (valuesMatch != null) {
            final body = valuesMatch.group(1)!;
            return RegExp(r'(\w+)')
                .allMatches(body)
                .map((m) => m.group(1)!)
                .where((v) => v != enumName && !v.startsWith('_'))
                .toList();
          }
        }
      }
    }

    return <String>[];
  }

  static List<String> _parseSuperTypes(
    String content,
    String targetEntityName,
  ) {
    final superTypes = <String>[];
    final classRegex = RegExp(
      r'(?:(?:abstract|sealed|base|final|interface)\s+)*class\s+' +
          RegExp.escape(targetEntityName) +
          r'(?:\s+extends\s+(\$?\w+))?(?:\s+implements\s+([\$?\w\s,]+))?\s*\{',
      multiLine: true,
    );
    final match = classRegex.firstMatch(content);

    if (match != null) {
      final extendsType = match.group(1);
      if (extendsType != null) {
        superTypes.add(extendsType.trim());
      }
      final implementsTypes = match.group(2);
      if (implementsTypes != null) {
        superTypes.addAll(
          implementsTypes
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
    }
    return superTypes;
  }

  static Map<String, String> _parseEntityFields(
    String content,
    String targetEntityName,
  ) {
    final fields = <String, String>{};

    // Find the specific class/abstract class definition by name
    final classRegex = RegExp(
      r'(?:(?:abstract|sealed|base|final|interface)\s+)*class\s+' +
          RegExp.escape(targetEntityName) +
          r'(?:\s+extends\s+\$?\w+)?(?:\s+implements\s+[\$?\w\s,]+)?\s*\{',
      multiLine: true,
    );
    final classMatch = classRegex.firstMatch(content);

    if (classMatch != null) {
      final startIndex = classMatch.end;

      // Find the matching closing brace using balanced brace counting
      int braceCount = 1;
      int endIndex = startIndex;

      for (int i = startIndex; i < content.length && braceCount > 0; i++) {
        if (content[i] == '{') {
          braceCount++;
        } else if (content[i] == '}') {
          braceCount--;
        }
        endIndex = i;
      }

      final classBody = content.substring(startIndex, endIndex);

      // Parse getter-style fields within this class body
      final getterRegex = RegExp(
        r'([\w\?\$<>,\s]+)\s+get\s+(\w+)\s*;',
        multiLine: true,
      );
      final getterMatches = getterRegex.allMatches(classBody);

      for (final match in getterMatches) {
        final type = match.group(1)?.trim();
        final name = match.group(2);

        if (type != null && name != null && !_isIgnoredField(name)) {
          fields[name] = type;
        }
      }

      // Parse field declarations within this class body
      final fieldRegex = RegExp(
        r'final\s+([\w\?\$<>,\s\[\]]+)\s+(\w+)\s*;',
        multiLine: true,
      );
      final fieldMatches = fieldRegex.allMatches(classBody);

      for (final match in fieldMatches) {
        final type = match.group(1)?.trim();
        final name = match.group(2);

        if (type != null && name != null && !_isIgnoredField(name)) {
          fields[name] = type;
        }
      }
    }

    // If no class-specific fields found, fall back to the old method
    if (fields.isEmpty) {
      // Parse getter-style fields: Type get fieldName;
      final getterRegex = RegExp(
        r'(\w+(?:\?)?(?:<[^>]+>)?)\s+get\s+(\w+)\s*;',
        multiLine: true,
      );
      final getterMatches = getterRegex.allMatches(content);

      for (final match in getterMatches) {
        final type = match.group(1);
        final name = match.group(2);

        if (type != null && name != null && !_isIgnoredField(name)) {
          fields[name] = type;
        }
      }
    }

    // If still no fields found, return defaults
    return fields.isEmpty ? _getDefaultFields() : fields;
  }

  static bool _isIgnoredField(String fieldName) {
    // Ignore common method names and reserved words
    final ignored = {
      'toString',
      'hashCode',
      'runtimeType',
      'props',
      'copyWith',
      'toJson',
      'fromJson',
      'when',
      'map',
      'maybeWhen',
      'maybeMap',
    };
    return ignored.contains(fieldName);
  }

  static Map<String, String> _getDefaultFields() {
    // NEVER use fallback fields - only use actual entity fields
    return {};
  }

  static bool _hasOnlyDefaultFields(Map<String, String> fields) {
    // Check if these are the default fallback fields
    final defaultKeys = {
      'id',
      'name',
      'description',
      'price',
      'category',
      'isActive',
      'createdAt',
      'updatedAt',
    };
    return fields.keys.toSet().containsAll(defaultKeys);
  }

  static bool entityFileExists(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    return _findEntitySourcePathSync(
          entityName,
          outputDir,
          fileSystem: fileSystem,
        ) !=
        null;
  }

  static bool isSealedEntity(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final entityFilePath = _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fs,
    );
    if (entityFilePath == null) return false;

    try {
      final content = fs.readSync(entityFilePath);
      final match = RegExp(
        r'^\s*((?:(?:abstract|sealed|base|final|interface)\s+)*)class\s+\$?' +
            RegExp.escape(entityName) +
            r'\b',
        multiLine: true,
      ).firstMatch(content);
      return (match?.group(1) ?? '').contains('sealed');
    } catch (_) {
      return false;
    }
  }

  static String getEntityImportPath(
    String entityName,
    String outputDir, {
    String fromDir = 'data/mock',
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    if (isEnum(entityName, outputDir, fileSystem: fs)) {
      return '../../domain/entities/enums/index.dart';
    }

    final entityFilePath = _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fs,
    );
    if (entityFilePath == null) {
      final entitySnake = StringUtils.camelToSnake(entityName);
      return '../../domain/entities/$entitySnake/$entitySnake.dart';
    }

    final fromPath = p.join(outputDir, fromDir);
    return p.posix.normalize(
      p.relative(entityFilePath, from: fromPath).replaceAll(p.separator, '/'),
    );
  }

  /// Detects if an entity is polymorphic (has explicitSubTypes in @Zorphy)
  /// or a sealed class hierarchy. Returns subtype names without a leading `$`.
  static List<String> getPolymorphicSubtypes(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final entityFilePath = _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fs,
    );

    try {
      if (entityFilePath == null) return [];

      final content = fs.readSync(entityFilePath);
      final subtypes = <String>{};
      subtypes.addAll(_detectZorphySubtypes(content));
      subtypes.addAll(_detectSealedSubtypes(content, entityName));
      return subtypes.toList();
    } catch (_) {
      return [];
    }
  }

  static List<String> _detectZorphySubtypes(String content) {
    final zorphyRegex = RegExp(
      r'@Zorphy\s*\([^)]*explicitSubTypes\s*:\s*\[([^\]]+)\]',
      multiLine: true,
      dotAll: true,
    );
    final match = zorphyRegex.firstMatch(content);
    final subtypesStr = match?.group(1);
    if (subtypesStr == null || subtypesStr.trim().isEmpty) {
      return [];
    }

    return subtypesStr
        .split(',')
        .map((part) => part.trim())
        .map((part) => RegExp(r'\$?(\w+)').firstMatch(part)?.group(1))
        .whereType<String>()
        .toList();
  }

  static List<String> _detectSealedSubtypes(String content, String entityName) {
    final sealedRootRegex = RegExp(
      r'^\s*((?:(?:abstract|sealed|base|final|interface)\s+)*)class\s+\$?' +
          RegExp.escape(entityName) +
          r'\b',
      multiLine: true,
    );
    final rootMatch = sealedRootRegex.firstMatch(content);
    final rootModifiers = rootMatch?.group(1) ?? '';
    if (!rootModifiers.contains('sealed')) {
      return [];
    }

    final declarationRegex = RegExp(
      r'^\s*((?:(?:abstract|sealed|base|final|interface)\s+)*)class\s+(\$?\w+)(?:\s+extends\s+(\$?\w+))?(?:\s+implements\s+[^\{]+)?\s*\{',
      multiLine: true,
    );

    final declarations = <String, ({String? parent, String modifiers})>{};
    final declarationOrder = <String>[];
    for (final match in declarationRegex.allMatches(content)) {
      final name = match.group(2);
      if (name == null) continue;
      declarations[name] = (
        parent: match.group(3),
        modifiers: (match.group(1) ?? '').trim(),
      );
      declarationOrder.add(name);
    }

    bool inheritsFromRoot(String current, Set<String> visited) {
      if (!visited.add(current)) return false;
      final declaration = declarations[current];
      if (declaration == null) return false;
      final parent = declaration.parent;
      if (parent == null) return false;
      if (_matchesEntityName(parent, entityName)) {
        return true;
      }
      return inheritsFromRoot(parent, visited);
    }

    final subtypes = <String>[];
    final seen = <String>{};
    for (final name in declarationOrder) {
      if (_matchesEntityName(name, entityName)) continue;
      final declaration = declarations[name];
      if (declaration == null) continue;
      if (!inheritsFromRoot(name, <String>{})) continue;

      final modifiers = declaration.modifiers;
      if (modifiers.contains('abstract') || modifiers.contains('sealed')) {
        continue;
      }

      final cleanName = name.startsWith(r'$') ? name.substring(1) : name;
      if (seen.add(cleanName)) {
        subtypes.add(cleanName);
      }
    }

    return subtypes;
  }

  static bool _matchesEntityName(String candidate, String entityName) {
    return candidate == entityName || candidate == '\$entityName';
  }

  static String? _findEntitySourcePathSync(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final entitySnake = StringUtils.camelToSnake(entityName);
    final discovery = DiscoveryEngine(projectRoot: outputDir, fileSystem: fs);
    final directMatch = discovery.findFileSync('$entitySnake.dart');
    if (directMatch != null) {
      final directPath = directMatch.path;
      try {
        final content = fs.readSync(directPath);
        if (_containsEntityDeclaration(content, entityName)) {
          return directPath;
        }
      } catch (_) {
        return directPath;
      }
    }

    final entitiesDir = p.join(outputDir, 'domain', 'entities');
    if (!fs.existsSync(entitiesDir) || !fs.isDirectorySync(entitiesDir)) {
      return directMatch?.path;
    }

    for (final filePath in fs.listSync(entitiesDir, recursive: true)) {
      if (!filePath.endsWith('.dart') ||
          filePath.endsWith('.g.dart') ||
          filePath.endsWith('.freezed.dart') ||
          filePath.endsWith('.zorphy.dart')) {
        continue;
      }

      try {
        final content = fs.readSync(filePath);
        if (_containsEntityDeclaration(content, entityName)) {
          return filePath;
        }
      } catch (_) {
        continue;
      }
    }

    return directMatch?.path;
  }

  static bool _containsEntityDeclaration(String content, String entityName) {
    final declarationRegex = RegExp(
      r'^\s*(?:(?:abstract|sealed|base|final|interface)\s+)*class\s+\$?' +
          RegExp.escape(entityName) +
          r'\b',
      multiLine: true,
    );
    if (declarationRegex.hasMatch(content)) {
      return true;
    }

    return RegExp(
      r'^\s*enum\s+' + RegExp.escape(entityName) + r'\b',
      multiLine: true,
    ).hasMatch(content);
  }
}
