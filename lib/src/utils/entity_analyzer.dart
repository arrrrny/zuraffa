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

    // Use DiscoveryEngine to find the entity file anywhere in the project
    final discovery = DiscoveryEngine(projectRoot: outputDir, fileSystem: fs);
    final entityFile = discovery.findFileSync('$entitySnake.dart');

    try {
      if (entityFile == null) {
        return _getDefaultFields();
      }

      final content = fs.readSync(entityFile.path);
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
    // Check in enums/ directory first (index.dart or specific file)
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

    // Check in entities/ directory (legacy or direct)
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

  static List<String> _parseSuperTypes(
    String content,
    String targetEntityName,
  ) {
    final superTypes = <String>[];
    final classRegex = RegExp(
      r'(?:abstract\s+)?class\s+' +
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
      r'(?:abstract\s+)?class\s+' +
          RegExp.escape(targetEntityName) +
          r'(?:\s+extends\s+\w+)?(?:\s+implements\s+[\w\s,]+)?\s*\{',
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

  /// Detects if an entity is polymorphic (has explicitSubTypes in @Zorphy)
  /// Returns list of subtype names (without $ prefix)
  static List<String> getPolymorphicSubtypes(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityPath = p.join(
      outputDir,
      'domain',
      'entities',
      entitySnake,
      '$entitySnake.dart',
    );

    try {
      if (!fs.existsSync(entityPath)) return [];

      final content = fs.readSync(entityPath);

      // Look for @Zorphy annotation with explicitSubTypes
      final zorphyRegex = RegExp(
        r'@Zorphy\s*\([^)]*explicitSubTypes\s*:\s*\[([^\]]+)\]',
        multiLine: true,
        dotAll: true,
      );
      final match = zorphyRegex.firstMatch(content);

      if (match != null) {
        final subtypesStr = match.group(1);
        if (subtypesStr != null) {
          // Extract subtype names (e.g., $BarcodeUrlTemplate -> BarcodeUrlTemplate)
          final subtypeRegex = RegExp(r'\$(\w+)');
          final subtypes = subtypeRegex
              .allMatches(subtypesStr)
              .map((m) => m.group(1)!)
              .toList();
          return subtypes;
        }
      }
    } catch (e) {
      // Ignore errors
    }

    return [];
  }
}
