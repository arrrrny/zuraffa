part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorCore on CustomUseCaseGenerator {
  String _baseClass(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    switch (config.useCaseType) {
      case 'stream':
        return 'StreamUseCase<$returnsType, $paramsType>';
      case 'background':
        return 'BackgroundUseCase<$returnsType, $paramsType>';
      case 'completable':
        return 'CompletableUseCase<$paramsType>';
      case 'sync':
        return 'SyncUseCase<$returnsType, $paramsType>';
      case 'future':
      default:
        return 'UseCase<$returnsType, $paramsType>';
    }
  }

  List<String> _buildImports(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
  ) {
    final imports = <String>['package:zuraffa/zuraffa.dart'];
    if (config.hasRepo) {
      for (final repo in config.effectiveRepos) {
        final repoSnake = StringUtils.camelToSnake(
          repo.replaceAll('Repository', ''),
        );
        imports.add('../../repositories/${repoSnake}_repository.dart');
      }
    }
    if (config.hasService) {
      final serviceSnake = config.serviceSnake;
      if (serviceSnake == null) {
        throw ArgumentError(
          'Service name must be specified via --service or config.service',
        );
      }
      imports.add('../../services/${serviceSnake}_service.dart');
    }
    imports.addAll(
      CommonPatterns.entityImports([paramsType, returnsType], config, depth: 2),
    );
    return imports;
  }

  List<Field> _buildDependencyFields(GeneratorConfig config) {
    final fields = <Field>[];
    // For custom usecases, prefer service over repo if both provided
    if (config.hasService) {
      final serviceName = config.effectiveService;
      if (serviceName == null) {
        throw ArgumentError(
          'Service name must be specified via --service or config.service',
        );
      }
      final serviceBaseName = serviceName.endsWith('Service')
          ? serviceName.substring(0, serviceName.length - 7)
          : serviceName;
      final serviceFieldName =
          '_${StringUtils.pascalToCamel(serviceBaseName)}Service';
      fields.add(
        Field(
          (b) => b
            ..name = serviceFieldName
            ..type = refer(serviceName)
            ..modifier = FieldModifier.final$,
        ),
      );

      // If we have a service, we don't necessarily need the repo in a custom usecase
      // unless it's explicitly an orchestrator/polymorphic which handles its own fields.
      return fields;
    }

    if (config.hasRepo) {
      for (final repo in config.effectiveRepos) {
        final repoBaseName = repo.replaceAll('Repository', '');
        final repoFieldName =
            '_${StringUtils.pascalToCamel(repoBaseName)}Repository';
        fields.add(
          Field(
            (b) => b
              ..name = repoFieldName
              ..type = refer(repo)
              ..modifier = FieldModifier.final$,
          ),
        );
      }
    }
    return fields;
  }

  List<Parameter> _buildDependencyParams(List<Field> fields) {
    return fields
        .map(
          (field) => Parameter(
            (p) => p
              ..name = field.name
              ..toThis = true,
          ),
        )
        .toList();
  }

  String _resolveUseCasePath(GeneratorConfig config, String usecaseName) {
    final name = usecaseName.endsWith('UseCase')
        ? usecaseName.substring(0, usecaseName.length - 7)
        : usecaseName;
    final snakeName = StringUtils.camelToSnake(name);
    final fileName = '${snakeName}_usecase.dart';

    final usecasesDir = path.join(outputDir, 'domain', 'usecases');
    final usecasesDirectory = Directory(usecasesDir);

    if (usecasesDirectory.existsSync()) {
      for (final domainDir in usecasesDirectory.listSync()) {
        if (domainDir is Directory) {
          final usecaseFile = File(path.join(domainDir.path, fileName));
          if (usecaseFile.existsSync()) {
            final domainName = path.basename(domainDir.path);
            return '../$domainName/$fileName';
          }
          final subfolderFile = File(
            path.join(domainDir.path, snakeName, fileName),
          );
          if (subfolderFile.existsSync()) {
            final domainName = path.basename(domainDir.path);
            return '../$domainName/$snakeName/$fileName';
          }
        }
      }
    }

    return '../$snakeName/${snakeName}_usecase.dart';
  }
}
