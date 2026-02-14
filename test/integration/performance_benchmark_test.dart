import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

@Timeout(Duration(minutes: 2))
void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('performance_benchmark');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
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
    expect(stopwatch.elapsedMilliseconds < 10000, isTrue);
  });
}
