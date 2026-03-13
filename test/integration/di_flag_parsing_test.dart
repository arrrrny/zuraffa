import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/core/generator_options.dart';

void main() {
  final outputDir = path.join(Directory.current.path, 'test_workspace_di_flag');

  setUp(() async {
    final dir = Directory(outputDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);
  });

  tearDown(() async {
    final dir = Directory(outputDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('zfa di create --use-mock correctly sets up mock injection', () async {
    final options = GeneratorOptions(force: true);
    final plugin = DiPlugin(outputDir: outputDir, options: options);
    final capability = plugin.capabilities.firstWhere(
      (c) => c.name == 'create',
    );
    final command = CapabilityCommand(capability);
    final runner = CommandRunner<void>('zfa', 'CLI')..addCommand(command);

    // Run with --use-mock and --repo to ensure repository/datasource DI is generated
    await runner.run([
      'create',
      'Feedback',
      '--repo',
      'Feedback',
      '--use-mock',
      '--output-dir',
      outputDir,
    ]);

    final repoDiFile = File(
      path.join(outputDir, 'di', 'repositories', 'feedback_repository_di.dart'),
    );
    expect(repoDiFile.existsSync(), isTrue);
    final repoDiContent = repoDiFile.readAsStringSync();

    // Verify it uses MockDataSource
    expect(repoDiContent, contains('FeedbackMockDataSource'));
    expect(repoDiContent, isNot(contains('FeedbackRemoteDataSource')));

    // Verify mock datasource DI exists
    final mockDiFile = File(
      path.join(
        outputDir,
        'di',
        'datasources',
        'feedback_mock_datasource_di.dart',
      ),
    );
    expect(mockDiFile.existsSync(), isTrue);

    // Verify remote datasource DI DOES NOT exist
    final remoteDiFile = File(
      path.join(
        outputDir,
        'di',
        'datasources',
        'feedback_remote_datasource_di.dart',
      ),
    );
    expect(remoteDiFile.existsSync(), isFalse);
  });
}
