import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/project/project_context_store.dart';
import 'package:zuraffa/src/core/project/run_store.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('zfa_memory_integration_test');
    outputDir = workspace.outputDir;
    await writePubspec(workspace);
    await writeEntityStub(workspace, name: 'Product');
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('successful generation writes .zfa memory artifacts', () async {
    final generator = CodeGenerator(
      config: GeneratorConfig(
        name: 'Product',
        methods: const ['get'],
        generateRepository: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );

    final result = await generator.generate();

    expect(result.success, isTrue);

    final planFile = File(
      path.join(
        workspace.directory.path,
        '.zfa',
        'plans',
        'last_run_Product.json',
      ),
    );
    expect(planFile.existsSync(), isTrue);

    final runStore = RunStore(projectRoot: workspace.directory.path);
    final runs = await runStore.list();
    expect(runs, isNotEmpty);
    final run = runs.first;
    expect(run.name, 'Product');
    expect(run.files, isNotEmpty);

    final contextStore = ProjectContextStore(
      projectRoot: workspace.directory.path,
    );
    final context = await contextStore.load();
    expect(context, isNotNull);
    expect(context!['version'], '5.0');
    expect(context['domain_root'], 'lib/src/domain');
  });
}
