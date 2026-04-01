import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory workspace;
  late String outputDir;
  late String previousCwd;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zuraffa_vpc_records_');
    outputDir = path.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(
      path.join(workspace.path, 'pubspec.yaml'),
    ).writeAsString('name: zuraffa_test');
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
      'generate',
      'Product',
      '--methods=watch',
      '--vpcs',
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
