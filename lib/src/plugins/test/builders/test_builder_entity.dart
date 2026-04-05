part of 'test_builder.dart';

extension TestBuilderEntity on TestBuilder {
  /// Generates a test file for a single entity use case method.
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @param method Use case method name to generate tests for.
  /// @returns Generated test file metadata.
  Future<GeneratedFile> generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final useService = config.useService;
    final repoName = config.effectiveRepos.isNotEmpty
        ? config.effectiveRepos.first
        : null;
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;

    final targetName = useService && serviceName != null
        ? serviceName
        : repoName;
    if (targetName == null) {
      throw ArgumentError('Either repository or service must be specified');
    }
    final targetSnake = useService && serviceSnake != null
        ? serviceSnake
        : StringUtils.camelToSnake(targetName.replaceAll('Repository', ''));
    final targetDir = useService ? 'services' : 'repositories';
    final targetSuffix = useService ? 'service' : 'repository';

    String className;
    String returnTypeConstructor = '';
    bool isStream = false;
    bool isCompletable = false;

    switch (method) {
      case 'get':
        className = 'Get${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'getList':
      case 'list':
        className = 'Get${entityName}ListUseCase';
        returnTypeConstructor = 't${entityName}List';
        break;
      case 'create':
        className = 'Create${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'update':
        className = 'Update${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        break;
      case 'delete':
        className = 'Delete${entityName}UseCase';
        returnTypeConstructor = 'null';
        isCompletable = true;
        break;
      case 'watch':
        className = 'Watch${entityName}UseCase';
        returnTypeConstructor = 't$entityName';
        isStream = true;
        break;
      case 'watchList':
        className = 'Watch${entityName}ListUseCase';
        returnTypeConstructor = 't${entityName}List';
        isStream = true;
        break;
      default:
        throw ArgumentError('Unknown method: $method');
    }

    final fileSnake = StringUtils.camelToSnake(
      className.replaceAll('UseCase', ''),
    );
    final fileName = '${fileSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(entitySnake);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    String useCaseFileName;
    if (method == 'getList' || method == 'list') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }

    final packageName = await _resolvePackageName(projectRoot);

    // Use DiscoveryEngine to find the actual files for correct imports
    final entityFile = discovery.findFileSync('$entitySnake.dart');
    final targetFile = discovery.findFileSync(
      '${targetSnake}_$targetSuffix.dart',
    );
    final useCaseFile = discovery.findFileSync(useCaseFileName);

    if (useCaseFile == null) {
      print(
        '  ⚠️  Skipping test generation for $className: UseCase file ($useCaseFileName) not found.',
      );
      return GeneratedFile(path: filePath, type: 'test', action: 'skipped');
    }

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      if (method != 'create') Directive.import('package:zuraffa/zuraffa.dart'),
    ];

    if (entityFile != null) {
      final relPath = path.relative(entityFile.path, from: testDirPath);
      directives.add(Directive.import(relPath));
    } else {
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/entities/$entitySnake/$entitySnake.dart',
        ),
      );
    }

    if (targetFile != null) {
      final relPath = path.relative(targetFile.path, from: testDirPath);
      directives.add(Directive.import(relPath));
    } else {
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/$targetDir/${targetSnake}_$targetSuffix.dart',
        ),
      );
    }

    final relPath = path.relative(useCaseFile.path, from: testDirPath);
    directives.add(Directive.import(relPath));

    final mockRepoClass = 'Mock$targetName';
    final mockEntityClass = 'Mock$entityName';

    final mockRepo = Class(
      (c) => c
        ..name = mockRepoClass
        ..extend = refer('Mock')
        ..implements.add(refer(targetName)),
    );

    final mockEntity = Class(
      (c) => c
        ..name = mockEntityClass
        ..extend = refer('Mock')
        ..implements.add(refer(entityName)),
    );

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          final mockVarName = 'mock${StringUtils.capitalize(targetSuffix)}';
          b.statements.add(
            declareVar('useCase', type: refer(className), late: true).statement,
          );
          b.statements.add(
            declareVar(
              mockVarName,
              type: refer(mockRepoClass),
              late: true,
            ).statement,
          );

          final setUpBody = Block((s) {
            final fallbackValues = _getFallbackValues(
              config,
              method,
              mockEntityClass,
            );
            for (final val in fallbackValues) {
              s.statements.add(
                refer('registerFallbackValue').call([val]).statement,
              );
            }
            s.statements.add(
              refer(
                mockVarName,
              ).assign(refer(mockRepoClass).call([])).statement,
            );
            s.statements.add(
              refer(
                'useCase',
              ).assign(refer(className).call([refer(mockVarName)])).statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            if (method != 'delete') {
              g.statements.add(
                declareFinal(
                  't$entityName',
                ).assign(refer(mockEntityClass).call([])).statement,
              );
            }

            if (![
              'get',
              'create',
              'delete',
              'watch',
              'update',
            ].contains(method)) {
              if (['getList', 'watchList'].contains(method)) {
                g.statements.add(
                  declareFinal(
                    't${entityName}List',
                  ).assign(literalList([refer('t$entityName')])).statement,
                );
              }
            }

            final tests = isStream
                ? _generateStreamTests(
                    config,
                    method,
                    entityName,
                    returnTypeConstructor,
                    mockVarName,
                  )
                : _generateFutureTests(
                    config,
                    method,
                    entityName,
                    returnTypeConstructor,
                    isCompletable,
                    mockVarName,
                  );

            g.statements.addAll(tests);
          });

          b.statements.add(
            refer(
              'group',
            ).call([literalString(className), groupBody.toClosure()]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [mockRepo, mockEntity, mainMethod],
        directives: directives,
      ),
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'test',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
