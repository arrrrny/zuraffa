import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;
  late String zfaBin;
  late bool useCompiledBinary;

  setUpAll(() {
    final homeDir = Platform.environment['HOME'] ?? '';
    final compiledBin = p.join(homeDir, '.pub-cache', 'bin', 'zfa');
    final compiledExists = File(compiledBin).existsSync();

    if (compiledExists) {
      zfaBin = compiledBin;
      useCompiledBinary = true;
    } else {
      zfaBin = File('bin/zfa.dart').absolute.path;
      useCompiledBinary = false;
    }
  });

  Future<ProcessResult> runZfa(List<String> args, {String? workingDirectory}) {
    if (useCompiledBinary) {
      return Process.run(zfaBin, args, workingDirectory: workingDirectory);
    }

    return Process.run('dart', [
      'run',
      zfaBin,
      ...args,
    ], workingDirectory: workingDirectory);
  }

  setUp(() async {
    workspace = await createWorkspace('polymorphic_mock');
    outputDir = workspace.outputDir;

    await writePubspec(workspace);
    final pubGet = await runFlutterPubGet(workspace);
    expect(
      pubGet.exitCode,
      equals(0),
      reason: '${pubGet.stdout}\n${pubGet.stderr}',
    );

    final fixtureContent = File(
      'test/fixtures/sealed_category_config.dart',
    ).readAsStringSync();
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'category_config'),
    );
    await entityDir.create(recursive: true);
    await File(
      p.join(entityDir.path, 'category_config.dart'),
    ).writeAsString(fixtureContent);
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'zfa mock data generates compilable subtype mocks for sealed hierarchies',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final result = await runZfa([
        'mock',
        'data',
        'CategoryConfig',
        '--output',
        outputDir,
        '--force',
      ], workingDirectory: workspace.directory.path);

      expect(
        result.exitCode,
        equals(0),
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(
        result.stdout.toString(),
        contains('Mock data generation complete for: CategoryConfig'),
      );

      final primaryMockFile = File(
        p.join(outputDir, 'data', 'mock', 'primary_category_mock_data.dart'),
      );
      final secondaryMockFile = File(
        p.join(outputDir, 'data', 'mock', 'secondary_category_mock_data.dart'),
      );
      final baseMockFile = File(
        p.join(outputDir, 'data', 'mock', 'category_config_mock_data.dart'),
      );

      expect(primaryMockFile.existsSync(), isTrue);
      expect(secondaryMockFile.existsSync(), isTrue);
      expect(baseMockFile.existsSync(), isFalse);

      final primaryContent = primaryMockFile.readAsStringSync();
      final secondaryContent = secondaryMockFile.readAsStringSync();

      expect(
        primaryContent,
        contains(
          "import '../../domain/entities/category_config/category_config.dart';",
        ),
      );
      expect(primaryContent, contains('PrimaryCategory('));
      expect(secondaryContent, contains('SecondaryCategory('));

      final analyze = await runDartAnalyze(workspace);
      expect(
        analyze.exitCode,
        equals(0),
        reason: '${analyze.stdout}\n${analyze.stderr}',
      );
    },
  );
}
