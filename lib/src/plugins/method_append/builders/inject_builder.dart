import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:analyzer/dart/ast/ast.dart' as ast;

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/ast_modifier.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/string_utils.dart';

class InjectBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final SpecLibrary specLibrary;

  InjectBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.specLibrary = const SpecLibrary(),
  });

  Future<List<GeneratedFile>> inject({
    required String targetClass,
    required String dependencyName,
    required String targetType, // 'provider', 'datasource', 'mock'
  }) async {
    final updatedFiles = <GeneratedFile>[];

    var finalDependencyName = dependencyName;
    if (targetType == 'mock') {
      // If we are in a mock, try to find the mock version of the dependency
      finalDependencyName = _getMockDependencyName(dependencyName);
    }

    // 1. Find the target file
    final targetFilePath = await _findTargetFile(targetClass, targetType);
    if (targetFilePath == null) {
      throw Exception('Target file not found for $targetClass');
    }

    // 2. Add field and constructor parameter to the target class
    final fileResult = await _injectIntoClass(
      targetFilePath,
      targetClass,
      finalDependencyName,
    );
    if (fileResult != null) {
      updatedFiles.add(fileResult);
    }

    // 3. Update DI registration
    final diResults = await _updateDiRegistration(
      targetClass,
      finalDependencyName,
      targetType,
    );
    updatedFiles.addAll(diResults);

    return updatedFiles;
  }

  String _getMockDependencyName(String original) {
    if (original.endsWith('Service')) {
      return original.replaceAll('Service', 'MockProvider');
    }
    if (original.endsWith('Repository')) {
      return original.replaceAll('Repository', 'MockDataSource');
    }
    if (original.endsWith('Provider')) {
      return original.replaceAll('Provider', 'MockProvider');
    }
    if (original.endsWith('DataSource')) {
      return original.replaceAll('DataSource', 'MockDataSource');
    }
    return '${original}Mock';
  }

  Future<String?> _findTargetFile(String className, String targetType) async {
    final snakeName = StringUtils.camelToSnake(className);

    // Search in providers
    if (targetType == 'provider' || targetType == 'mock') {
      final providersDir = Directory(path.join(outputDir, 'data', 'providers'));
      if (providersDir.existsSync()) {
        final files = providersDir.listSync(recursive: true);
        for (final file in files) {
          final fileName = path.basename(file.path);
          if (file is File && fileName == '$snakeName.dart') {
            return file.path;
          }
        }
      }
    }

    // Search in datasources
    if (targetType == 'datasource') {
      final dsDir = Directory(path.join(outputDir, 'data', 'datasources'));
      if (dsDir.existsSync()) {
        final files = dsDir.listSync(recursive: true);
        for (final file in files) {
          final fileName = path.basename(file.path);
          if (file is File) {
            // Standard snake case: MyRemoteDataSource -> my_remote_data_source.dart
            if (fileName == '$snakeName.dart') {
              return file.path;
            }

            // Zuraffa convention: MyRemoteDataSource -> my_remote_datasource.dart
            final zuraffaSnake = snakeName.replaceAll(
              '_data_source',
              '_datasource',
            );
            if (fileName == '$zuraffaSnake.dart') {
              return file.path;
            }

            // Also check for repo-based datasources: ListingRemoteDataSource -> listing_remote_datasource.dart
            // The folder might be 'listing' and the file 'listing_remote_datasource.dart'
            // If the class ends with RemoteDataSource or LocalDataSource, try to extract the base name
            if (className.endsWith('RemoteDataSource')) {
              final base = className.replaceAll('RemoteDataSource', '');
              final baseSnake = StringUtils.camelToSnake(base);
              if (fileName == '${baseSnake}_remote_datasource.dart') {
                return file.path;
              }
            }
            if (className.endsWith('LocalDataSource')) {
              final base = className.replaceAll('LocalDataSource', '');
              final baseSnake = StringUtils.camelToSnake(base);
              if (fileName == '${baseSnake}_local_datasource.dart') {
                return file.path;
              }
            }
            if (className.endsWith('DataSource')) {
              final base = className.replaceAll('DataSource', '');
              final baseSnake = StringUtils.camelToSnake(base);
              if (fileName == '${baseSnake}_datasource.dart') {
                return file.path;
              }
            }
          }
        }
      }
    }

    return null;
  }

  Future<GeneratedFile?> _injectIntoClass(
    String filePath,
    String className,
    String dependencyName,
  ) async {
    var source = await File(filePath).readAsString();
    final helper = const AstHelper();
    final parseResult = helper.parseSource(source);
    final unit = parseResult.unit;
    if (unit == null) return null;

    final classNode = helper.findClass(unit, className);
    if (classNode == null) return null;

    final publicName = StringUtils.pascalToCamel(dependencyName);
    final privateName = '_$publicName';

    if (!source.contains('final $dependencyName $privateName;')) {
      // 1. Add field at the top of the class
      final fieldSource = 'final $dependencyName $privateName;';
      final body = classNode.body;
      if (body is ast.BlockClassBody) {
        final insertOffset = body.leftBracket.offset + 1;
        final indent = '${_getIndent(source, classNode.offset)}  ';
        source = source.replaceRange(
          insertOffset,
          insertOffset,
          '\n$indent$fieldSource\n',
        );
      }
    }

    // 2. Add constructor parameter
    // This is a bit complex as we need to find or create a constructor.
    source = await _updateConstructor(
      source,
      className,
      publicName,
      privateName,
      dependencyName,
    );

    // 3. Add import
    final updatedSource = await _addDependencyImport(
      source,
      dependencyName,
      filePath,
    );

    await FileUtils.writeFile(
      filePath,
      updatedSource,
      'inject',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );

    return GeneratedFile(path: filePath, type: 'inject', action: 'updated');
  }

  Future<String> _updateConstructor(
    String source,
    String className,
    String publicName,
    String privateName,
    String dependencyName,
  ) async {
    final helper = const AstHelper();
    final unit = helper.parseSource(source).unit!;
    final classNode = helper.findClass(unit, className)!;

    final body = classNode.body;
    if (body is! ast.BlockClassBody) return source;

    final constructors = body.members.whereType<ast.ConstructorDeclaration>();

    if (constructors.isEmpty) {
      // Create new constructor
      final constructorSource =
          '$className({required $dependencyName $publicName}) : $privateName = $publicName;';

      // Try to insert after the last field
      final fields = body.members.whereType<ast.FieldDeclaration>();
      if (fields.isNotEmpty) {
        final lastField = fields.last;
        final insertOffset = lastField.end;
        final indent = _getIndent(source, lastField.offset);
        final insert = '\n\n$indent$constructorSource';
        return source.replaceRange(insertOffset, insertOffset, insert);
      }

      // If no fields, insert at the beginning of the class body
      final insertOffset = body.leftBracket.offset + 1;
      final indent = '${_getIndent(source, classNode.offset)}  ';
      final insert = '\n$indent$constructorSource';
      return source.replaceRange(insertOffset, insertOffset, insert);
    } else {
      // Update existing constructor
      final constructor = constructors.first;
      final params = constructor.parameters;

      if (params.parameters.isEmpty) {
        // No parameters, add named parameter and initializer
        final constructorSource =
            '{required $dependencyName $publicName}) : $privateName = $publicName';
        return source.replaceRange(
          params.leftParenthesis.offset + 1,
          params.rightParenthesis.offset + 1,
          constructorSource,
        );
      }

      // Check if parameter already exists
      final hasParam = params.parameters.any((p) {
        if (p is ast.DefaultFormalParameter) {
          return p.parameter.name?.lexeme == publicName;
        }
        return p.name?.lexeme == publicName;
      });

      String updatedSource = source;
      if (!hasParam) {
        final lastParam = params.parameters.last;
        if (lastParam is ast.DefaultFormalParameter &&
            lastParam.parameter.isNamed) {
          // Already has named parameters, just append
          updatedSource = source.replaceRange(
            lastParam.end,
            lastParam.end,
            ', required $dependencyName $publicName',
          );
        } else {
          // Has positional parameters, but no named ones yet?
          updatedSource = source.replaceRange(
            lastParam.end,
            lastParam.end,
            ', {required $dependencyName $publicName}',
          );
        }
      }

      // Re-parse to find the constructor again after parameter update (or use original if no change)
      final newUnit = helper.parseSource(updatedSource).unit!;
      final newClass = helper.findClass(newUnit, className)!;
      final newClassBody = newClass.body;
      if (newClassBody is! ast.BlockClassBody) return updatedSource;
      final newConstructor = newClassBody.members
          .whereType<ast.ConstructorDeclaration>()
          .first;

      // Check if initializer already exists
      final hasInitializer = newConstructor.initializers.any((i) {
        if (i is ast.ConstructorFieldInitializer) {
          return i.fieldName.name == privateName;
        }
        return false;
      });

      if (hasInitializer) {
        return updatedSource;
      }

      if (newConstructor.initializers.isEmpty) {
        // Add first initializer
        final bodyStart = newConstructor.body.offset;
        return updatedSource.replaceRange(
          bodyStart,
          bodyStart,
          ' : $privateName = $publicName ',
        );
      } else {
        // Append to existing initializers
        final lastInitializer = newConstructor.initializers.last;
        return updatedSource.replaceRange(
          lastInitializer.end,
          lastInitializer.end,
          ', $privateName = $publicName',
        );
      }
    }
  }

  Future<String> _addDependencyImport(
    String source,
    String dependencyName,
    String targetFilePath,
  ) async {
    // 1. Calculate possible snake case names for the dependency
    final dependencySnake = StringUtils.camelToSnake(
      dependencyName
          .replaceAll('Service', '')
          .replaceAll('Repository', '')
          .replaceAll('Provider', '')
          .replaceAll('DataSource', ''),
    );
    final fullDependencySnake = StringUtils.camelToSnake(dependencyName);

    // 2. Define standard search directories (prio)
    final searchDirs = [
      path.join(outputDir, 'domain', 'services'),
      path.join(outputDir, 'domain', 'repositories'),
      path.join(outputDir, 'data', 'providers'),
      path.join(outputDir, 'data', 'datasources'),
      path.join(outputDir, 'domain', 'entities'),
    ];

    // Also add the whole outputDir as backup
    final allSearchDirs = [...searchDirs, outputDir];
    final visited = <String>{};

    for (final dirPath in allSearchDirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && file.path.endsWith('.dart')) {
            final filePath = file.path;
            if (visited.contains(filePath)) continue;
            visited.add(filePath);

            final fileName = path.basename(filePath);

            // Check if file name matches snake case
            final nameMatch =
                fileName.contains(dependencySnake) ||
                fileName.contains(fullDependencySnake);

            if (nameMatch) {
              // Verify the file actually contains the class definition to avoid false positives
              final fileContent = await file.readAsString();
              if (fileContent.contains('class $dependencyName')) {
                final relativePath = path.relative(
                  filePath,
                  from: path.dirname(targetFilePath),
                );

                if (!source.contains(relativePath)) {
                  final helper = const AstHelper();
                  final parseResult = helper.parseSource(source);
                  final unit = parseResult.unit;
                  if (unit != null) {
                    return AstModifier.addImport(source, unit, relativePath);
                  }
                }
                return source;
              }
            }
          }
        }
      }
    }

    return source;
  }

  Future<List<GeneratedFile>> _updateDiRegistration(
    String targetClass,
    String dependencyName,
    String targetType,
  ) async {
    final updatedFiles = <GeneratedFile>[];
    final snakeName = StringUtils.camelToSnake(targetClass);
    final diFileName = '${snakeName}_di.dart';

    // Search for all DI files
    final diDir = Directory(path.join(outputDir, 'di'));
    if (!diDir.existsSync()) {
      diDir.createSync(recursive: true);
    }

    final files = diDir.listSync(recursive: true).whereType<File>().toList();
    final diFilesToUpdate = <File>[];

    final startPattern = '() => $targetClass(';

    for (final file in files) {
      if (file.path.endsWith('.dart')) {
        final content = await file.readAsString();
        if (content.contains(startPattern)) {
          diFilesToUpdate.add(file);
        }
      }
    }

    final fieldName = StringUtils.pascalToCamel(dependencyName);
    final dependencyCall = "getIt<$dependencyName>()";
    final namedDependencyCall = "$fieldName: $dependencyCall";

    if (diFilesToUpdate.isEmpty) {
      // Create new DI file ONLY if no existing registrations were found
      final diSubDir = targetType == 'provider' || targetType == 'mock'
          ? 'providers'
          : 'datasources';
      final newDiPath = path.join(outputDir, 'di', diSubDir, diFileName);

      if (File(newDiPath).existsSync()) {
        // If file exists but didn't contain the pattern, we should still try to use it if it's the right name
        diFilesToUpdate.add(File(newDiPath));
      } else {
        // Try to find the import for the target class
        String targetImport = "// TODO: Add missing import for $targetClass";
        final targetFile = await _findTargetFile(targetClass, targetType);
        if (targetFile != null) {
          final relPath = path.relative(
            targetFile,
            from: path.join(outputDir, 'di', diSubDir),
          );
          targetImport = "import '$relPath';";
        }

        final registrationName = 'register$targetClass';
        final content =
            '''
import 'package:get_it/get_it.dart';
$targetImport

void $registrationName(GetIt getIt) {
  getIt.registerLazySingleton<$targetClass>(
    () => $targetClass(
      $namedDependencyCall,
    ),
  );
}
''';
        await FileUtils.writeFile(
          newDiPath,
          content,
          'di_inject',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
        );

        return [
          GeneratedFile(path: newDiPath, type: 'di_inject', action: 'created'),
        ];
      }
    }

    for (final diFile in diFilesToUpdate) {
      var source = await diFile.readAsString();

      // Look for all instantiations in this file: () => TargetClass(...)
      int lastIdx = 0;
      bool updated = false;

      while (true) {
        final startIdx = source.indexOf(startPattern, lastIdx);
        if (startIdx == -1) break;

        final paramsStartIdx = startIdx + startPattern.length;

        // Find balanced closing parenthesis
        int balance = 1;
        int currentIdx = paramsStartIdx;
        while (balance > 0 && currentIdx < source.length) {
          if (source[currentIdx] == '(') {
            balance++;
          } else if (source[currentIdx] == ')') {
            balance--;
          }
          currentIdx++;
        }

        if (balance == 0) {
          final paramsEndIdx = currentIdx - 1;
          final existingParams = source.substring(paramsStartIdx, paramsEndIdx);
          String newParams;

          // Clean up existing params by removing both named and positional versions of the dependency if we're forcing
          var cleanedParams = existingParams;
          if (options.force) {
            // Remove named version: fieldName: getIt<DependencyName>()
            final namedRegex = RegExp(
              '\\s*$fieldName\\s*:\\s*getIt<\\s*$dependencyName\\s*>\\s*\\(\\s*\\)\\s*,?',
              dotAll: true,
            );
            // Remove positional version: getIt<DependencyName>()
            final positionalRegex = RegExp(
              '\\s*getIt<\\s*$dependencyName\\s*>\\s*\\(\\s*\\)\\s*,?',
              dotAll: true,
            );

            cleanedParams = cleanedParams
                .replaceAll(namedRegex, '')
                .replaceAll(positionalRegex, '');
          }

          if (cleanedParams.trim().isEmpty) {
            newParams = '\n      $namedDependencyCall,\n    ';
          } else {
            if (!options.force && existingParams.contains(fieldName)) {
              lastIdx = currentIdx;
              continue; // Already injected in this instantiation
            }

            if (!cleanedParams.contains(fieldName)) {
              // Check if it ends with a comma, if not add one
              final trimmedCleaned = cleanedParams.trimRight();
              if (trimmedCleaned.isNotEmpty && !trimmedCleaned.endsWith(',')) {
                newParams =
                    '$cleanedParams,\n      $namedDependencyCall,\n    ';
              } else {
                newParams = '$cleanedParams\n      $namedDependencyCall,\n    ';
              }
            } else {
              newParams = cleanedParams;
            }
          }

          source = source.replaceRange(paramsStartIdx, paramsEndIdx, newParams);
          lastIdx = paramsStartIdx + newParams.length;
          updated = true;
        } else {
          break;
        }
      }

      if (updated) {
        // Fix function signature if it was corrupted (only if it matches registerTargetClass)
        final signaturePattern = RegExp(
          'void\\s+register$targetClass\\(.*?\\)\\s*{',
        );
        if (source.contains(signaturePattern)) {
          source = source.replaceFirst(
            signaturePattern,
            'void register$targetClass(GetIt getIt) {',
          );
        }

        // Ensure dependency import is present in DI file
        source = await _addDependencyImport(
          source,
          dependencyName,
          diFile.path,
        );

        await FileUtils.writeFile(
          diFile.path,
          source,
          'di_inject',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
        );

        updatedFiles.add(
          GeneratedFile(
            path: diFile.path,
            type: 'di_inject',
            action: 'updated',
          ),
        );
      }
    }

    return updatedFiles;
  }

  String _getIndent(String source, int offset) {
    var lineStart = offset;
    while (lineStart > 0 && source[lineStart - 1] != '\n') {
      lineStart--;
    }
    return source.substring(lineStart, offset).replaceAll(RegExp(r'\S'), '');
  }
}
