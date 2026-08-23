import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Resolve a known-good directory via Platform.script.
/// Immune to CWD changes by other tests.
String _safeRoot() {
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final ps = File('${dir.path}/pubspec.yaml');
      if (ps.existsSync()) {
        final c = ps.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}
  return Directory.systemTemp.path;
}

String _resolvedRoot = _safeRoot();
void main() {
  late Directory workspace;
  late String outputDir;
  late String previousCwd;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zuraffa_vpc_records_');
    outputDir = path.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_test
dependencies:
  flutter:
    sdk: flutter
''');
    previousCwd = Directory.current.path;
    Directory.current = workspace.path;
  });

  tearDown(() async {
    Directory.current = previousCwd;
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  test('VPC generation uses Dart 3.0 Records for watch methods', () async {
    final runner = CliRunner(exitOnCompletion: false);

    // Run generation via CLI runner to ensure all context is built correctly
    await runner.run([
      'make',
      'Product',
      '--methods=watch',
      '--with=vpc',
      '--state',
      '--output',
      outputDir,
      '--force',
    ]);

    final presenterFile = File(
      path.join(
        outputDir,
        'presentation',
        'pages',
        'product',
        'product_presenter.dart',
      ),
    );
    final controllerFile = File(
      path.join(
        outputDir,
        'presentation',
        'pages',
        'product',
        'product_controller.dart',
      ),
    );

    expect(presenterFile.existsSync(), isTrue);
    expect(controllerFile.existsSync(), isTrue);

    final presenterContent = presenterFile.readAsStringSync();
    final controllerContent = controllerFile.readAsStringSync();

    // Verify Presenter returns a Record (Analyzer 12/Dart 3.0)
    expect(
      presenterContent,
      contains('Future<Result<Product, AppFailure>> initial'),
    );
    expect(
      presenterContent,
      contains('Stream<Result<Product, AppFailure>> updates'),
    );
    expect(presenterContent, contains('watchProductRecord(String id)'));
    expect(presenterContent, contains('return ('));
    expect(presenterContent, contains('.first,'));

    // Verify Controller destructures the Record
    expect(
      controllerContent,
      contains(
        'final (initialFuture, updatesStream) = _presenter.watchProductRecord(',
      ),
    );
    expect(controllerContent, contains('updatesStream.listen'));
  });
}
