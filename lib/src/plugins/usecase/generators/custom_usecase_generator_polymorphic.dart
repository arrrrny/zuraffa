part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorPolymorphic on CustomUseCaseGenerator {
  Future<List<GeneratedFile>> generatePolymorphic(
    GeneratorConfig config,
  ) async {
    final files = <GeneratedFile>[];
    final baseClassName = '${config.name}UseCase';
    final classSnake = StringUtils.camelToSnake(config.name);
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final paramsType = config.paramsType;
    final returnsType = config.returnsType;
    if (paramsType == null || returnsType == null) {
      throw ArgumentError('paramsType and returnsType are required');
    }

    final baseClass = _baseClass(config, paramsType, returnsType);
    final abstractSpec = UseCaseClassSpec(
      className: baseClassName,
      baseClass: baseClass,
      isAbstract: true,
      imports: ['package:zuraffa/zuraffa.dart'],
    );
    final abstractContent = classBuilder.build(abstractSpec);
    final abstractFileName = '${classSnake}_usecase.dart';
    final abstractFilePath = path.join(usecaseDirPath, abstractFileName);
    files.add(
      await FileUtils.writeFile(
        abstractFilePath,
        abstractContent,
        'usecase_polymorphic_base',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      ),
    );

    for (final variant in config.variants) {
      final variantClassName = '$variant${config.name}UseCase';
      final variantSnake = StringUtils.camelToSnake('$variant${config.name}');
      final variantFileName = '${variantSnake}_usecase.dart';
      final variantFilePath = path.join(usecaseDirPath, variantFileName);

      final repoBase = config.repo;
      final repoClassName = repoBase != null
          ? (repoBase.endsWith('Repository')
              ? repoBase
              : '${repoBase}Repository')
          : null;

      final fields = <Field>[];
      final constructorParams = <Parameter>[];
      final imports = <String>[
        'package:zuraffa/zuraffa.dart',
        abstractFileName,
      ];

      if (repoClassName != null) {
        final repoSnake = StringUtils.camelToSnake(
          repoClassName.replaceAll('Repository', ''),
        );
        imports.add('../../repositories/${repoSnake}_repository.dart');
        fields.add(
          Field(
            (b) => b
              ..name = '_repository'
              ..type = refer(repoClassName)
              ..modifier = FieldModifier.final$,
          ),
        );
        constructorParams.add(
          Parameter(
            (p) => p
              ..name = '_repository'
              ..toThis = true,
          ),
        );
      }

      final executeMethod = _buildPolymorphicExecute(
        config,
        paramsType,
        returnsType,
        variant,
      );

      final spec = UseCaseClassSpec(
        className: variantClassName,
        baseClass: baseClassName,
        fields: fields,
        constructors: constructorParams.isEmpty
            ? const []
            : [
                Constructor(
                  (b) => b..requiredParameters.addAll(constructorParams),
                ),
              ],
        methods: [executeMethod],
        imports: imports,
      );

      final content = classBuilder.build(spec);
      files.add(
        await FileUtils.writeFile(
          variantFilePath,
          content,
          'usecase_polymorphic_variant',
          force: force,
          dryRun: dryRun,
          verbose: verbose,
        ),
      );
    }

    final factoryClassName = '${config.name}UseCaseFactory';
    final factoryFileName = '${classSnake}_usecase_factory.dart';
    final factoryFilePath = path.join(usecaseDirPath, factoryFileName);
    final factoryClass = _buildPolymorphicFactory(
      config,
      baseClassName,
      factoryClassName,
      paramsType,
    );
    final factoryImports = <String>[
      abstractFileName,
      ...config.variants.map(
        (v) => '${StringUtils.camelToSnake('$v${config.name}')}_usecase.dart',
      ),
    ];
    final factorySpec = UseCaseClassSpec(
      className: factoryClassName,
      fields: factoryClass.fields,
      constructors: factoryClass.constructors,
      methods: factoryClass.methods,
      imports: factoryImports,
    );
    final factoryContent = classBuilder.build(factorySpec);
    files.add(
      await FileUtils.writeFile(
        factoryFilePath,
        factoryContent,
        'usecase_polymorphic_factory',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      ),
    );

    return files;
  }
}
