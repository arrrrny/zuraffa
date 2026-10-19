import '../core/plugin_system/discovery_engine.dart';
import '../core/context/file_system.dart';
import 'crud_method_vocabulary.dart';
import 'entity_field_resolver.dart';
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
    return findEnumSourcePath(typeName, outputDir, fileSystem: fs) != null;
  }

  /// The file that declares [typeName] as an `enum`, or `null` when no
  /// candidate declares it.
  ///
  /// The probe order is the historical [isEnum] order — the conventional
  /// `enums/` barrel, a per-name `enums/<snake>.dart`, then the per-entity
  /// folder `<snake>/<snake>.dart`. Callers that need to IMPORT the enum go
  /// through this instead of assuming the barrel exists: a project may declare
  /// its enum in its own folder and carry no `enums/` directory at all
  /// (issue #1735).
  static String? findEnumSourcePath(
    String typeName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final typeSnake = StringUtils.camelToSnake(typeName);
    final enumDir = p.join(outputDir, 'domain', 'entities', 'enums');
    final candidates = <String>[
      p.join(enumDir, 'index.dart'),
      p.join(enumDir, '$typeSnake.dart'),
      p.join(outputDir, 'domain', 'entities', typeSnake, '$typeSnake.dart'),
    ];

    for (final candidate in candidates) {
      if (!fs.existsSync(candidate)) continue;
      if (fs.readSync(candidate).contains('enum $typeName')) return candidate;
    }

    return null;
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

  /// Public accessor for the discovered on-disk source path of [entityName]
  /// (issue #1856 review). Resolves enums and non-canonical entities via
  /// DiscoveryEngine instead of assuming `domain/entities/<snake>/<snake>.dart`.
  static String? findEntitySourcePath(
    String entityName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    return _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );
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

  /// True when [typeName]'s source IS on disk but declares no CRUD surface —
  /// issue #1747's shape, and the single predicate the mock lane shares
  /// between the builders that emit the class-shaped artifacts
  /// ([MockBuilder]) and the ones that emit the DI binding beside them
  /// ([MockPlugin]): both must agree, or the run leaves a binding importing
  /// a datasource that was never written.
  ///
  /// A target with no entity file at all is NOT this shape — there is
  /// nothing to probe, and that path keeps its historical behaviour.
  static bool lacksCrudSurface(
    String typeName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    return entityFileExists(typeName, outputDir, fileSystem: fs) &&
        !hasCrudSurface(typeName, outputDir, fileSystem: fs);
  }

  /// Issue #1898: the #1747 guard skips the class-shaped CRUD
  /// datasource/provider surface for types that declare no CRUD surface.
  /// A request that asks for ONLY non-CRUD verbs (`list`, or any verb
  /// not in the standard CRUD vocabulary) does not need that surface, so
  /// the guard must not fire for it — otherwise the `--methods` arm
  /// (#1787) is unreachable on exactly the input shape it was written
  /// for.
  ///
  /// The standard CRUD vocabulary is the shared
  /// [crudSurfaceMethodVocabulary] minus `list`; `list` and arbitrary
  /// verbs from issue #1823 are treated as non-CRUD requests.
  ///
  /// An EMPTY list means "CRUD": `GeneratorConfig.methods` defaults to
  /// `const []`, and these plugin entry points are public — the omitted
  /// default must keep the pre-#1898 guard behavior rather than emitting
  /// the non-compiling pair. The CLI normalizes an omitted `--methods`
  /// to `get,update,toggle`, so the shipped path is unaffected.
  static bool methodsRequireCrudSurface(Iterable<String> methods) {
    if (methods.isEmpty) return true;
    for (final method in methods) {
      if (crudSurfaceMethodVocabulary.contains(method)) return true;
    }
    return false;
  }

  /// True when [typeName] declares the CRUD surface the generated
  /// datasource / mock-datasource body calls (issue #1747): a `<Type>Patch`
  /// companion, a `copyWithField` method, and a resolvable identity field.
  ///
  /// A plain DTO or value class carries none of these, so emitting the
  /// class-shaped CRUD stack for it writes code the analyzer cannot compile
  /// (`<Type>Patch` isn't a type, `.id` isn't defined, `copyWithField` isn't
  /// defined) while the mock certification still reports `(conforms)`.
  ///
  /// The probe reads the entity source AND its `part` companions — a Zorphy
  /// entity's concrete class, its `copyWithField`, and its `<Type>Patch` all
  /// live in the generated `.zorphy.dart` part, which
  /// [_findEntitySourcePathSync] deliberately skips as a declaration site.
  static bool hasCrudSurface(
    String typeName,
    String outputDir, {
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final entityPath = _findEntitySourcePathSync(
      typeName,
      outputDir,
      fileSystem: fs,
    );
    if (entityPath == null) return false;

    final String surface;
    try {
      surface = _readEntitySurface(entityPath, fs);
    } catch (_) {
      return false;
    }

    // A value object is explicitly identity-free — never a CRUD entity.
    if (EntityFieldResolver.detectsValueObject(surface)) return false;

    if (!RegExp(
      r'\b(?:class|mixin|typedef)\s+' + RegExp.escape(typeName) + r'Patch\b',
    ).hasMatch(surface)) {
      return false;
    }
    if (!RegExp(r'\bcopyWithField\b').hasMatch(surface)) return false;

    return _hasIdentityField(surface);
  }

  /// [entityPath]'s source concatenated with every `part '…'` it pulls in.
  static String _readEntitySurface(String entityPath, FileSystem fs) {
    final content = fs.readSync(entityPath);
    final dir = p.dirname(entityPath);
    final buffer = StringBuffer(content);
    final partPattern = RegExp(
      r"""^\s*part\s+['\"]([^'\"]+)['\"]\s*;""",
      multiLine: true,
    );
    for (final match in partPattern.allMatches(content)) {
      final partPath = p.join(dir, match.group(1)!);
      if (fs.existsSync(partPath)) buffer.writeln(fs.readSync(partPath));
    }
    return buffer.toString();
  }

  /// True when [surface] declares an identity — a field literally named
  /// `id`, a field ending in `Id`, or `@Zorphy(autoId: true)`. The same
  /// resolution order `zfa make` applies (see [EntityFieldResolver]).
  static bool _hasIdentityField(String surface) {
    if (EntityFieldResolver.detectsAutoId(surface)) return true;
    for (final field in EntityFieldResolver.parseEntityFields(surface)) {
      if (field.name == 'id') return true;
      if (field.name.length > 2 && field.name.endsWith('Id')) return true;
    }
    return false;
  }

  /// The import a consumer in [fromDir] writes to bring [entityName] into
  /// scope, relative to its own directory.
  ///
  /// Enums resolve to the file that DECLARES them (issue #1735): assuming the
  /// conventional `domain/entities/enums/index.dart` barrel is only correct for
  /// projects that keep their enums there, and silently wrong — a
  /// `uri_does_not_exist` plus an unresolvable type — for the per-entity
  /// layout [findEnumSourcePath] already probes.
  static String getEntityImportPath(
    String entityName,
    String outputDir, {
    String fromDir = 'data/mock',
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final enumFilePath = findEnumSourcePath(
      entityName,
      outputDir,
      fileSystem: fs,
    );
    if (enumFilePath != null) {
      return _relativeImportPath(enumFilePath, outputDir, fromDir);
    }

    final entityFilePath = _findEntitySourcePathSync(
      entityName,
      outputDir,
      fileSystem: fs,
    );
    if (entityFilePath == null) {
      final entitySnake = StringUtils.camelToSnake(entityName);
      return '${_relativeUpPrefix(fromDir)}domain/entities/'
          '$entitySnake/$entitySnake.dart';
    }

    return _relativeImportPath(entityFilePath, outputDir, fromDir);
  }

  static String _relativeImportPath(
    String filePath,
    String outputDir,
    String fromDir,
  ) {
    final fromPath = p.join(outputDir, fromDir);
    return p.posix.normalize(
      p.relative(filePath, from: fromPath).replaceAll(p.separator, '/'),
    );
  }

  /// The `../` prefix that climbs from `<outputDir>/<fromDir>` back to
  /// `<outputDir>` — the depth of [fromDir], so the conventional-layout
  /// fallbacks below stay correct for a consumer that is not at `data/mock`.
  static String _relativeUpPrefix(String fromDir) {
    final depth = p.posix
        .split(fromDir.replaceAll(p.separator, '/'))
        .where((segment) => segment.isNotEmpty && segment != '.')
        .length;
    return '../' * depth;
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
      // Only treat the direct match as an entity source when it actually
      // declares the entity (#1747 nit): an unrelated file with the same
      // snake-cased name must not drive hasCrudSurface/lacksCrudSurface.
      if (directMatch != null) {
        try {
          final content = fs.readSync(directMatch.path);
          if (_containsEntityDeclaration(content, entityName)) {
            return directMatch.path;
          }
        } catch (_) {
          return directMatch.path;
        }
      }
      return null;
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

    // Final fallback: only the direct match that actually declares the
    // entity qualifies; otherwise there is no resolvable source.
    if (directMatch != null) {
      try {
        final content = fs.readSync(directMatch.path);
        if (_containsEntityDeclaration(content, entityName)) {
          return directMatch.path;
        }
      } catch (_) {
        return directMatch.path;
      }
    }
    return null;
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
