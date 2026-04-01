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
    final multipleParams = config.multipleParams;
    final returnsType = config.returnsType ?? 'void';

    final returnRef = _returnType(config.useCaseType, returnsType);

    final effectiveParams = multipleParams.isNotEmpty
        ? multipleParams
        : paramsType;

    if (!config.isPrivate) {
      final servicePath = path.join(
        outputDir,
        'domain',
        'services',
        '${serviceSnake}_service.dart',
      );
      final serviceExists = await fileSystem.exists(servicePath);

      if (!serviceExists) {
        if (!config.revert) {
          await _createService(
            config,
            servicePath,
            serviceName,
            methodName,
            returnRef,
            effectiveParams,
          );
          updatedFiles.add(
            GeneratedFile(
              path: servicePath,
              type: 'service',
              action: 'created',
            ),
          );
        }
      } else {
        final result = await _appendToInterface(
          config,
          servicePath,
          serviceName,
          methodName,
          returnRef,
          effectiveParams,
          type: 'service',
        );
        if (result != null) {
          updatedFiles.add(result);
          // Also add the host file itself as updated
          updatedFiles.add(
            GeneratedFile(
              path: servicePath,
              type: 'service',
              action: 'updated',
            ),
          );
        } else {
          warnings.add('Failed to append to ${serviceSnake}_service.dart');
        }
      }
    }

    if (config.generateData) {
      final providerName = config.effectiveProvider;
      if (providerName == null) {
        throw ArgumentError(
          'Provider name must be specified for service append operations',
        );
      }

      final providersDir = path.join(outputDir, 'data', 'providers');
      var providerPath = await FileUtils.findFileImplementing(
        providersDir,
        serviceName,
        fileSystem: fileSystem,
      );

      if (providerPath == null) {
        final domainSnake = StringUtils.camelToSnake(config.effectiveDomain);
        providerPath = path.join(
          providersDir,
          domainSnake,
          '${serviceSnake}_provider.dart',
        );
      }

      if (await fileSystem.exists(providerPath)) {
        final result = await _appendToProvider(
          config,
          providerPath,
          providerName,
          methodName,
          returnRef,
          effectiveParams,
        );
        if (result != null) {
          updatedFiles.add(result);
          updatedFiles.add(
            GeneratedFile(
              path: providerPath,
              type: 'provider',
              action: 'updated',
            ),
          );
        } else {
          warnings.add('Failed to append to ${serviceSnake}_provider.dart');
        }
      } else if (!config.revert) {
        await _createProvider(
          config,
          providerPath,
          serviceName,
          methodName,
          returnRef,
          effectiveParams,
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

    final mockProviderPath = await _findMockProvider(config, serviceSnake);
    if (mockProviderPath != null) {
      final mockProviderName =
          '${StringUtils.convertToPascalCase(serviceSnake)}MockProvider';
      final result = await _appendToMockProvider(
        config,
        mockProviderPath,
        mockProviderName,
        methodName,
        returnRef,
        effectiveParams,
      );
      if (result != null) {
        updatedFiles.add(result);
        updatedFiles.add(
          GeneratedFile(
            path: mockProviderPath,
            type: 'mock_provider',
            action: 'updated',
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
    Object params, {
    String type = 'interface',
  }) async {
    if (!await fileSystem.exists(filePath)) return null;

    final helper = const AstHelper();
    final augmentFileName = path
        .basename(filePath)
        .replaceFirst('.dart', '.augment.dart');

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params as String),
                  ),
                ],
        ),
    );

    if (config.revert) {
      await augmentationBuilder.remove(
        hostPath: filePath,
        className: className,
        members: [method],
        dryRun: options.dryRun,
      );

      var source = await fileSystem.read(filePath);
      source = helper.removeAugment(
        source: source,
        augmentPath: augmentFileName,
      );

      if (helper.isClassEmpty(source, className)) {
        return FileUtils.deleteFile(
          filePath,
          type,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      await FileUtils.writeFile(
        filePath,
        source,
        type,
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );

      return GeneratedFile(path: filePath, type: type, action: 'reverted');
    }

    var source = await fileSystem.read(filePath);

    source = helper.addAugment(source: source, augmentPath: augmentFileName);
    source = await _addMissingImports(config, source, filePath);

    await FileUtils.writeFile(
      filePath,
      source,
      type,
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );

    final augmentationFile = await augmentationBuilder.generate(
      hostPath: filePath,
      className: className,
      members: [method],
      dryRun: options.dryRun,
    );

    return GeneratedFile(
      path: augmentationFile.path,
      type: type,
      action: 'updated',
    );
  }

  Future<GeneratedFile?> _appendToDataRepository(
    GeneratorConfig config,
    String filePath,
    String methodName,
    Reference returnType,
    Object params,
    String repoSnake,
  ) async {
    if (!await fileSystem.exists(filePath)) return null;

    final helper = const AstHelper();
    final augmentFileName = path
        .basename(filePath)
        .replaceFirst('.dart', '.augment.dart');

    final className =
        'Data${StringUtils.convertToPascalCase(repoSnake)}Repository';

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    var source = await fileSystem.read(filePath);
    final dataSourceFieldMatch = RegExp(
      r'final \w+ (_\w+);',
    ).firstMatch(source);
    final dataSourceField = dataSourceFieldMatch?.group(1) ?? '_dataSource';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.addAll([if (!config.isPrivate) refer('override')])
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params as String),
                  ),
                ],
        )
        ..body = refer(dataSourceField)
            .property(methodName)
            .call(
              params is List<Param>
                  ? params.map((p) => refer(p.name))
                  : [
                      refer(
                        params == 'NoParams'
                            ? 'params'
                            : params.toString().toLowerCase(),
                      ),
                    ],
            )
            .maybeAwaited(!isStream && !isSync)
            .returned
            .statement,
    );

    if (config.revert) {
      await augmentationBuilder.remove(
        hostPath: filePath,
        className: className,
        members: [method],
        dryRun: options.dryRun,
      );

      source = helper.removeAugment(
        source: source,
        augmentPath: augmentFileName,
      );

      if (helper.isClassEmpty(source, className)) {
        return FileUtils.deleteFile(
          filePath,
          'repository_implementation',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      await FileUtils.writeFile(
        filePath,
        source,
        'repository_implementation',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
      return GeneratedFile(
        path: filePath,
        type: 'repository_implementation',
        action: 'reverted',
      );
    }

    source = helper.addAugment(source: source, augmentPath: augmentFileName);
    source = await _addMissingImports(config, source, filePath);

    await FileUtils.writeFile(
      filePath,
      source,
      'repository_implementation',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );

    final augmentationFile = await augmentationBuilder.generate(
      hostPath: filePath,
      className: className,
      members: [method],
      dryRun: options.dryRun,
    );

    return GeneratedFile(
      path: augmentationFile.path,
      type: 'repository_implementation',
      action: 'updated',
    );
  }

  Future<GeneratedFile?> _appendToRemoteDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      params,
      'Implement remote $methodName',
      type: 'remote_datasource',
    );
  }

  Future<GeneratedFile?> _appendToLocalDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      params,
      'Implement local storage $methodName',
      type: 'local_datasource',
    );
  }

  Future<GeneratedFile?> _appendToMockDataSource(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    if (!await fileSystem.exists(filePath)) return null;

    final helper = const AstHelper();
    final augmentFileName = path
        .basename(filePath)
        .replaceFirst('.dart', '.augment.dart');

    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.add(refer('override'))
        ..modifier = MethodModifier.async
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params as String),
                  ),
                ],
        )
        ..body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString(
                  params is List<Param>
                      ? '$methodName called'
                      : '$methodName called with params: \$params',
                ),
              ]).statement,
              refer(
                'Future',
              ).property('delayed').call([refer('_delay')]).awaited.statement,
              if (isList) ...[
                refer(
                  '${entityName}MockData',
                ).property('sampleList').returned.statement,
              ] else if (baseReturns == 'void') ...[
                refer('Future').property('value').call([]).returned.statement,
              ] else ...[
                refer(
                  '${entityName}MockData',
                ).property('sample$entityName').returned.statement,
              ],
            ]),
        ),
    );

    if (config.revert) {
      await augmentationBuilder.remove(
        hostPath: filePath,
        className: className,
        members: [method],
        dryRun: options.dryRun,
      );

      var source = await fileSystem.read(filePath);
      source = helper.removeAugment(
        source: source,
        augmentPath: augmentFileName,
      );

      if (helper.isClassEmpty(source, className)) {
        return FileUtils.deleteFile(
          filePath,
          'mock_datasource',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      await FileUtils.writeFile(
        filePath,
        source,
        'mock_datasource',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
      return GeneratedFile(
        path: filePath,
        type: 'mock_datasource',
        action: 'reverted',
      );
    }

    var source = await fileSystem.read(filePath);

    source = helper.addAugment(source: source, augmentPath: augmentFileName);
    source = await _addMissingImports(config, source, filePath, isMock: true);

    await FileUtils.writeFile(
      filePath,
      source,
      'mock_datasource',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );

    final augmentationFile = await augmentationBuilder.generate(
      hostPath: filePath,
      className: className,
      members: [method],
      dryRun: options.dryRun,
    );

    return GeneratedFile(
      path: augmentationFile.path,
      type: 'mock_datasource',
      action: 'updated',
    );
  }

  Future<GeneratedFile?> _appendToProvider(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    return _appendToDataSourceImpl(
      config,
      filePath,
      className,
      methodName,
      returnType,
      params,
      'Implement $methodName',
      isMock: filePath.contains('_mock_provider.dart'),
      type: 'provider',
    );
  }

  Future<GeneratedFile?> _appendToDataSourceImpl(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
    String errorMessage, {
    bool isMock = false,
    String type = 'datasource',
  }) async {
    if (!await fileSystem.exists(filePath)) return null;

    final helper = const AstHelper();
    final augmentFileName = path
        .basename(filePath)
        .replaceFirst('.dart', '.augment.dart');

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.addAll([if (!config.isPrivate) refer('override')])
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params as String),
                  ),
                ],
        )
        ..body = Block(
          (b) => b
            ..statements.add(
              refer(
                'UnimplementedError',
              ).call([literalString(errorMessage)]).thrown.statement,
            ),
        ),
    );

    if (config.revert) {
      await augmentationBuilder.remove(
        hostPath: filePath,
        className: className,
        members: [method],
        dryRun: options.dryRun,
      );

      var source = await fileSystem.read(filePath);
      source = helper.removeAugment(
        source: source,
        augmentPath: augmentFileName,
      );

      if (helper.isClassEmpty(source, className)) {
        return FileUtils.deleteFile(
          filePath,
          type,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      await FileUtils.writeFile(
        filePath,
        source,
        type,
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
      return GeneratedFile(path: filePath, type: type, action: 'reverted');
    }

    var source = await fileSystem.read(filePath);

    source = helper.addAugment(source: source, augmentPath: augmentFileName);
    source = await _addMissingImports(config, source, filePath, isMock: isMock);

    await FileUtils.writeFile(
      filePath,
      source,
      type,
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );

    final augmentationFile = await augmentationBuilder.generate(
      hostPath: filePath,
      className: className,
      members: [method],
      dryRun: options.dryRun,
    );

    return GeneratedFile(
      path: augmentationFile.path,
      type: type,
      action: 'updated',
    );
  }

  Future<GeneratedFile?> _appendToMockProvider(
    GeneratorConfig config,
    String filePath,
    String className,
    String methodName,
    Reference returnType,
    Object params,
  ) async {
    if (!await fileSystem.exists(filePath)) return null;

    final helper = const AstHelper();
    final augmentFileName = path
        .basename(filePath)
        .replaceFirst('.dart', '.augment.dart');

    final isStream = config.useCaseType == 'stream';
    final isSync = config.useCaseType == 'sync';

    final returns = config.returnsType ?? 'void';
    final baseReturns = returns.replaceAll('?', '');
    final isList = baseReturns.startsWith('List<');
    final entityName = config.repo != null
        ? config.repo!.replaceAll('Repository', '')
        : config.name;

    final primitives = {
      'String',
      'int',
      'double',
      'bool',
      'void',
      'DateTime',
      'dynamic',
      'Object',
    };
    final isPrimitive =
        primitives.contains(baseReturns) ||
        (isList &&
            primitives.contains(
              baseReturns
                  .substring(5, baseReturns.length - 1)
                  .replaceAll('?', ''),
            ));

    final mockDataClass = '${entityName}MockData';
    final sampleProperty = 'sample$entityName';

    final method = Method(
      (m) => m
        ..name = methodName
        ..returns = returnType
        ..annotations.addAll([if (!config.isPrivate) refer('override')])
        ..modifier = isStream || isSync ? null : MethodModifier.async
        ..requiredParameters.addAll(
          params is List<Param>
              ? params.map(
                  (p) => Parameter(
                    (pp) => pp
                      ..name = p.name
                      ..type = refer(p.type),
                  ),
                )
              : [
                  Parameter(
                    (p) => p
                      ..name = 'params'
                      ..type = refer(params as String),
                  ),
                ],
        )
        ..body = Block(
          (b) => b
            ..statements.addAll([
              refer('logger').property('info').call([
                literalString(
                  params is List<Param>
                      ? '$methodName called'
                      : '$methodName called with params: \$params',
                ),
              ]).statement,
              if (isStream) ...[
                refer('Stream')
                    .property('fromFuture')
                    .call([
                      refer('Future').property('delayed').call([
                        refer('_delay'),
                        Method(
                          (mm) => mm
                            ..lambda = true
                            ..body = isPrimitive
                                ? (isList
                                      ? literalList([]).code
                                      : (baseReturns == 'void'
                                            ? literalNull.code
                                            : _primitiveValue(
                                                baseReturns,
                                              ).code))
                                : (isList
                                      ? refer(
                                          mockDataClass,
                                        ).property('sampleList').code
                                      : refer(
                                          mockDataClass,
                                        ).property(sampleProperty).code),
                        ).closure,
                      ]),
                    ])
                    .returned
                    .statement,
              ] else ...[
                refer(
                  'Future',
                ).property('delayed').call([refer('_delay')]).awaited.statement,
                if (isPrimitive) ...[
                  if (isList)
                    literalList([]).returned.statement
                  else if (baseReturns == 'void')
                    refer(
                      'Future',
                    ).property('value').call([]).returned.statement
                  else
                    _primitiveValue(baseReturns).returned.statement,
                ] else ...[
                  if (isList)
                    refer(
                      mockDataClass,
                    ).property('sampleList').returned.statement
                  else
                    refer(
                      mockDataClass,
                    ).property(sampleProperty).returned.statement,
                ],
              ],
            ]),
        ),
    );

    if (config.revert) {
      await augmentationBuilder.remove(
        hostPath: filePath,
        className: className,
        members: [method],
        dryRun: options.dryRun,
      );

      var source = await fileSystem.read(filePath);
      source = helper.removeAugment(
        source: source,
        augmentPath: augmentFileName,
      );

      if (helper.isClassEmpty(source, className)) {
        return FileUtils.deleteFile(
          filePath,
          'provider',
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        );
      }

      await FileUtils.writeFile(
        filePath,
        source,
        'provider',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        fileSystem: fileSystem,
      );
      return GeneratedFile(
        path: filePath,
        type: 'provider',
        action: 'reverted',
      );
    }

    var source = await fileSystem.read(filePath);

    source = helper.addAugment(source: source, augmentPath: augmentFileName);
    source = await _addMissingImports(config, source, filePath, isMock: true);

    await FileUtils.writeFile(
      filePath,
      source,
      'provider',
      force: true,
      dryRun: options.dryRun,
      verbose: options.verbose,
      fileSystem: fileSystem,
    );

    final augmentationFile = await augmentationBuilder.generate(
      hostPath: filePath,
      className: className,
      members: [method],
      dryRun: options.dryRun,
    );

    return GeneratedFile(
      path: augmentationFile.path,
      type: 'provider',
      action: 'updated',
    );
  }
}
