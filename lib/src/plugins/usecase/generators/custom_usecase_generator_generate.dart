part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorGenerate on CustomUseCaseGenerator {
  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final baseName = config.name.endsWith('UseCase')
        ? config.name.substring(0, config.name.length - 7)
        : config.name;
    final className = '${baseName}UseCase';
    final classSnake = StringUtils.camelToSnake(baseName);
    final fileName = '${classSnake}_usecase.dart';
    final usecaseDirPath = path.join(
      outputDir,
      'domain',
      'usecases',
      config.effectiveDomain,
    );
    final filePath = path.join(usecaseDirPath, fileName);

    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    final baseClass = _baseClass(config, paramsType, returnsType);
    final imports = _buildImports(config, paramsType, returnsType);
    final fields = _buildDependencyFields(config);
    final constructorParams = _buildDependencyParams(fields);
    final methods = _buildMethods(config, paramsType, returnsType, fields);

    final spec = UseCaseClassSpec(
      className: className,
      baseClass: baseClass,
      fields: fields,
      constructors: constructorParams.isEmpty
          ? const []
          : [
              Constructor(
                (b) => b..requiredParameters.addAll(constructorParams),
              ),
            ],
      methods: methods,
      imports: imports,
    );

    final content = classBuilder.build(spec);
    return _writeOrAppend(
      config: config,
      filePath: filePath,
      className: className,
      methodSources: _methodSourcesForAppend(
        config,
        paramsType,
        returnsType,
        fields,
      ),
      content: content,
    );
  }
}
