import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import 'package:analyzer/dart/ast/ast.dart' as ast;

import '../../../core/ast/ast_helper.dart';
import '../../../core/ast/ast_modifier.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../core/generator_options.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
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
    final diResult = await _updateDiRegistration(
      targetClass,
      finalDependencyName,
      targetType,
    );
    if (diResult != null) {
      updatedFiles.add(diResult);
    }

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
          if (file is File && file.path.endsWith('${snakeName}.dart')) {
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
          if (file is File && file.path.endsWith('${snakeName}.dart')) {
            return file.path;
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
    
    // Check if already injected
    if (source.contains('final $dependencyName $privateName;')) {
      return null;
    }

    // 1. Add field at the top of the class
    final fieldSource = 'final $dependencyName $privateName;';
    final insertOffset = classNode.leftBracket.offset + 1;
    final indent = _getIndent(source, classNode.offset) + '  ';
    source = source.replaceRange(insertOffset, insertOffset, '\n$indent$fieldSource\n');

    // 2. Add constructor parameter
    // This is a bit complex as we need to find or create a constructor.
    source = await _updateConstructor(source, className, publicName, privateName, dependencyName);

    // 3. Add import
    source = await _addDependencyImport(source, dependencyName, filePath);

    await FileUtils.writeFile(
      filePath,
      source,
      'inject',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
    );

    return GeneratedFile(
      path: filePath,
      type: 'inject',
      action: 'updated',
    );
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

    final constructors = classNode.members.whereType<ast.ConstructorDeclaration>();
    
    if (constructors.isEmpty) {
      // Create new constructor
      final constructorSource = '$className({required $dependencyName $publicName}) : $privateName = $publicName;';
      
      // Try to insert after the last field
      final fields = classNode.members.whereType<ast.FieldDeclaration>();
      if (fields.isNotEmpty) {
        final lastField = fields.last;
        final insertOffset = lastField.end;
        final indent = _getIndent(source, lastField.offset);
        final insert = '\n\n$indent$constructorSource';
        return source.replaceRange(insertOffset, insertOffset, insert);
      }

      // If no fields, insert at the beginning of the class body
      final insertOffset = classNode.leftBracket.offset + 1;
      final indent = _getIndent(source, classNode.offset) + '  ';
      final insert = '\n$indent$constructorSource';
      return source.replaceRange(insertOffset, insertOffset, insert);
    } else {
      // Update existing constructor
      final constructor = constructors.first;
      final params = constructor.parameters;
      final insertOffset = params.rightParenthesis.offset;

      if (params.parameters.isEmpty) {
        // No parameters, add named parameter and initializer
        final constructorSource = '{required $dependencyName $publicName}) : $privateName = $publicName';
        return source.replaceRange(params.leftParenthesis.offset + 1, params.rightParenthesis.offset + 1, constructorSource);
      }

      final lastParam = params.parameters.last;
      String updatedSource;
      if (lastParam is ast.DefaultFormalParameter && lastParam.parameter.isNamed) {
        // Already has named parameters, just append
        updatedSource = source.replaceRange(lastParam.end, lastParam.end, ', required $dependencyName $publicName');
      } else {
        // Has positional parameters, but no named ones yet?
        updatedSource = source.replaceRange(lastParam.end, lastParam.end, ', {required $dependencyName $publicName}');
      }

      // Re-parse to find the constructor again after parameter update
      final newUnit = helper.parseSource(updatedSource).unit!;
      final newClass = helper.findClass(newUnit, className)!;
      final newConstructor = newClass.members.whereType<ast.ConstructorDeclaration>().first;

      if (newConstructor.initializers.isEmpty) {
        // Add first initializer
        final bodyStart = newConstructor.body.offset;
        return updatedSource.replaceRange(bodyStart, bodyStart, ' : $privateName = $publicName ');
      } else {
        // Append to existing initializers
        final lastInitializer = newConstructor.initializers.last;
        return updatedSource.replaceRange(lastInitializer.end, lastInitializer.end, ', $privateName = $publicName');
      }
    }
  }

  Future<String> _addDependencyImport(
    String source,
    String dependencyName,
    String targetFilePath,
  ) async {
    // Try to find the dependency file
    final dependencySnake = StringUtils.camelToSnake(dependencyName.replaceAll('Service', '').replaceAll('Repository', '').replaceAll('Provider', '').replaceAll('DataSource', ''));
    
    // Search for the interface or implementation
    final searchDirs = [
      path.join(outputDir, 'domain', 'services'),
      path.join(outputDir, 'domain', 'repositories'),
      path.join(outputDir, 'data', 'providers'),
      path.join(outputDir, 'data', 'datasources'),
    ];

    for (final dirPath in searchDirs) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File && 
              (file.path.contains(dependencySnake) || file.path.contains(StringUtils.camelToSnake(dependencyName))) && 
              file.path.endsWith('.dart')) {
            final relativePath = path.relative(file.path, from: path.dirname(targetFilePath));
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

    return source;
  }

  Future<GeneratedFile?> _updateDiRegistration(
    String targetClass,
    String dependencyName,
    String targetType,
  ) async {
    final snakeName = StringUtils.camelToSnake(targetClass);
    final diFileName = '${snakeName}_di.dart';
    
    // Search for DI file
    final diDir = Directory(path.join(outputDir, 'di'));
    if (!diDir.existsSync()) {
      diDir.createSync(recursive: true);
    }

    final files = diDir.listSync(recursive: true);
    File? diFile;
    for (final file in files) {
      if (file is File && file.path.endsWith(diFileName)) {
        diFile = file;
        break;
      }
    }

    final fieldName = StringUtils.pascalToCamel(dependencyName);
    final dependencyCall = "getIt<${dependencyName}>()";

    if (diFile == null) {
      // Create new DI file if it doesn't exist
      final diSubDir = targetType == 'provider' || targetType == 'mock' ? 'providers' : 'datasources';
      final newDiPath = path.join(outputDir, 'di', diSubDir, diFileName);
      
      // Try to find the import for the target class
      String targetImport = "// TODO: Add missing import for $targetClass";
      final targetFile = await _findTargetFile(targetClass, targetType);
      if (targetFile != null) {
        final relPath = path.relative(targetFile, from: path.join(outputDir, 'di', diSubDir));
        targetImport = "import '$relPath';";
      }

      final registrationName = 'register$targetClass';
      final content = '''
import 'package:get_it/get_it.dart';
$targetImport

void $registrationName(GetIt getIt) {
  getIt.registerLazySingleton<$targetClass>(
    () => $targetClass($fieldName: $dependencyCall),
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

      return GeneratedFile(
        path: newDiPath,
        type: 'di_inject',
        action: 'created',
      );
    }

    var source = await diFile.readAsString();

    // Look for instantiation: () => TargetClass(...)
    // Use a more specific regex that ensures we only match the instantiation
    // and correctly identifies the parameter block.
    final pattern = RegExp('=>\\s*$targetClass\\((.*?)\\)');
    final match = pattern.firstMatch(source);
    if (match != null) {
      final existingParams = match.group(1) ?? '';
      String newParams;

      if (existingParams.trim().isEmpty) {
        newParams = '$fieldName: $dependencyCall';
      } else {
        if (!existingParams.contains(fieldName)) {
          newParams = '$existingParams, $fieldName: $dependencyCall';
        } else {
          return null; // Already injected in DI
        }
      }

      // Find the start of the ( ) block specifically for the matched instantiation
      final instantiationStart = match.group(0)!.indexOf('(');
      final actualParamsStart = match.start + instantiationStart + 1;
      final actualParamsEnd = match.end - 1;

      source = source.replaceRange(actualParamsStart, actualParamsEnd, newParams);

      // Ensure dependency import is present in DI file
      source = await _addDependencyImport(source, dependencyName, diFile.path);

      await FileUtils.writeFile(
        diFile.path,
        source,
        'di_inject',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
      );

      return GeneratedFile(
        path: diFile.path,
        type: 'di_inject',
        action: 'updated',
      );
    }

    return null;
  }

  String _getIndent(String source, int offset) {
    var lineStart = offset;
    while (lineStart > 0 && source[lineStart - 1] != '\n') {
      lineStart--;
    }
    return source.substring(lineStart, offset).replaceAll(RegExp(r'\S'), '');
  }
}
