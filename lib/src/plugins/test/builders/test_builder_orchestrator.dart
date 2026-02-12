part of 'test_builder.dart';

extension TestBuilderOrchestrator on TestBuilder {
  /// Generates a test file for an orchestrator use case.
  ///
  /// @param config Generator configuration describing the use case and options.
  /// @returns Generated test file metadata.
  Future<GeneratedFile> generateOrchestrator(GeneratorConfig config) async {
    final useCaseName = '${config.name}UseCase';
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
    for (final usecase in config.usecases) {
      mockSpecs.add(
        Class(
          (c) => c
            ..name = 'Mock${usecase}UseCase'
            ..extend = refer('Mock')
            ..implements.add(refer('${usecase}UseCase')),
        ),
      );

      final usecaseSnake = StringUtils.camelToSnake(usecase);
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/usecases/$usecaseSnake/${usecaseSnake}_usecase.dart',
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
          for (final usecase in config.usecases) {
            b.statements.add(
              declareVar(
                'mock${usecase}UseCase',
                type: refer('Mock${usecase}UseCase'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            for (final usecase in config.usecases) {
              s.statements.add(
                refer(
                  'mock${usecase}UseCase',
                ).assign(refer('Mock${usecase}UseCase').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.usecases
                          .map((u) => refer('mock${u}UseCase'))
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
            final paramsType = config.paramsType ?? 'NoParams';
            final callArgs = paramsType == 'NoParams'
                ? refer('NoParams').constInstance([])
                : refer('params');

            final testBody = Block((t) {
              t.statements.add(
                declareFinal(
                  'result',
                ).assign(refer('useCase').call([callArgs]).awaited).statement,
              );
              t.statements.add(
                refer('expect').call([
                  refer('result'),
                  refer('isA').call([], {}, [refer('Success')]),
                ]).statement,
              );
            });

            g.statements.add(
              refer('test').call([
                literalString('should orchestrate all usecases'),
                testBody.toClosure(asAsync: true),
              ]).statement,
            );
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
