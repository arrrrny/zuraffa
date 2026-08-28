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

    final packageName = await _resolvePackageName(projectRoot);

    for (final variant in config.variants) {
      final className = '${config.name}${variant}UseCase';
      final classSnake = StringUtils.camelToSnake('${config.name}$variant');
      final fileName = '${classSnake}_usecase_test.dart';
      final filePath = path.join(testDirPath, fileName);

      // #354: detect Flutter vs pure-Dart from pubspec.yaml (see entity builder).
      final isFlutter = await _isFlutterProject(projectRoot);
      final directives = [
        _testFrameworkImport(isFlutter),
        _zuraffaCoreImport(isFlutter),
        Directive.import(
          'package:$packageName/src/domain/usecases/${config.effectiveDomain}/${classSnake}_usecase.dart',
        ),
      ];

      final fakeSpecs = <Class>[];
      final repoBase = config.repo;
      if (repoBase != null) {
        final repoName = '${repoBase}Repository';
        final repoSnake = StringUtils.camelToSnake(
          repoBase.replaceAll('Repository', ''),
        );
        final repoFile = discovery.findFileSync('${repoSnake}_repository.dart');
        if (repoFile == null) {
          print(
            '  ⚠️  Skipping test generation for $className: Repository '
            'file (${repoSnake}_repository.dart) not found.',
          );
          continue;
        }

        final repoSourcePath =
            'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart';
        directives.add(Directive.import(repoSourcePath));

        // Generate a Fake{repo}Repository using AST-parsed method signatures.
        fakeSpecs.add(
          await _requireFakeClassForDependency(
            className: 'Fake$repoName',
            interfaceName: repoName,
            filePath: repoFile.path,
            packageName: packageName,
            projectRoot: projectRoot,
            entityTypes: {config.name},
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
                  'fake${repoBase}Repository',
                  type: refer('Fake${repoBase}Repository'),
                  late: true,
                ).statement,
              );
            }

            final setUpBody = Block((s) {
              if (repoBase != null) {
                s.statements.add(
                  refer('fake${repoBase}Repository')
                      .assign(refer('Fake${repoBase}Repository').call([]))
                      .statement,
                );
              }
              final setupArgs = repoBase != null
                  ? [refer('fake${repoBase}Repository')]
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
          specs: [...fakeSpecs, mainMethod],
          directives: directives,
        ),
      );

      final file = await FileUtils.writeFile(
        filePath,
        content,
        'test',
        force: options.force,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
        fileSystem: fileSystem,
      );
      files.add(file);
    }

    return files;
  }
}
