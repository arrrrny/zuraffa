part of 'test_builder.dart';

extension TestBuilderCustom on TestBuilder {
  /// Generates a test file for a custom use case.
  ///
  /// @param config Generator configuration describing the use case and options.
  /// @returns Generated test file metadata.
  Future<GeneratedFile> generateCustom(GeneratorConfig config) async {
    final useCaseName = '${config.name}UseCase';
    final useCaseType = config.useCaseType;
    final paramsType = config.paramsType ?? 'NoParams';
    final fileName = '${config.nameSnake}_usecase_test.dart';

    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(config.effectiveDomain);
    final testDirPath = path.joinAll(testPathParts);
    final filePath = path.join(testDirPath, fileName);

    final packageName = _resolvePackageName(projectRoot);

    final directives = [
      Directive.import('package:flutter_test/flutter_test.dart'),
      Directive.import('package:mocktail/mocktail.dart'),
      Directive.import('package:zuraffa/zuraffa.dart'),
      Directive.import(
        'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${config.nameSnake}_usecase.dart',
      ),
    ];

    final mockSpecs = <Class>[];
    for (final repo in config.effectiveRepos) {
      mockSpecs.add(
        Class(
          (c) => c
            ..name = 'Mock$repo'
            ..extend = refer('Mock')
            ..implements.add(refer(repo)),
        ),
      );

      final repoSnake = StringUtils.camelToSnake(
        repo.replaceAll('Repository', ''),
      );
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart',
        ),
      );
    }

    final mainMethod = Method(
      (m) => m
        ..name = 'main'
        ..returns = refer('void')
        ..body = Block((b) {
          b.statements.add(
            declareVar(
              'useCase',
              type: refer(useCaseName),
              late: true,
            ).statement,
          );
          for (final repo in config.effectiveRepos) {
            b.statements.add(
              declareVar(
                'mock$repo',
                type: refer('Mock$repo'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            s.statements.add(
              refer('registerFallbackValue').call([
                refer(
                  'ListQueryParams',
                ).constInstance(const [], const {}, [refer('dynamic')]),
              ]).statement,
            );
            for (final repo in config.effectiveRepos) {
              s.statements.add(
                refer(
                  'mock$repo',
                ).assign(refer('Mock$repo').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.effectiveRepos
                          .map((r) => refer('mock$r'))
                          .toList(),
                    ),
                  )
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            final testCall = _generateCustomTestBody(
              config,
              paramsType,
              useCaseType,
            );
            g.statements.add(testCall.statement);
          });

          b.statements.add(
            refer('group').call([
              literalString(useCaseName),
              groupBody.toClosure(),
            ]).statement,
          );
        }),
    );

    final content = specLibrary.emitLibrary(
      specLibrary.library(
        specs: [...mockSpecs, mainMethod],
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
