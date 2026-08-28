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

    final useCaseFileName = '${config.nameSnake}_usecase.dart';
    final useCaseFile = discovery.findFileSync(useCaseFileName);

    if (useCaseFile == null) {
      print(
        '  ⚠️  Skipping test generation for $useCaseName: UseCase file ($useCaseFileName) not found.',
      );
      return GeneratedFile(path: filePath, type: 'test', action: 'skipped');
    }

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

    final entityTypeSet = entityTypes.toSet();

    for (final type in entityTypeSet) {
      final snake = StringUtils.camelToSnake(type);
      directives.add(
        Directive.import(
          'package:$packageName/src/domain/entities/$snake/$snake.dart',
        ),
      );
    }

    final fakeSpecs = <Class>[];

    if (paramsType != 'NoParams' && !KnownTypes.isDartPrimitive(paramsType)) {
      final paramsBaseType = paramsType.split('<').first.trim();
      final paramsFile = discovery.findFileSync(
        '${StringUtils.camelToSnake(paramsBaseType)}.dart',
      );
      fakeSpecs.add(
        await _requireFakeClassForDependency(
          className: 'Fake$paramsBaseType',
          interfaceName: paramsType,
          filePath: paramsFile?.path,
          packageName: packageName,
          projectRoot: projectRoot,
          entityTypes: entityTypeSet,
        ),
      );
    }

    for (final repo in config.effectiveRepos) {
      final repoSnake = StringUtils.camelToSnake(
        repo.replaceAll('Repository', ''),
      );
      final repoSourcePath =
          'package:$packageName/src/domain/repositories/${repoSnake}_repository.dart';
      directives.add(Directive.import(repoSourcePath));

      // Generate a Fake{repo} using AST-parsed method signatures.
      final repoFile = discovery.findFileSync('${repoSnake}_repository.dart');
      fakeSpecs.add(
        await _requireFakeClassForDependency(
          className: 'Fake$repo',
          interfaceName: repo,
          filePath: repoFile?.path,
          packageName: packageName,
          projectRoot: projectRoot,
          entityTypes: entityTypeSet,
        ),
      );
    }

    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    if (serviceName != null && serviceSnake != null) {
      final serviceImport = config.useService
          ? 'package:$packageName/src/domain/services/${config.effectiveDomain}/${serviceSnake}_service.dart'
          : 'package:$packageName/src/domain/services/${serviceSnake}_service.dart';
      directives.add(Directive.import(serviceImport));

      // Generate a Fake{service} using AST-parsed method signatures.
      final serviceFile = discovery.findFileSync(
        '${serviceSnake}_service.dart',
      );
      fakeSpecs.add(
        await _requireFakeClassForDependency(
          className: 'Fake$serviceName',
          interfaceName: serviceName,
          filePath: serviceFile?.path,
          packageName: packageName,
          projectRoot: projectRoot,
          entityTypes: entityTypeSet,
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
                'fake$repo',
                type: refer('Fake$repo'),
                late: true,
              ).statement,
            );
          }
          if (serviceName != null) {
            b.statements.add(
              declareVar(
                'fake$serviceName',
                type: refer('Fake$serviceName'),
                late: true,
              ).statement,
            );
          }

          final setUpBody = Block((s) {
            for (final repo in config.effectiveRepos) {
              s.statements.add(
                refer(
                  'fake$repo',
                ).assign(refer('Fake$repo').call([])).statement,
              );
            }
            if (serviceName != null) {
              s.statements.add(
                refer(
                  'fake$serviceName',
                ).assign(refer('Fake$serviceName').call([])).statement,
              );
            }
            s.statements.add(
              refer('useCase')
                  .assign(
                    refer(useCaseName).call([
                      ...config.effectiveRepos.map((r) => refer('fake$r')),
                      if (serviceName != null) refer('fake$serviceName'),
                    ]),
                  )
                  .statement,
            );
          });

          b.statements.add(
            refer('setUp').call([setUpBody.toClosure()]).statement,
          );

          final groupBody = Block((g) {
            if (paramsType != 'NoParams' &&
                !KnownTypes.isDartPrimitive(paramsType)) {
              final paramsBaseType = paramsType.split('<').first.trim();
              g.statements.add(
                declareFinal(
                  't$paramsBaseType',
                ).assign(refer('Fake$paramsBaseType').call([])).statement,
              );
            }

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
