part of 'method_append_builder.dart';

extension MethodAppendBuilderFind on MethodAppendBuilder {
  Future<String?> _findDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final file = discovery.findFileSync('${repoSnake}_datasource.dart');
    return file?.path;
  }

  Future<String?> _findRemoteDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final file = discovery.findFileSync('${repoSnake}_remote_datasource.dart');
    return file?.path;
  }

  Future<String?> _findLocalDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final file = discovery.findFileSync('${repoSnake}_local_datasource.dart');
    return file?.path;
  }

  Future<String?> _findMockDataSource(
    GeneratorConfig config,
    String repoSnake,
  ) async {
    final file = discovery.findFileSync('${repoSnake}_mock_datasource.dart');
    return file?.path;
  }

  Future<String?> _findMockProvider(
    GeneratorConfig config,
    String serviceSnake,
  ) async {
    final file = discovery.findFileSync('${serviceSnake}_mock_provider.dart');
    return file?.path;
  }
}
