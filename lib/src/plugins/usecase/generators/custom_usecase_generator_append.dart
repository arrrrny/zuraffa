part of 'custom_usecase_generator.dart';

extension CustomUseCaseGeneratorAppend on CustomUseCaseGenerator {
  List<String> _methodSourcesForAppend(
    GeneratorConfig config,
    String paramsType,
    String returnsType,
    List<Field> dependencyFields,
  ) {
    if (config.useCaseType == 'background') {
      final buildTaskSource =
          '@override\nBackgroundTask<$paramsType> buildTask() { return _process; }';
      final processSource =
          'static void _process(BackgroundTaskContext<$paramsType> context) {\n  try {\n    final params = context.params;\n    final result = processData(params);\n    context.sendData(result);\n    context.sendDone();\n  } catch (e, stackTrace) {\n    context.sendError(e, stackTrace);\n  }\n}';
      final processDataSource =
          'static $returnsType processData($paramsType params) {\n  throw UnimplementedError(\'Implement your background processing logic\');\n}';
      return [buildTaskSource, processSource, processDataSource];
    }

    final methodName = config.hasService
        ? config.getServiceMethodName()
        : config.getRepoMethodName();
    final depField = dependencyFields.isNotEmpty
        ? dependencyFields.first.name
        : '';

    if (config.useCaseType == 'stream') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        '@override\nStream<$returnsType> execute($paramsType params, CancelToken? cancelToken) {\n  $body\n}',
      ];
    }

    if (config.useCaseType == 'sync') {
      final body = depField.isEmpty
          ? 'throw UnimplementedError();'
          : 'return $depField.$methodName(params);';
      return [
        '@override\n$returnsType execute($paramsType params) {\n  $body\n}',
      ];
    }

    final returnTypeRef = config.useCaseType == 'completable'
        ? 'Future<void>'
        : 'Future<$returnsType>';
    final body = depField.isEmpty
        ? 'throw UnimplementedError();'
        : 'return await $depField.$methodName(params);';
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
    if (config.appendToExisting && File(filePath).existsSync()) {
      if (force) {
        return FileUtils.writeFile(
          filePath,
          content,
          'usecase',
          force: true,
          dryRun: dryRun,
          verbose: verbose,
        );
      }

      var updatedSource = await File(filePath).readAsString();
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
        dryRun: dryRun,
        verbose: verbose,
      );
    }

    return FileUtils.writeFile(
      filePath,
      content,
      'usecase',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
  }
}
