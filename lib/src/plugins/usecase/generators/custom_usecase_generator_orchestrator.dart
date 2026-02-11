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

    final paramsType = config.paramsType!;
    final returnsType = config.returnsType!;
    final baseClass = _baseClass(config, paramsType, returnsType);

    final usecaseImports = <String>['package:zuraffa/zuraffa.dart'];
    final usecaseFields = <Field>[];
    final usecaseParams = <Parameter>[];

    for (final usecaseName in config.usecases) {
      final usecasePath = _resolveUseCasePath(config, usecaseName);
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

    final entityImports = _entityImports([paramsType, returnsType]);
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
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
