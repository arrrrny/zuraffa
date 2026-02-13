part of 'method_append_builder.dart';

extension MethodAppendBuilderAppend on MethodAppendBuilder {
  Future<MethodAppendResult> _appendServiceMethod(
    GeneratorConfig config,
  ) async {
    final updatedFiles = <GeneratedFile>[];
    final warnings = <String>[];

    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null || serviceSnake == null) {
      throw ArgumentError(
        'Service name must be specified via --service or config.service',
      );
    }
    final methodName = config.getServiceMethodName();
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';

    final returnRef = _returnType(config.useCaseType, returnsType);

    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      '${serviceSnake}_service.dart',
    );
    final serviceExists = File(servicePath).existsSync();

    if (!serviceExists) {
      await _createService(
        config,
        servicePath,
        serviceName,
        methodName,
        returnRef,
        paramsType,
      );
      updatedFiles.add(
        GeneratedFile(path: servicePath, type: 'service', action: 'created'),
      );
    } else {
      final result = await _appendToInterface(
        config,
        servicePath,
        serviceName,
        methodName,
        returnRef,
        paramsType,
      );
      if (result != null) {
        updatedFiles.add(result);
      } else {
        warnings.add('Failed to append to ${serviceSnake}_service.dart');
      }
    }

    if (config.generateData) {
      final domainSnake = StringUtils.camelToSnake(config.effectiveDomain);
      assert(
        config.effectiveProvider != null,
        'Provider name must be specified for service append operations',
      );
      final providerName = config.effectiveProvider;
      if (providerName == null) {
        throw ArgumentError(
          'Provider name must be specified for service append operations',
        );
      }
      final providerPath = path.join(
        outputDir,
        'data',
        'providers',
        domainSnake,
        '${serviceSnake}_provider.dart',
      );

      if (File(providerPath).existsSync()) {
        final result = await _appendToProvider(
          config,
          providerPath,
          providerName,
          methodName,
          returnRef,
          paramsType,
        );
        if (result != null) {
          updatedFiles.add(result);
        } else {
          warnings.add('Failed to append to ${serviceSnake}_provider.dart');
        }
      } else {
        await _createProvider(
          config,
          providerPath,
          serviceName,
          methodName,
          returnRef,
          paramsType,
        );
        updatedFiles.add(
          GeneratedFile(
            path: providerPath,
            type: 'provider',
            action: 'created',
          ),
        );
      }
    }

    return MethodAppendResult(updatedFiles, warnings);
  }

  Future<GeneratedFile?> _appendToInterface(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        ),
    );

    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'interface',
        action: 'updated',
      );
    }
    return null;
  }

  Future<GeneratedFile?> _appendToDataRepository(
    GeneratorConfig config,
    String filePath,
    String methodName,
    Reference returnType,
    String paramsType,
    String repoSnake,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final dataSourceFieldMatch = RegExp(
      r'final \w+ (_\w+);',
    ).firstMatch(source);
    final dataSourceField = dataSourceFieldMatch?.group(1) ?? '_dataSource';

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = refer(dataSourceField)
            .property(methodName)
            .call([refer('params')])
            .maybeAwaited(!isStream && !isSync)
            .returned
            .statement,
    );

    final className =
        'Data${StringUtils.convertToPascalCase(repoSnake)}Repository';
    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'repository',
        action: 'updated',
      );
    }
    return null;
  }

  Future<GeneratedFile?> _appendToRemoteDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement remote $methodName',
    );
  }

  Future<GeneratedFile?> _appendToLocalDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement local storage $methodName',
    );
  }

  Future<GeneratedFile?> _appendToMockDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Return mock data for $methodName',
    );
  }

  Future<GeneratedFile?> _appendToProvider(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      paramsType,
      'Implement $methodName',
    );
  }

  Future<GeneratedFile?> _appendToDataSourceImpl(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    String paramsType,
    String errorMessage,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    var source = await file.readAsString();
    source = await _addMissingImports(config, source, filePath);

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'params'
              ..type = refer(paramsType),
          ),
        )
        ..body = refer(
          'UnimplementedError',
        ).call([literalString(errorMessage)]).thrown.statement,
    );

    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    if (result.changed) {
      await FileUtils.writeFile(
        filePath,
        result.source,
        'append',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
      );
      return GeneratedFile(
        path: filePath,
        type: 'datasource',
        action: 'updated',
      );
    }
    return null;
  }
}
