part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorAppend on CustomUseCaseGenerator {
  List<String> _methodSourcesForAppend(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
    final depField = dependencyFields.isNotEmpty
        ? dependencyFields.first.name
        : '';

    if (config.useCaseType == 'stream') {
      final dependencyCall = depField.isEmpty
          ? null
          : refer(depField)
                .property(methodName)
                .call(
                  config.hasMultipleParams
                      ? config.multipleParams
                            .map(
                              (p) => refer(
                                'intent',
                              ).property('params').property(p.name),
                            )
                            .toList()
                      : [refer('intent').property('params')],
                );
      return _buildWatchMethods(paramsType, returnsType, dependencyCall).map((
        method,
      ) {
        return method
            .accept(
              DartEmitter(orderDirectives: true, useNullSafetySyntax: true),
            )
            .toString();
      }).toList();
    }

    if (config.useCaseType == 'sync') {
      final body = depField.isEmpty
          ? '// TODO: Implement logic\n  throw UnimplementedError();'
          : 'return $depField.$methodName(${config.hasMultipleParams ? config.multipleParams.map((p) => 'params.${p.name}').join(', ') : 'params'});';
      return [
        '@override\n$returnsType execute($paramsType params) {\n  $body\n}',
      ];
    }

    final returnTypeRef = config.useCaseType == 'completable'
        ? 'Future<void>'
        : 'Future<$returnsType>';
    final body = depField.isEmpty
        ? '// TODO: Implement logic\n  throw UnimplementedError();'
        : 'return await $depField.$methodName(${config.hasMultipleParams ? config.multipleParams.map((p) => 'params.${p.name}').join(', ') : 'params'});';
    return [
      '@override\n$returnTypeRef execute($paramsType params, CancelToken? cancelToken) async {\n  cancelToken?.throwIfCancelled();\n  $body\n}',
    ];
  }

  Future<GeneratedFile> _writeOrAppend({
    required GeneratorConfig config,
    required String filePath,
    required String className,
    required List<String> methodSources,
    required String content,
  }) async {
    if (config.revert) {
      if (config.appendToExisting) {
        if (options.verbose) {
          print('  Cannot revert append operation for $filePath');
        }
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
        );
      }
      return FileUtils.writeFile(
        filePath,
        content,
        'usecase',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: true,
        skipRevertIfExisted: true,
        fileSystem: fileSystem,
      );
    }

    if (config.appendToExisting &&
        await fileSystem.exists(filePath) &&
        !config.force) {
      var updatedSource = await fileSystem.read(filePath);
      var changed = false;
      for (final methodSource in methodSources) {
        final result = appendExecutor.execute(
          AppendRequest.method(
            source: updatedSource,
            className: className,
            memberSource: methodSource,
          ),
        );
        if (result.changed) {
          updatedSource = result.source;
          changed = true;
        }
      }
      if (!changed) {
        return GeneratedFile(
          path: filePath,
          type: 'usecase',
          action: 'skipped',
          content: updatedSource,
        );
      }
      return FileUtils.writeFile(
        filePath,
        updatedSource,
        'usecase',
        force: true,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: false,
        fileSystem: fileSystem,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );
  }
}
