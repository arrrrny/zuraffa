part of 'test_builder.dart';

extension TestBuilderEntity on TestBuilder {
  Future<GeneratedFile> generateForMethod(
    GeneratorConfig config,
    String method,
  ) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final repoName = config.effectiveRepos.first;

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
    if (method == 'getList') {
      useCaseFileName = 'get_${entitySnake}_list_usecase.dart';
    } else if (method == 'watchList') {
      useCaseFileName = 'watch_${entitySnake}_list_usecase.dart';
    } else {
      useCaseFileName =
          '${StringUtils.camelToSnake(method)}_${entitySnake}_usecase.dart';
    }

    final packageName = _resolvePackageName(projectRoot);
    final repoSnake = StringUtils.camelToSnake(
      repoName.replaceAll('Repository', ''),
    );

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      if (method != 'create') Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        'package:$packageName/src/domain/entities/$entitySnake/$entitySnake.dart',
      ),
      Directive.import(
        'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart',
      ),
      Directive.import(
        'package:$packageName/src/domain/usecases/$entitySnake/$useCaseFileName',
      ),
    ];

    final mockRepoClass = 'Mock$repoName';
    final mockEntityClass = 'Mock$entityName';

    final mockRepo = Class(
      (c) => c
        ..name = mockRepoClass
        ..extend = refer('Mock')
        ..implements.add(refer(repoName)),
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
          b.statements.add(
            declareVar('useCase', type: refer(className), late: true).statement,
          );
          b.statements.add(
            declareVar(
              'mockRepository',
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
                'mockRepository',
              ).assign(refer(mockRepoClass).call([])).statement,
            );
            s.statements.add(
              refer('useCase')
                  .assign(refer(className).call([refer('mockRepository')]))
                  .statement,
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
                  )
                : _generateFutureTests(
                    config,
                    method,
                    entityName,
                    returnTypeConstructor,
                    isCompletable,
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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
