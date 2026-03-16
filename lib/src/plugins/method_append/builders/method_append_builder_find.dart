part of 'method_append_builder.dart';

extension MethodAppendBuilderFind on MethodAppendBuilder {
  Future<String?> _findDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'datasources',
      repoSnake,
      '${repoSnake}_datasource.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'datasources',
        config.domain,
        '${repoSnake}_datasource.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findRemoteDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'datasources',
      repoSnake,
      '${repoSnake}_remote_datasource.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'datasources',
        config.domain,
        '${repoSnake}_remote_datasource.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findLocalDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'datasources',
      repoSnake,
      '${repoSnake}_local_datasource.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'datasources',
        config.domain,
        '${repoSnake}_local_datasource.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findMockDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'datasources',
      repoSnake,
      '${repoSnake}_mock_datasource.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'datasources',
        config.domain,
        '${repoSnake}_mock_datasource.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }

  Future<String?> _findMockProvider(
    GeneratorConfig config,
    String serviceSnake,
  ) async {
    final domainSnake = StringUtils.camelToSnake(config.effectiveDomain);
    final directPath = path.join(
      outputDir,
      'data',
      'providers',
      domainSnake,
      '${serviceSnake}_mock_provider.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    return null;
  }
}
