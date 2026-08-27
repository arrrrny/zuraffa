import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/models/generator_result.dart';

/// Test-workspace helpers for the VPC (view/presenter/controller) generator
/// tests that live in `zuraffa_flutter` (issues #431 / #435).
///
/// Unlike the pure-Dart regression fixtures of the core package
/// (`test/regression/regression_test_utils.dart`), these workspaces declare a
/// `flutter:` SDK in their pubspec so the presentation-layer generators run
/// on their intended target instead of being skipped (Constitution VII:
/// Engine Purity — pure-Dart targets skip VPC output).
class VpcWorkspace {
  final Directory directory;
  final String outputDir;

  const VpcWorkspace({required this.directory, required this.outputDir});
}

Future<VpcWorkspace> createWorkspace(String prefix) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  final outputDir = path.join(dir.path, 'lib', 'src');
  return VpcWorkspace(directory: dir, outputDir: outputDir);
}

Future<void> disposeWorkspace(VpcWorkspace workspace) async {
  if (workspace.directory.existsSync()) {
    await workspace.directory.delete(recursive: true);
  }
}

/// Locates the monorepo root (the checkout containing `zuraffa_flutter/`).
Future<String> findProjectRoot() async {
  final starts = <String>[
    Directory.current.path,
    File.fromUri(Platform.script).parent.path,
  ];
  for (final start in starts) {
    var dir = Directory(path.absolute(start));
    for (var i = 0; i < 12; i += 1) {
      final pubspec = File(path.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (RegExp(
          r'^name:\s*zuraffa_flutter\s*$',
          multiLine: true,
        ).hasMatch(content)) {
          return dir.parent.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  throw StateError('zuraffa_flutter package root not found');
}

/// Writes a *Flutter* pubspec (declares `flutter:`) into [projectRoot] so the
/// VPC generators detect a Flutter target and emit their output.
///
/// This is the lightweight flavour-only variant used by plugin-level tests:
/// the fixture is never pub-getted or analyzed, so no path deps are needed.
Future<void> writeFlutterPubspecAt(
  String projectRoot, {
  String name = 'zuraffa_vpc_target',
}) async {
  await File(path.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: $name
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
''');
}

/// Writes the full Flutter fixture pubspec for a [VpcWorkspace], mirroring the
/// core `writePubspec` helper plus the `flutter:` SDK and a local
/// `zuraffa_flutter` path dependency (the package the generated VPC code
/// imports).
Future<void> writeFlutterPubspec(VpcWorkspace workspace) async {
  final repoRoot = await findProjectRoot();
  final content =
      '''
name: zuraffa_vpc_test_app
environment:
  sdk: ">=3.8.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: ${path.normalize(repoRoot)}
  zuraffa_flutter:
    path: ${path.normalize(path.join(repoRoot, 'zuraffa_flutter'))}
  get_it: ^9.0.0
dev_dependencies:
  mocktail: ^1.0.4
dependency_overrides:
  meta: ^1.19.0
  analyzer: ^14.0.0
''';
  await File(
    path.join(workspace.directory.path, 'pubspec.yaml'),
  ).writeAsString(content);
}

Future<void> writeEntityStub(
  VpcWorkspace workspace, {
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

class ${name}Patch {
  final $idType? id;

  const ${name}Patch({this.id});
}

class ${name}Fields {
  static const Field<$name, $idType> id = Field(name: 'id');
  static const Field<$name, String> slug = Field(name: 'slug');
}
''');
}

/// Entity stub for entities WITHOUT an `id` field (issues #294 / #302): the
/// id-like field must be resolved from the declared fields.
Future<void> writeEntityStubWithoutId(
  VpcWorkspace workspace, {
  required String name,
  required List<({String name, String type})> fields,
}) async {
  final entitySnake = _toSnake(name);
  final entityDir = Directory(
    path.join(workspace.outputDir, 'domain', 'entities', entitySnake),
  );
  await entityDir.create(recursive: true);
  final entityFile = File(path.join(entityDir.path, '$entitySnake.dart'));

  final buffer = StringBuffer()
    ..writeln('// Auto-generated entity stub for the VPC regression test.')
    ..writeln()
    ..writeln('abstract class \$$name {');

  for (final f in fields) {
    buffer.writeln('  ${f.type} get ${f.name};');
  }
  buffer
    ..writeln('}')
    ..writeln();

  buffer.writeln('abstract final class ${name}Fields {');
  for (final f in fields) {
    buffer.writeln(
      "  static const Field<$name, ${f.type}> ${f.name} = "
      "Field<$name, ${f.type}>(name: '${f.name}');",
    );
  }
  buffer.writeln('}');

  await entityFile.writeAsString(buffer.toString());
}

/// Mirrors the core `generateFullFeature` helper: a canonical full-stack
/// `zfa make` generation over a Flutter-flavoured workspace.
Future<GeneratorResult> generateFullFeature(
  VpcWorkspace workspace, {
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
