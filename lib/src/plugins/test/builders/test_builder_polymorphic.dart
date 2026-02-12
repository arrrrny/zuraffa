part of 'test_builder.dart';

extension TestBuilderPolymorphic on TestBuilder {
  /// Generates test files for polymorphic use case variants.
  ///
  /// @param config Generator configuration describing the variants and options.
  /// @returns List of generated test file metadata.
  Future<List<GeneratedFile>> generatePolymorphic(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final projectRoot = outputDir.replaceAll('lib/src', '');
    final testPathParts = <String>[projectRoot, 'test', 'domain', 'usecases'];
    testPathParts.add(config.effectiveDomain);
    final testDirPath = path.joinAll(testPathParts);

    final packageName = _resolvePackageName(projectRoot);

    for (final variant in config.variants) {
      final className = '${config.name}${variant}UseCase';
      final classSnake = StringUtils.camelToSnake('${config.name}$variant');
      final fileName = '${classSnake}_usecase_test.dart';
      final filePath = path.join(testDirPath, fileName);

      final directives = [
        Directive.import('package:flutter_test/flutter_test.dart'),
        Directive.import('package:mocktail/mocktail.dart'),
        Directive.import('package:zuraffa/zuraffa.dart'),
        Directive.import(
          'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${classSnake}_usecase.dart',
        ),
      ];

      final mockSpecs = <Class>[];
      final repoBase = config.repo;
      if (repoBase != null) {
        final repoName = '${repoBase}Repository';
        mockSpecs.add(
          Class(
            (c) => c
              ..name = 'Mock$repoName'
              ..extend = refer('Mock')
              ..implements.add(refer(repoName)),
          ),
        );

        final repoSnake = StringUtils.camelToSnake(
          repoBase.replaceAll('Repository', ''),
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
                type: refer(className),
                late: true,
              ).statement,
            );
            if (repoBase != null) {
              b.statements.add(
                declareVar(
                  'mock${repoBase}Repository',
                  type: refer('Mock${repoBase}Repository'),
                  late: true,
                ).statement,
              );
            }

            final setUpBody = Block((s) {
              if (repoBase != null) {
                s.statements.add(
                  refer('mock${repoBase}Repository')
                      .assign(refer('Mock${repoBase}Repository').call([]))
                      .statement,
                );
              }
              final setupArgs = repoBase != null
                  ? [refer('mock${repoBase}Repository')]
                  : <Expression>[];
              s.statements.add(
                refer(
                  'useCase',
                ).assign(refer(className).call(setupArgs)).statement,
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
                if (config.useCaseType == 'stream') {
                  t.statements.add(
                    declareFinal(
                      'result',
                    ).assign(refer('useCase').call([callArgs])).statement,
                  );
                  t.statements.add(
                    refer('expectLater')
                        .call([
                          refer('result'),
                          refer('emits').call([
                            refer('isA').call([], {}, [refer('Success')]),
                          ]),
                        ])
                        .awaited
                        .statement,
                  );
                } else {
                  t.statements.add(
                    declareFinal('result')
                        .assign(refer('useCase').call([callArgs]).awaited)
                        .statement,
                  );
                  t.statements.add(
                    refer('expect').call([
                      refer('result'),
                      refer('isA').call([], {}, [refer('Success')]),
                    ]).statement,
                  );
                }
              });

              g.statements.add(
                refer('test').call([
                  literalString(
                    config.useCaseType == 'stream'
                        ? 'should emit values from stream'
                        : 'should return Success',
                  ),
                  testBody.toClosure(asAsync: true),
                ]).statement,
              );
            });

            b.statements.add(
              refer('group').call([
                literalString(className),
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

      final file = await FileUtils.writeFile(
        filePath,
        content,
        'test',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      );
      files.add(file);
    }

    return files;
  }
}
