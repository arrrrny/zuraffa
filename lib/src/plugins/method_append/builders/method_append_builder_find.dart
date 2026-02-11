part of 'method_append_builder.dart';

extension MethodAppendBuilderFind on MethodAppendBuilder {
  Future<String?> _findDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final directPath = path.join(
      outputDir,
      'data',
      'data_sources',
      repoSnake,
      '${repoSnake}_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_data_source.dart',
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
      'data_sources',
      repoSnake,
      '${repoSnake}_remote_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_remote_data_source.dart',
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
      'data_sources',
      repoSnake,
      '${repoSnake}_local_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_local_data_source.dart',
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
      'data_sources',
      repoSnake,
      '${repoSnake}_mock_data_source.dart',
    );
    if (File(directPath).existsSync()) return directPath;
    if (config.domain != null) {
      final domainPath = path.join(
        outputDir,
        'data',
        'data_sources',
        config.domain,
        '${repoSnake}_mock_data_source.dart',
      );
      if (File(domainPath).existsSync()) return domainPath;
    }
    return null;
  }
}
