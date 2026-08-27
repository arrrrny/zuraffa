@Tags(['integration', 'slow'])
import 'dart:io';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import '../regression/regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('toggle_method_test');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  // tearDown(() async {
  //   await disposeWorkspace(workspace);
  // });

  test('toggle method is generated across all layers', () async {
    final generator = CodeGenerator(
      config: GeneratorConfig(
        name: 'Todo',
        methods: const ['get', 'toggle'],
        generateData: true,
        generateLocal: true,
        generateUseCase: true,
        generateVpcs: true,
        generateState: true,
        outputDir: outputDir,
      ),
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    final result = await generator.generate();
    expect(result.success, isTrue);

    // 1. Check Repository Interface
    final repoFile = File(
      '$outputDir/domain/repositories/todo_repository.dart',
    );
    expect(repoFile.existsSync(), isTrue);
    final repoContent = repoFile.readAsStringSync();
    expect(
      repoContent.contains(
        'Future<Todo> toggle(ToggleParams<String, Field<Todo, dynamic>> params)',
      ),
      isTrue,
    );

    // 2. Check UseCase
    final useCaseFile = File(
      '$outputDir/domain/usecases/todo/toggle_todo_usecase.dart',
    );
    expect(useCaseFile.existsSync(), isTrue);
    final useCaseContent = useCaseFile.readAsStringSync();
    expect(
      useCaseContent.contains(
        'extends UseCase<Todo, ToggleParams<String, Field<Todo, dynamic>>>',
      ),
      isTrue,
    );

    // 3. Check Data Repository Implementation
    final dataRepoFile = File(
      '$outputDir/data/repositories/data_todo_repository.dart',
    );
    expect(dataRepoFile.existsSync(), isTrue);
    final dataRepoContent = dataRepoFile.readAsStringSync();
    expect(
      dataRepoContent.contains(
        'Future<Todo> toggle(ToggleParams<String, Field<Todo, dynamic>> params)',
      ),
      isTrue,
    );
    expect(dataRepoContent.contains('_dataSource.toggle(params)'), isTrue);

    // 4. Check DataSource Interface
    final dataSourceFile = File(
      '$outputDir/data/datasources/todo/todo_datasource.dart',
    );
    expect(dataSourceFile.existsSync(), isTrue);
    final dataSourceContent = dataSourceFile.readAsStringSync();
    expect(
      dataSourceContent.contains(
        'Future<Todo> toggle(ToggleParams<String, Field<Todo, dynamic>> params)',
      ),
      isTrue,
    );

    // 5. Check Remote DataSource
    final remoteFile = File(
      '$outputDir/data/datasources/todo/todo_remote_datasource.dart',
    );
    expect(remoteFile.existsSync(), isTrue);
    final remoteContent = remoteFile.readAsStringSync();
    expect(
      remoteContent.contains(
        'Future<Todo> toggle(ToggleParams<String, Field<Todo, dynamic>> params) async',
      ),
      isTrue,
    );
    expect(
      remoteContent.contains(
        "throw UnimplementedError('Implement remote toggle')",
      ),
      isTrue,
    );

    // 6. Check Local DataSource
    final localFile = File(
      '$outputDir/data/datasources/todo/todo_local_datasource.dart',
    );
    expect(localFile.existsSync(), isTrue);
    final localContent = localFile.readAsStringSync();
    expect(
      localContent.contains(
        'Future<Todo> toggle(ToggleParams<String, Field<Todo, dynamic>> params) async',
      ),
      isTrue,
    );
    expect(
      localContent.contains(
        'existing.copyWithField(params.field, params.value)',
      ),
      isTrue,
    );

    // 7. Check State (for isToggling flag)
    final stateFile = File(
      '$outputDir/presentation/pages/todo/todo_state.dart',
    );
    expect(stateFile.existsSync(), isTrue);
    final stateContent = stateFile.readAsStringSync();
    expect(stateContent, contains('final bool isToggling;'));
    expect(stateContent, contains('this.isToggling = false'));
    expect(stateContent, contains('bool? isToggling'));

    // 8. Check Presenter
    final presenterFile = File(
      '$outputDir/presentation/pages/todo/todo_presenter.dart',
    );
    expect(presenterFile.existsSync(), isTrue);
    final presenterContent = presenterFile.readAsStringSync();
    expect(
      presenterContent,
      contains('Future<Result<Todo, AppFailure>> toggleTodo'),
    );

    // 9. Check Controller
    final controllerFile = File(
      '$outputDir/presentation/pages/todo/todo_controller.dart',
    );
    expect(controllerFile.existsSync(), isTrue);
    final controllerContent = controllerFile.readAsStringSync();
    expect(controllerContent, contains('Future<void> toggleTodo'));
    expect(controllerContent, contains('isToggling'));
    expect(controllerContent, contains('_presenter.toggleTodo'));
  });

  // Regression test for #289: PR #287 added 'toggle' to the entity-methods
  // default used by the di/test plugins (['get', 'update', 'toggle']) so a
  // canonical `zfa make <Entity> --preset=crud --with=vpc,state,di,test`
  // routes through the per-method generators. The test builder's method
  // switch had no `toggle` case, so the test plugin crashed with
  // `Unknown method: toggle` before emitting any file. This locks in the
  // fix: with the test plugin on + toggle in the methods list, generation
  // succeeds AND the per-method toggle usecase test file is emitted with the
  // expected shape.
  test(
    '#289 — toggle test file is generated when test plugin is on (no Unknown method: toggle crash)',
    () async {
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Todo',
          methods: const ['get', 'update', 'toggle'],
          generateData: true,
          generateLocal: true,
          generateUseCase: true,
          generateVpcs: true,
          generateState: true,
          generateDi: true,
          generateTest: true,
          outputDir: outputDir,
        ),
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      final result = await generator.generate();
      expect(
        result.success,
        isTrue,
        reason: 'Generation crashed: ${result.errors.join('; ')}',
      );

      // The per-method test builder must emit a toggle-specific test file.
      final toggleTestFile = File(
        '$outputDir/../../test/domain/usecases/todo/toggle_todo_usecase_test.dart',
      );
      expect(
        toggleTestFile.existsSync(),
        isTrue,
        reason: 'toggle_todo_usecase_test.dart should be generated',
      );

      final content = toggleTestFile.readAsStringSync();
      // Class name follows the usecase generator's pattern.
      expect(content, contains('ToggleTodoUseCase'));
      // The mock repository must be exercised via its toggle method.
      expect(content, contains('mockRepository.toggle('));
      // The params constructor must match the usecase generator's signature.
      expect(content, contains('ToggleParams<String, Field<Todo, dynamic>>'));
      // The Field constant must come from the entity's Fields class
      // (config.queryField defaults to 'id').
      expect(content, contains('TodoFields.id'));
    },
  );
}
