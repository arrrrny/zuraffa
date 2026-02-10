import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

void main() {
  late Directory workspaceDir;
  late String outputDir;

  setUp(() async {
    workspaceDir = await _createWorkspace();
    outputDir = '${workspaceDir.path}/lib/src';
  });

  tearDown(() async {
    if (workspaceDir.existsSync()) {
      await workspaceDir.delete(recursive: true);
    }
  });

  test('full generation completes under 5 seconds', () async {
    final config = GeneratorConfig(
      name: 'Profile',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      generateData: true,
      generateVpc: true,
      generateState: true,
      generateDi: true,
    );
    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
    );

    final stopwatch = Stopwatch()..start();
    final result = await generator.generate();
    stopwatch.stop();

    expect(result.success, isTrue);
    expect(stopwatch.elapsedMilliseconds < 5000, isTrue);
  });
}

Future<Directory> _createWorkspace() async {
  final root = Directory.current.path;
  final dir = Directory(
    '$root/.tmp_integration_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}
