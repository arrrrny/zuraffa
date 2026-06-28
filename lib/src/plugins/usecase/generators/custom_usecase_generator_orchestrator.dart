part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorOrchestrator on CustomUseCaseGenerator {
  Future<GeneratedFile> generateOrchestrator(GeneratorConfig config) async {
    final className = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final fileName = '${classSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    if (config.revert) {
      return FileUtils.deleteFile(
        filePath,
        'usecase_orchestrator',
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
    }

    final paramsType = config.paramsType;
    if (paramsType == null) {
      throw ArgumentError('paramsType is required');
    }
    // Completable orchestrators use 'void' as returnsType
    final returnsType = config.useCaseType == 'completable'
        ? 'void'
        : (config.returnsType ?? 'void');
    final baseClass = _baseClass(config, paramsType, returnsType);

    final usecaseImports = <String>['package:zuraffa/zuraffa.dart'];
    final usecaseFields = <Field>[];
    final usecaseParams = <Parameter>[];

    for (final usecaseName in config.usecases) {
      final usecasePath = await _resolveUseCasePath(config, usecaseName);
      final usecaseClassName = usecaseName.endsWith('UseCase')
          ? usecaseName
          : '${usecaseName}UseCase';
      final baseName = usecaseName.replaceAll('UseCase', '');
      final fieldName = '_${StringUtils.pascalToCamel(baseName)}';

      usecaseImports.add(usecasePath);
      usecaseFields.add(
        Field(
          (b) => b
            ..name = fieldName
            ..type = refer(usecaseClassName)
            ..modifier = FieldModifier.final$,
        ),
      );
      usecaseParams.add(
        Parameter(
          (p) => p
            ..name = fieldName
            ..toThis = true,
        ),
      );
    }

    // Also inject service dependency if specified
    if (config.hasService) {
      final serviceName = config.effectiveService;
      if (serviceName == null) {
        throw ArgumentError(
          'Service name must be specified via --service or config.service',
        );
      }
      final svcSnake = config.serviceSnake;
      if (svcSnake != null) {
        usecaseImports.add('../../services/${svcSnake}_service.dart');
      }

      final serviceBaseName = serviceName.endsWith('Service')
          ? serviceName.substring(0, serviceName.length - 7)
          : serviceName;
      final serviceFieldName =
          '_${StringUtils.pascalToCamel(serviceBaseName)}Service';

      usecaseFields.add(
        Field(
          (b) => b
            ..name = serviceFieldName
            ..type = refer(serviceName)
            ..modifier = FieldModifier.final$,
        ),
      );
      usecaseParams.add(
        Parameter(
          (p) => p
            ..name = serviceFieldName
            ..toThis = true,
        ),
      );
    }

    // Also inject repo dependency if specified (when no service)
    if (config.hasRepo && !config.hasService) {
      for (final repo in config.effectiveRepos) {
        final repoBaseName = repo.replaceAll('Repository', '');
        final repoFieldName =
            '_${StringUtils.pascalToCamel(repoBaseName)}Repository';

        final repoSnake = StringUtils.camelToSnake(repoBaseName);
        usecaseImports.add('../../repositories/${repoSnake}_repository.dart');

        usecaseFields.add(
          Field(
            (b) => b
              ..name = repoFieldName
              ..type = refer(repo)
              ..modifier = FieldModifier.final$,
          ),
        );
        usecaseParams.add(
          Parameter(
            (p) => p
              ..name = repoFieldName
              ..toThis = true,
          ),
        );
      }
    }

    final entityImports = CommonPatterns.entityImports(
      [paramsType, returnsType],
      config,
      depth: 3,
      includeDomain: false,
      fileSystem: fileSystem,
    );
    usecaseImports.addAll(entityImports);

    final executeMethod = _buildOrchestratorExecute(
      config,
      paramsType,
      returnsType,
    );

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: usecaseFields,
      constructors: [
        Constructor((b) => b..requiredParameters.addAll(usecaseParams)),
      ],
      methods: [executeMethod],
      imports: usecaseImports,
    );

    final content = classBuilder.build(spec);
    return FileUtils.writeFile(
      filePath,
      content,
      'usecase_orchestrator',
      force: config.force,
      dryRun: config.dryRun,
      verbose: config.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
