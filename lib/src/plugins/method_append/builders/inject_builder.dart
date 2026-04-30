import 'dart:io';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/visitor.dart' as ast_visitor;

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
            if (fileName == '$snakeName.dart') {
              return file.path;
            }

            final zuraffaSnake = snakeName.replaceAll(
              '_data_source',
              '_datasource',
            );
            if (fileName == '$zuraffaSnake.dart') {
              return file.path;
            }

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

    // 1. Add field to the class
    final fieldSource = 'final $dependencyName $privateName;';
    source = AstModifier.addFieldToClass(
      source: source,
      classNode: classNode,
      fieldSource: fieldSource,
    );

    // 2. Add constructor parameter
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
    final emitter = DartEmitter(useNullSafetySyntax: true);
    final unit = helper.parseSource(source).unit!;
    final classNode = helper.findClass(unit, className)!;

    final body = classNode.body;
    if (body is! ast.BlockClassBody) return source;

    final constructors = body.members.whereType<ast.ConstructorDeclaration>();

    if (constructors.isEmpty) {
      final constructor = Constructor(
        (c) => c
          ..optionalParameters.add(
            Parameter(
              (p) => p
                ..name = publicName
                ..type = refer(dependencyName)
                ..named = true
                ..required = true,
            ),
          )
          ..initializers.add(Code('$privateName = $publicName')),
      );

      final tempClass = Class(
        (b) => b
          ..name = className
          ..constructors.add(constructor),
      );
      final classSource = tempClass.accept(emitter).toString();
      final start = classSource.indexOf('$className(');
      final end = classSource.lastIndexOf(';') != -1
          ? classSource.lastIndexOf(';') + 1
          : classSource.lastIndexOf('}') + 1;
      final constructorSource = classSource.substring(start, end);

      return helper.addMethodToClass(
        source: source,
        className: className,
        methodSource: constructorSource,
      );
    } else {
      final oldConstructor = constructors.first;

      // Extract existing parameters and initializers from AST
      final params = <Parameter>[];
      for (final p in oldConstructor.parameters.parameters) {
        final dynamic dp = p;
        final isDefault =
            p.runtimeType.toString().contains('DefaultFormalParameter') ||
            (dp is ast.FormalParameter && _hasDefaultClause(dp));

        if (isDefault) {
          final dynamic fp = _getInternalParameter(dp);
          params.add(
            Parameter(
              (b) => b
                ..name = _getParameterName(fp)
                ..type = refer(_getParameterType(fp))
                ..named = _isNamed(fp)
                ..required = _isRequired(dp),
            ),
          );
        } else {
          params.add(
            Parameter(
              (b) => b
                ..name = _getParameterName(dp)
                ..type = refer(_getParameterType(dp))
                ..named = _isNamed(dp)
                ..required = true,
            ),
          );
        }
      }

      // Check if parameter already exists
      if (params.any((p) => p.name == publicName)) {
        return source;
      }

      // Add new parameter
      params.add(
        Parameter(
          (b) => b
            ..name = publicName
            ..type = refer(dependencyName)
            ..named = true
            ..required = true,
        ),
      );

      final initializers = <Code>[];
      for (final init in oldConstructor.initializers) {
        initializers.add(Code(init.toString()));
      }

      // Add new initializer if not present
      if (!initializers.any((i) => i.toString().contains(privateName))) {
        initializers.add(Code('$privateName = $publicName'));
      }

      final newConstructor = Constructor(
        (c) => c
          ..optionalParameters.addAll(params.where((p) => p.named))
          ..requiredParameters.addAll(params.where((p) => !p.named))
          ..initializers.addAll(initializers),
      );

      final tempClass = Class(
        (b) => b
          ..name = className
          ..constructors.add(newConstructor),
      );
      final classSource = tempClass.accept(emitter).toString();
      final start = classSource.indexOf('$className(');
      final end = classSource.lastIndexOf(';') != -1
          ? classSource.lastIndexOf(';') + 1
          : classSource.lastIndexOf('}') + 1;
      final constructorSource = classSource.substring(start, end);

      return helper.replaceConstructorInClass(
        source: source,
        className: className,
        constructorSource: constructorSource,
      );
    }
  }

  bool _hasDefaultClause(dynamic p) {
    try {
      return p.defaultClause != null;
    } catch (_) {
      return false;
    }
  }

  dynamic _getInternalParameter(dynamic p) {
    try {
      return p.parameter;
    } catch (_) {
      return p;
    }
  }

  String _getParameterName(dynamic p) {
    try {
      return p.name?.lexeme ?? '';
    } catch (_) {
      return '';
    }
  }

  String _getParameterType(dynamic p) {
    try {
      // In Analyzer 13, SimpleFormalParameter is RegularFormalParameter
      return p.type?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isNamed(dynamic p) {
    try {
      return p.isNamed;
    } catch (_) {
      return false;
    }
  }

  bool _isRequired(dynamic p) {
    try {
      return p.isRequired;
    } catch (_) {
      return false;
    }
  }

  Future<String> _addDependencyImport(
    String source,
    String dependencyName,
    String targetFilePath,
  ) async {
    final dependencySnake = StringUtils.camelToSnake(
      dependencyName
          .replaceAll('Service', '')
          .replaceAll('Repository', '')
          .replaceAll('Provider', '')
          .replaceAll('DataSource', ''),
    );
    final fullDependencySnake = StringUtils.camelToSnake(dependencyName);

    final searchDirs = [
      path.join(outputDir, 'domain', 'services'),
      path.join(outputDir, 'domain', 'repositories'),
      path.join(outputDir, 'data', 'providers'),
      path.join(outputDir, 'data', 'datasources'),
      path.join(outputDir, 'domain', 'entities'),
    ];

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
            final nameMatch =
                fileName.contains(dependencySnake) ||
                fileName.contains(fullDependencySnake);

            if (nameMatch) {
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
    final helper = const AstHelper();

    final diDir = Directory(path.join(outputDir, 'di'));
    if (!diDir.existsSync()) {
      diDir.createSync(recursive: true);
    }

    final files = diDir.listSync(recursive: true).whereType<File>().toList();
    final diFilesToUpdate = <File>[];

    for (final file in files) {
      if (file.path.endsWith('.dart')) {
        final content = await file.readAsString();
        if (content.contains(targetClass)) {
          diFilesToUpdate.add(file);
        }
      }
    }

    final fieldName = StringUtils.pascalToCamel(dependencyName);
    final dependencyCall = "getIt<$dependencyName>()";
    final namedDependencyCall = "$fieldName: $dependencyCall";

    if (diFilesToUpdate.isEmpty) {
      final diSubDir = targetType == 'provider' || targetType == 'mock'
          ? 'providers'
          : 'datasources';
      final newDiPath = path.join(outputDir, 'di', diSubDir, diFileName);

      if (File(newDiPath).existsSync()) {
        diFilesToUpdate.add(File(newDiPath));
      } else {
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
      final parseResult = helper.parseSource(source);
      final unit = parseResult.unit;
      if (unit == null) continue;

      bool fileUpdated = false;
      final visitor = _DIUpdateVisitor(
        targetClass,
        fieldName,
        namedDependencyCall,
      );
      unit.accept(visitor);

      if (visitor.matches.isNotEmpty) {
        final sortedMatches = visitor.matches.toList()
          ..sort((a, b) => b.offset.compareTo(a.offset));

        for (final match in sortedMatches) {
          if (options.force || !match.alreadyExists) {
            source = source.replaceRange(
              match.offset,
              match.end,
              match.replacement,
            );
            fileUpdated = true;
          }
        }
      }

      if (fileUpdated) {
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
}

class _DIMatch {
  final int offset;
  final int end;
  final String replacement;
  final bool alreadyExists;

  _DIMatch(this.offset, this.end, this.replacement, this.alreadyExists);
}

class _DIUpdateVisitor extends ast_visitor.RecursiveAstVisitor<void> {
  final String targetClass;
  final String fieldName;
  final String namedDependencyCall;
  final List<_DIMatch> matches = [];

  _DIUpdateVisitor(this.targetClass, this.fieldName, this.namedDependencyCall);

  @override
  void visitInstanceCreationExpression(ast.InstanceCreationExpression node) {
    if (node.constructorName.type.name.toString() == targetClass) {
      _handleArgumentList(node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  String? _getLabelName(dynamic labelNode) {
    try {
      // Analyzer < 13
      return labelNode.label.name;
    } catch (_) {
      try {
        // Analyzer >= 13
        return labelNode.name.lexeme;
      } catch (_) {
        return null;
      }
    }
  }

  void _handleArgumentList(ast.ArgumentList node) {
    bool alreadyExists = false;
    for (final arg in node.arguments) {
      // Analyzer 13 replacement: NamedExpression is now NamedArgument in ArgumentList
      final isNamed =
          arg.runtimeType.toString().contains('NamedArgument') ||
          arg.runtimeType.toString().contains('NamedExpression');

      if (isNamed) {
        // In Analyzer 13, Label.label (SimpleIdentifier) is removed, use Label.name (Token)
        // For compatibility, we check if label or name property is available via reflection or string comparison if we can't use static types yet
        // But since we are migrating, we will use a more robust way to check.
        final dynamic namedArg = arg;
        final String? name = _getLabelName(namedArg.name);
        if (name == fieldName) {
          alreadyExists = true;
          break;
        }
      }
    }

    if (node.arguments.isEmpty) {
      matches.add(
        _DIMatch(
          node.leftParenthesis.offset + 1,
          node.rightParenthesis.offset,
          namedDependencyCall,
          alreadyExists,
        ),
      );
    } else {
      final lastArg = node.arguments.last;
      matches.add(
        _DIMatch(
          lastArg.end,
          lastArg.end,
          ', $namedDependencyCall',
          alreadyExists,
        ),
      );
    }
  }
}
