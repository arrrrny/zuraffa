import 'dart:io';

import 'package:path/path.dart' as path;

/// #431: VPC (view/presenter/controller) generation test utilities.
///
/// These helpers mirror `test/regression/regression_test_utils.dart` from the
/// pure-Dart `zuraffa` core package, with one crucial difference: the fixture
/// workspace's `pubspec.yaml` declares a `flutter:` SDK dependency. That makes
/// the core's `detectProjectFlavor` (`package:zuraffa/src/utils/project_flavor.dart`)
/// classify the fixture as `ProjectFlavor.flutter`, so the controller /
/// presenter / view generators run instead of skipping (Constitution VII:
/// Engine Purity — Flutter-only output belongs in Flutter target packages).
///
/// The pure-Dart `zuraffa` package keeps only the pure-Dart behaviour:
/// domain/data/state generation and the VPC *skip* assertions (issue #420).
class VpcWorkspace {
  final Directory directory;
  final String outputDir;

  const VpcWorkspace({required this.directory, required this.outputDir});
}

/// Creates a temp fixture workspace whose `pubspec.yaml` (written by
/// [writeFlutterPubspec]) declares `flutter:` so VPC generation runs.
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

/// Resolves the absolute root of the package whose pubspec declares
/// [pubspecName].
///
/// Under `flutter test` the CWD is the `zuraffa_flutter` package root (this
/// package's pubspec matches immediately; the monorepo's core `zuraffa`
/// package root matches one level further up). `Isolate.resolvePackageUri`
/// and `Platform.packageConfig` are both unavailable in that environment, so
/// the fallback parses the absolute `file://` source URI out of the current
/// stack trace (frames inside this package's `test/` tree carry them).
String _packageRoot(String pubspecName) {
  // Strategy 1: walk up from the CWD (skip temp paths — some suites run with
  // a contaminated CWD).
  try {
    final cwd = Directory.current.path;
    if (!_isTempPath(cwd)) {
      final root = _walkToRoot(cwd, pubspecName);
      if (root != null) return root;
    }
  } catch (_) {
    // fall through to the stack-trace strategy
  }

  // Strategy 2: walk up from the absolute path of the first stack-trace
  // frame that lives inside this monorepo.
  final framePath = _stackTraceSourcePath();
  if (framePath != null) {
    final root = _walkToRoot(framePath, pubspecName);
    if (root != null) return root;
  }
  throw StateError(
    'cannot locate the $pubspecName package root (CWD='
    '${Directory.current.path})',
  );
}

/// Walks up from [startPath] looking for a `pubspec.yaml` whose `name:` is
/// [pubspecName]. Returns the containing directory, or null when exhausted.
String? _walkToRoot(String startPath, String pubspecName) {
  try {
    var dir = Directory(startPath).existsSync()
        ? Directory(startPath)
        : File(startPath).parent;
    for (var i = 0; i < 20; i++) {
      final pubspec = File(path.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (RegExp(
          '^name:\\s*$pubspecName\\s*\$',
          multiLine: true,
        ).hasMatch(content)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {
    // ignore — next strategy
  }
  return null;
}

/// Extracts the absolute path of the first stack-trace frame whose `file://`
/// URI points inside this monorepo (frames from the SDK / pub cache are
/// ignored).
String? _stackTraceSourcePath() {
  for (final match
      in RegExp(r'file://(/[^()\s:]+\.dart)').allMatches(
        StackTrace.current.toString(),
      )) {
    final candidate = Uri.decodeComponent(match.group(1)!);
    if (candidate.contains('/zuraffa_flutter/') ||
        candidate.contains('/zuraffa/')) {
      return candidate;
    }
  }
  return null;
}

bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  final systemTempLower = Directory.systemTemp.path.toLowerCase();
  return lower == '/tmp' ||
      lower.startsWith('/tmp/') ||
      lower.contains('/tmp/') ||
      lower == systemTempLower ||
      lower.startsWith(systemTempLower);
}

/// Writes a **Flutter** fixture pubspec — the `flutter:` SDK dependency is
/// what flips `detectProjectFlavor` to `ProjectFlavor.flutter`, un-skipping
/// the VPC generators. Both monorepo packages are wired in via path deps so
/// the fixture mirrors a real Flutter app consuming zuraffa + zuraffa_flutter.
Future<void> writeFlutterPubspec(VpcWorkspace workspace) async {
  final coreRoot = _packageRoot('zuraffa');
  final flutterRoot = _packageRoot('zuraffa_flutter');
  final content = '''
name: zuraffa_vpc_test_app
description: Flutter fixture workspace for VPC generation tests (issue #431).
publish_to: none
environment:
  sdk: ">=3.11.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: ${path.normalize(coreRoot)}
  zuraffa_flutter:
    path: ${path.normalize(flutterRoot)}
''';
  await File(path.join(workspace.directory.path, 'pubspec.yaml')).writeAsString(
    content,
  );
}

/// Writes an entity stub WITH an `id` field — mirrors the core package's
/// `writeEntityStub` from `test/regression/regression_test_utils.dart`.
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

/// Writes an entity file WITHOUT an `id` field — mimics what
/// `zfa entity create -n X --field depotId:String` produces (a Zorphy
/// abstract class with `Type get fieldName;` getters). Also writes a
/// matching `<Name>Fields` class so the generated code can reference
/// `<Name>Fields.<fieldName>` constants.
///
/// Mirrors the helpers local to the core's `issue_294` / `issue_302`
/// regression tests (transported here by #431).
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
    ..writeln('// Auto-generated entity stub for VPC test (#431).')
    ..writeln()
    ..writeln('abstract class \$$name {');

  for (final f in fields) {
    buffer.writeln('  ${f.type} get ${f.name};');
  }
  buffer
    ..writeln('}')
    ..writeln();

  // Stub `<Name>Fields` class with Field constants for each declared field.
  // The mock datasource / presenter / test generators reference these.
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
