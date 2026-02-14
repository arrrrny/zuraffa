import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/models/generator_result.dart';

class RegressionWorkspace {
  final Directory directory;
  final String outputDir;

  const RegressionWorkspace({required this.directory, required this.outputDir});
}

Future<RegressionWorkspace> createWorkspace(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  final outputDir = path.join(dir.path, 'lib', 'src');
  return RegressionWorkspace(directory: dir, outputDir: outputDir);
}

Future<void> disposeWorkspace(RegressionWorkspace workspace) async {
  if (workspace.directory.existsSync()) {
    await workspace.directory.delete(recursive: true);
  }
}

Future<void> writePubspec(RegressionWorkspace workspace) async {
  final repoRoot = Directory.current.path;
  final content =
      '''
name: zuraffa_regression_workspace
environment:
  sdk: ">=3.8.0 <4.0.0"
  flutter: ">=3.10.0"
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: ${path.normalize(repoRoot)}
  get_it: ^8.0.0
dependency_overrides:
  meta: 1.17.0
''';
  await File(
    path.join(workspace.directory.path, 'pubspec.yaml'),
  ).writeAsString(content);
}

Future<void> writeEntityStub(
  RegressionWorkspace workspace, {
  required String name,
  String idType = 'String',
}) async {
  final entitySnake = _toSnake(name);
  final entityDir = Directory(
    path.join(workspace.outputDir, 'domain', 'entities', entitySnake),
  );
  await entityDir.create(recursive: true);
  final entityFile = File(path.join(entityDir.path, '$entitySnake.dart'));
  await entityFile.writeAsString('''
class $name {
  final $idType id;

  const $name({required this.id});
}
''');
}

Future<void> writeMainStub(RegressionWorkspace workspace) async {
  final mainFile = File(
    path.join(workspace.directory.path, 'lib', 'main.dart'),
  );
  await mainFile.parent.create(recursive: true);
  await mainFile.writeAsString('''
import 'package:get_it/get_it.dart';

final GetIt getIt = GetIt.instance;

void main() {}
''');
}

Future<ProcessResult> runFlutterPubGet(RegressionWorkspace workspace) {
  return Process.run('flutter', [
    'pub',
    'get',
  ], workingDirectory: workspace.directory.path);
}

Future<ProcessResult> runDartAnalyze(RegressionWorkspace workspace) {
  return Process.run('dart', [
    'analyze',
    'lib/src',
  ], workingDirectory: workspace.directory.path);
}

Future<ProcessResult> runDartFormatCheck(RegressionWorkspace workspace) {
  return Process.run('dart', [
    'format',
    '--set-exit-if-changed',
    'lib/src',
  ], workingDirectory: workspace.directory.path);
}

Future<ProcessResult> runDartAnalyzePaths(
  RegressionWorkspace workspace,
  List<String> paths,
) {
  return Process.run('dart', [
    'analyze',
    ...paths,
  ], workingDirectory: workspace.directory.path);
}

Future<ProcessResult> runDartFormatCheckPaths(
  RegressionWorkspace workspace,
  List<String> paths,
) {
  return Process.run('dart', [
    'format',
    '--set-exit-if-changed',
    ...paths,
  ], workingDirectory: workspace.directory.path);
}

Future<GeneratorResult> generateFullFeature(
  RegressionWorkspace workspace, {
  String name = 'Product',
}) async {
  final generator = CodeGenerator(
    config: GeneratorConfig(
      name: name,
      methods: const [
        'get',
        'getList',
        'create',
        'update',
        'delete',
        'watch',
        'watchList',
      ],
      generateData: true,
      generateVpc: true,
      generateState: true,
      generateDi: true,
      generateRoute: true,
    ),
    outputDir: workspace.outputDir,
    dryRun: false,
    force: true,
    verbose: false,
  );
  return generator.generate();
}

String _toSnake(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i += 1) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char && char != '_') {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}
