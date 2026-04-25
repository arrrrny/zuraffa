import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../../core/constants/known_types.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generator_config.dart';
import '../../../models/parsed_usecase_info.dart';
import '../../../utils/string_utils.dart';

class CommonPatterns {
  static List<String> entityImports(
    List<String?> types,
    GeneratorConfig config, {
    int depth = 1,
    bool includeDomain = true,
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) {
    final fs = fileSystem ?? FileSystem.create(root: config.outputDir);

    final entities = <String>{};
    for (final type in types) {
      if (type == null) continue;
      final baseTypes = extractBaseTypes(type);
      for (final baseType in baseTypes) {
        if (!KnownTypes.isExcluded(baseType)) {
          entities.add(baseType);
        }
      }
    }

    final domainSnake = config.domain != null
        ? StringUtils.camelToSnake(config.domain!)
        : null;
    final prefix = '../' * depth;

    final results = <String>[];
    for (final entity in entities) {
      final entitySnake = StringUtils.camelToSnake(entity);
      var found = false;

      // 1. Try domain-specific entity directory first if domain is provided
      if (domainSnake != null) {
        final domainEntityDirPath = path.join(
          config.outputDir,
          'domain',
          'entities',
          domainSnake,
          entitySnake,
        );

        final domainEntityFilePath = path.join(
          domainEntityDirPath,
          '$entitySnake.dart',
        );

        if (fs.existsSync(domainEntityFilePath)) {
          results.add(
            '${prefix}domain/entities/$domainSnake/$entitySnake/$entitySnake.dart',
          );
          found = true;
        }

        if (!found) {
          final flatFilePath = path.join(
            config.outputDir,
            'domain',
            'entities',
            domainSnake,
            '$entitySnake.dart',
          );
          if (fs.existsSync(flatFilePath)) {
            results.add(
              '${prefix}domain/entities/$domainSnake/$entitySnake.dart',
            );
            found = true;
          }
        }
      }

      if (!found) {
        // 2. Try standard entity directory
        final entityDirPath = path.join(
          config.outputDir,
          'domain',
          'entities',
          entitySnake,
        );
        final entityFilePath = path.join(entityDirPath, '$entitySnake.dart');

        if (fs.existsSync(entityFilePath)) {
          results.add(
            '${prefix}domain/entities/$entitySnake/$entitySnake.dart',
          );
          found = true;
        }
      }

      if (!found) {
        // 3. Try legacy flat entity file
        final entityFilePath = path.join(
          config.outputDir,
          'domain',
          'entities',
          '$entitySnake.dart',
        );
        if (fs.existsSync(entityFilePath)) {
          // Check for enum
          final content = fs.readSync(entityFilePath);
          if (content.contains('enum $entity')) {
            results.add('${prefix}domain/entities/enums/index.dart');
          } else {
            results.add('${prefix}domain/entities/$entitySnake.dart');
          }
          found = true;
        }
      }

      if (!found) {
        // 4. Try enums/ directory
        final enumPath = path.join(
          config.outputDir,
          'domain',
          'entities',
          'enums',
          '$entitySnake.dart',
        );
        if (fs.existsSync(enumPath)) {
          results.add('${prefix}domain/entities/enums/index.dart');
          found = true;
        }
      }

      if (!found) {
        // 5. Check if it's in the same domain but specified without entities/ subdirectory
        if (domainSnake != null) {
          final altPath = path.join(
            config.outputDir,
            'domain',
            'entities',
            domainSnake,
            '$entitySnake.dart',
          );
          if (fs.existsSync(altPath)) {
            results.add(
              '${prefix}domain/entities/$domainSnake/$entitySnake.dart',
            );
            found = true;
          }
        }
      }

      if (!found) {
        results.add('${prefix}domain/entities/$entitySnake/$entitySnake.dart');
      }
    }

    return results.toSet().toList();
  }

  static Future<ParsedUseCaseInfo> parseUseCaseInfo(
    String u,
    GeneratorConfig config,
    String outputDir, {
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? FileSystem.create(root: outputDir);
    final className = u.endsWith('UseCase') ? u : '${u}UseCase';
    final fieldName = StringUtils.pascalToCamel(
      className.replaceAll('UseCase', ''),
    );
    final usecaseSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );

    // Try to find the file and parse params/returns
    String? paramsType = config.paramsType;
    String? returnsType = config.returnsType;
    String? useCaseType = config.useCaseType;

    final usecaseDomain = await findUseCaseDomain(
      usecaseSnake,
      config.effectiveDomain,
      outputDir,
      discovery: discovery,
      fileSystem: fs,
    );

    final filePath = path.join(
      outputDir,
      'domain',
      'usecases',
      usecaseDomain,
      '${usecaseSnake}_usecase.dart',
    );

    // Final check for existence
    if (await fs.exists(filePath)) {
      final content = await fs.read(filePath);
      final extendsMatch = RegExp(
        r'extends (UseCase|StreamUseCase|CompletableUseCase|SyncUseCase)<(.+)>',
      ).firstMatch(content);
      if (extendsMatch != null) {
        useCaseType = extendsMatch.group(1)?.toLowerCase();
        final typesStr = extendsMatch.group(2);
        if (typesStr != null) {
          final types = _splitByComma(typesStr);
          if (useCaseType == 'completableusecase') {
            useCaseType = 'completable';
            paramsType = types[0];
            returnsType = 'void';
          } else if (types.isNotEmpty) {
            returnsType = types[0];
            paramsType = types.length > 1 ? types[1] : 'NoParams';
            if (useCaseType == 'streamusecase') useCaseType = 'stream';
            if (useCaseType == 'syncusecase') useCaseType = 'sync';
            if (useCaseType == 'usecase') useCaseType = 'future';
          }
        }
      }
    } else {
      // If file not found, try to infer from name if it's a standard pattern
      // and we are in a feature context
      if (usecaseSnake.startsWith('get_') &&
          usecaseSnake.endsWith(StringUtils.camelToSnake(config.name))) {
        returnsType ??= config.name;
        paramsType ??= 'NoParams';
      } else if (usecaseSnake.startsWith('list_') &&
          usecaseSnake.endsWith(StringUtils.camelToSnake(config.name))) {
        returnsType ??= 'List<${config.name}>';
        paramsType ??= 'NoParams';
      }
    }

    return ParsedUseCaseInfo(
      className: className,
      fieldName: fieldName,
      paramsType: paramsType,
      returnsType: returnsType,
      useCaseType: useCaseType,
    );
  }

  static Future<String> findUseCaseDomain(
    String usecaseSnake,
    String defaultDomain,
    String outputDir, {
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? FileSystem.create(root: outputDir);
    // 1. If discovery engine is available, use it for ACTIVE discovery
    if (discovery != null) {
      final found = discovery.findFileSync(
        '${usecaseSnake}_usecase.dart',
        subDir: 'domain/usecases',
      );
      if (found != null) {
        // Return the parent folder name (the domain)
        return path.basename(path.dirname(found.path));
      }
    }

    final usecasesDir = path.join(outputDir, 'domain', 'usecases');
    if (await fs.exists(usecasesDir)) {
      final dirs = await fs.list(usecasesDir);
      for (final dir in dirs) {
        if (await fs.isDirectory(dir)) {
          final useCaseFile = path.join(dir, '${usecaseSnake}_usecase.dart');
          if (await fs.exists(useCaseFile)) {
            return path.basename(dir);
          }
        }
      }
    }
    // Try to find if it is an entity-based usecase
    final possiblePrefixes = [
      'get_',
      'create_',
      'update_',
      'delete_',
      'watch_',
    ];
    for (final prefix in possiblePrefixes) {
      if (usecaseSnake.startsWith(prefix)) {
        final entitySnake = usecaseSnake
            .replaceFirst(prefix, '')
            .replaceFirst('_list', '');
        return entitySnake;
      }
    }

    // Fallback to the default domain if not found
    return defaultDomain;
  }

  static List<String> extractBaseTypes(String type) {
    // 1. Remove nullable marker
    final cleanType = type.replaceAll('?', '').trim();
    if (cleanType.isEmpty || cleanType == 'void') return [];

    final results = <String>[];

    // 2. Handle "Type name" format from multiple params if it leaked here
    final spaceIndex = _findSpaceOutsideGenerics(cleanType);
    if (spaceIndex != -1) {
      final actualType = cleanType.substring(0, spaceIndex).trim();
      results.addAll(extractBaseTypes(actualType));
      return results;
    }

    // 3. Handle generic types like Stream<BarcodeListing?> or List<User>
    final genericMatch = RegExp(r'^(\w+)<(.+)>$').firstMatch(cleanType);
    if (genericMatch != null) {
      final outerType = genericMatch.group(1);
      if (outerType != null) {
        results.add(outerType);
      }
      final innerTypes = genericMatch.group(2);
      if (innerTypes != null) {
        // Split by comma but respect nested generics
        final parts = _splitByComma(innerTypes);
        for (final part in parts) {
          results.addAll(extractBaseTypes(part));
        }
      }
    } else {
      // 4. Simple type (e.g., Barcode, BarcodeListing)
      // Strip common suffixes for entity lookup
      var finalType = cleanType;
      if (finalType.endsWith('Patch') && finalType.length > 5) {
        finalType = finalType.substring(0, finalType.length - 5);
      }
      results.add(finalType);
    }

    return results;
  }

  static int _findSpaceOutsideGenerics(String input) {
    var bracketCount = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '<') bracketCount++;
      if (char == '>') bracketCount--;
      if (char == ' ' && bracketCount == 0) {
        return i;
      }
    }
    return -1;
  }

