// Transported from the pure-Dart `zuraffa` core package (issue #431).
//
// Integration coverage for the toggle method across the VPC layer. The core's
// `test/integration/toggle_method_test.dart` runs against a *pure-Dart*
// fixture, where VPC generation is now correctly skipped (Constitution VII:
// Engine Purity, see #420) — so the presenter/controller assertions were
// transported into THIS package where the fixture pubspec declares
// `flutter:` and the VPC generators actually run. The core keeps the
// domain/data/state layer assertions (repository, usecase, datasource, local
// datasource, state) and the VPC skip assertions.
//
// See: test/integration/toggle_method_test.dart (core),
// https://github.com/arrrrny/zuraffa/issues/431.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('toggle_method_vpc_');
    await writeFlutterPubspec(workspace);
    await writeEntityStub(workspace, name: 'Todo');
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test('toggle method is generated across the VPC layer (Flutter target)', () async {
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

    // 1. Check State (for isToggling flag)
    final stateFile = File(
      '$outputDir/presentation/pages/todo/todo_state.dart',
    );
    expect(stateFile.existsSync(), isTrue);
    final stateContent = stateFile.readAsStringSync();
    expect(stateContent, contains('final bool isToggling;'));
    expect(stateContent, contains('this.isToggling = false'));
    expect(stateContent, contains('bool? isToggling'));

    // 2. Check Presenter
    final presenterFile = File(
      '$outputDir/presentation/pages/todo/todo_presenter.dart',
    );
    expect(presenterFile.existsSync(), isTrue);
    final presenterContent = presenterFile.readAsStringSync();
    expect(
      presenterContent,
      contains('Future<Result<Todo, AppFailure>> toggleTodo'),
    );

    // 3. Check Controller
    final controllerFile = File(
      '$outputDir/presentation/pages/todo/todo_controller.dart',
    );
    expect(controllerFile.existsSync(), isTrue);
    final controllerContent = controllerFile.readAsStringSync();
    expect(controllerContent, contains('Future<void> toggleTodo'));
    expect(controllerContent, contains('isToggling'));
    expect(controllerContent, contains('_presenter.toggleTodo'));
  });
}
