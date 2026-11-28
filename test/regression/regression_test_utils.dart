import 'dart:io';

import 'package:path/path.dart' as path;
import '../helpers/project_root.dart';
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

Future<void> writePubspec(
  RegressionWorkspace workspace, {
  String? repoRootOverride,
}) async {
  final repoRoot = repoRootOverride ?? await findProjectRoot();
  final content =
      '''
name: zuraffa_test_app
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  zuraffa:
    path: ${path.normalize(repoRoot)}
  get_it: ^9.0.0
dev_dependencies:
dependency_overrides:
  meta: ^1.18.0
  analyzer: ^12.0.0
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
  // A hand-written stand-in for a zorphy v3 entity's generated surface: the
  // concrete class with `fromTrusted` + `copyWith`, the `<E>Fields` registry
  // of write-capable `ZorphyField`s the toggle writes through, and the
  // `<E>Patch` with the full `ZorphyPatch` algebra. The integration suites
  // COMPILE these fixtures, so every type here is the real
  // zorphy_annotation one.
  await entityFile.writeAsString('''
import 'package:zorphy_annotation/zorphy_annotation.dart';

final class $name {
  const $name.fromTrusted({required this.id});

  final $idType id;

  $name copyWith({$idType? id}) => $name.fromTrusted(id: id ?? this.id);
}

abstract final class ${name}Fields {
  static const ZorphyField<$name, $idType> id = ZorphyField<$name, $idType>(
    name: 'id',
    jsonKey: 'id',
    pointer: '/id',
    get: _getId,
    set: _setId,
  );

  static final List<ZorphyField<$name, Object?>> all = [id.asObject];

  static $idType _getId($name root) => root.id;
  static $name _setId($name root, $idType value) => root.copyWith(id: value);
}

final class ${name}Patch implements ZorphyPatch<$name> {
  const ${name}Patch({this.id = const PatchValue.unchanged()});

  final PatchValue<$idType> id;

  @override
  bool get isEmpty => id.isUnchanged;
  @override
  bool get isNotEmpty => !isEmpty;

  @override
  $name apply(covariant $name target) => target.copyWith(
    id: id.isUnchanged ? target.id : id.valueOrNull,
  );

  @override
  ZorphyPatch<$name> compose(covariant ZorphyPatch<$name> next) => next;

  @override
  ZorphyPatch<$name> invert($name before) =>
      ${name}Patch(id: PatchValue<$idType>.set(before.id));

  @override
  Map<String, Object?> toWire() => const <String, Object?>{};
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
  // Use 'dart pub get' since zuraffa is now a pure Dart package (no Flutter SDK).
  return Process.run('dart', [
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
      generateVpcs: true,
      generateState: true,
      generateDi: true,
      generateRoute: true,
      outputDir: workspace.outputDir,
      dryRun: false,
      force: true,
      verbose: true,
    ),
    outputDir: workspace.outputDir,
  );
  return generator.generate();
}

String _toSnake(String input) {
  final result = <String>[];
  for (var i = 0; i < input.length; i += 1) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char && char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join();
}
