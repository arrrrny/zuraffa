part of 'test_builder.dart';

extension TestBuilderOrchestrator on TestBuilder {
  /// Generates a test file for an orchestrator use case.
  ///
  /// @param config Generator configuration describing the use case and options.
  /// @returns Generated test file metadata.
  Future<GeneratedFile> generateOrchestrator(GeneratorConfig config) async {
    // Issue #1723 review: reference the normalized orchestrator class and its
    // real file so the generated test compiles against what the generator
    // wrote (raw casing / suffix doubling previously desynced the two).
    final useCaseName = StringUtils.normalizeUseCaseClassName(config.name);
    final classSnake = StringUtils.camelToSnake(
      useCaseName.substring(0, useCaseName.length - 'UseCase'.length),
    );
    final fileName = '${classSnake}_usecase_test.dart';

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
        'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${classSnake}_usecase.dart',
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

    // Issue #1723 review: one normalized name per token, computed once —
    // the emission sites below stay consistent by construction instead of by
    // repeated per-loop normalization.
    final fakeNames = {
      for (final usecase in config.usecases)
        usecase: StringUtils.normalizeUseCaseClassName(usecase),
    };

    final fakeSpecs = <Class>[];
    for (final usecase in config.usecases) {
      final usecaseSnake = StringUtils.camelToSnake(
        usecase.replaceAll('UseCase', ''),
      );
      // Issue #1720: derive the fake class/interface names from the
      // normalized PascalCase class name. The unconditional
      // `'${usecase}UseCase'` concatenation doubled the suffix for full
      // class-name tokens and kept raw token casing for snake_case tokens,
      // so the class-declaration check below never matched an existing
      // usecase file — dry-run always reported placeholder fakes.
      final usecaseClass = fakeNames[usecase]!;
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
      fakeSpecs.add(
        await _requireFakeClassForDependency(
          className: 'Fake$usecaseClass',
          interfaceName: usecaseClass,
          filePath: usecaseFile?.path,
          packageName: packageName,
          projectRoot: projectRoot,
          entityTypes: entityTypes.toSet(),
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
            final usecaseClass = fakeNames[usecase]!;
            b.statements.add(
              declareVar(
                'fake$usecaseClass',
                type: refer('Fake$usecaseClass'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            for (final usecase in config.usecases) {
              final usecaseClass = fakeNames[usecase]!;
              s.statements.add(
                refer(
                  'fake$usecaseClass',
                ).assign(refer('Fake$usecaseClass').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call(
                      config.usecases
                          .map((u) => refer('fake${fakeNames[u]}'))
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
