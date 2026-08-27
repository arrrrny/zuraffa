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

    final packageName = await _resolvePackageName(projectRoot);

    // #354: detect Flutter vs pure-Dart from pubspec.yaml (see entity builder).
    final isFlutter = await _isFlutterProject(projectRoot);
    final directives = [
      _testFrameworkImport(isFlutter),
      _zuraffaCoreImport(isFlutter),
      Directive.import(
        'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${config.nameSnake}_usecase.dart',
      ),
    ];

    final entityTypes = <String>[];
    if (config.returnsType != null) {
      entityTypes.addAll(EntityUtils.extractEntityTypes(config.returnsType!));
    }
    if (config.paramsType != null) {
      entityTypes.addAll(EntityUtils.extractEntityTypes(config.paramsType!));
    }

    for (final type in entityTypes.toSet()) {
      final snake = StringUtils.camelToSnake(type);
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/entities/$snake/$snake.dart',
        ),
      );
    }

    final fakeSpecs = <Class>[];
    for (final usecase in config.usecases) {
      final usecaseSnake = StringUtils.camelToSnake(
        usecase.replaceAll('UseCase', ''),
      );
      // Find the actual domain for this usecase
      final usecaseDomain = await _findUseCaseDomain(
        usecaseSnake,
        config.effectiveDomain,
      );
      final usecaseImportPath =
          'package:$packageName/src/domain/usecases/$usecaseDomain/${usecaseSnake}_usecase.dart';
      directives.add(Directive.import(usecaseImportPath));

      // Generate a Fake for this child use case using AST-parsed signatures.
      final usecaseFile = discovery.findFileSync(
        '${usecaseSnake}_usecase.dart',
      );
      if (usecaseFile != null) {
        final fakeClass = await _generateFakeClassForDependency(
          className: 'Fake${usecase}UseCase',
          interfaceName: '${usecase}UseCase',
          filePath: usecaseFile.path,
          packageName: packageName,
          projectRoot: projectRoot,
          entityTypes: entityTypes.toSet(),
        );
        if (fakeClass != null) {
          fakeSpecs.add(fakeClass);
        } else {
          fakeSpecs.add(
            Class(
              (c) => c
                ..name = 'Fake${usecase}UseCase'
                ..implements.add(refer('${usecase}UseCase')),
            ),
          );
        }
      } else {
        fakeSpecs.add(
          Class(
            (c) => c
              ..name = 'Fake${usecase}UseCase'
              ..implements.add(refer('${usecase}UseCase')),
          ),
        );
      }
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
                'fake${usecase}UseCase',
                type: refer('Fake${usecase}UseCase'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            for (final usecase in config.usecases) {
              s.statements.add(
                refer(
                  'fake${usecase}UseCase',
                ).assign(refer('Fake${usecase}UseCase').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.usecases
                          .map((u) => refer('fake${u}UseCase'))
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
        specs: [...fakeSpecs, mainMethod],
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