  static List<String> _splitByComma(String input) {
    final results = <String>[];
    var bracketCount = 0;
    var current = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '<') bracketCount++;
      if (char == '>') bracketCount--;
      if (char == ',' && bracketCount == 0) {
        results.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      results.add(current.toString().trim());
    }
    return results;
  }

  static Field finalField(String name, String type, {bool isLate = false}) {
    return Field(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..modifier = FieldModifier.final$
        ..late = isLate,
    );
  }

  static Parameter requiredNamedParam(String name, String type) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..required = true,
    );
  }

  static Parameter optionalNamedParam(
    String name,
    String type, {
    Code? defaultTo,
  }) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..defaultTo = defaultTo,
    );
  }

  static Constructor constructor({
    String? name,
    bool isConst = false,
    Iterable<Parameter> parameters = const [],
    Iterable<Code> initializers = const [],
    Code? body,
  }) {
    return Constructor((b) {
      b
        ..name = name
        ..constant = isConst
        ..initializers.addAll(initializers)
        ..body = body;
      for (final parameter in parameters) {
        if (parameter.named) {
          b.optionalParameters.add(parameter);
        } else {
          b.requiredParameters.add(parameter);
        }
      }
    });
  }

  static Method abstractMethod({
    required String name,
    required String returnType,
    Iterable<Parameter> parameters = const [],
  }) {
    return Method((b) {
      b
        ..name = name
        ..returns = refer(returnType);
      for (final parameter in parameters) {
        if (parameter.named) {
          b.optionalParameters.add(parameter);
        } else {
          b.requiredParameters.add(parameter);
        }
      }
    });
  }
}
