@Tags(['regression', 'slow'])
library;
// Full-VPC counterpart of the core regression test for issue #302
// (https://github.com/arrrrny/zuraffa/issues/302).
//
// In the pure-Dart core package the controller/presenter generators correctly
// SKIP output for a pure-Dart target (Constitution VII: Engine Purity — see
// `test/regression/issue_302_toggle_param_collision_test.dart` in the core,
// and issues #420 / #431). The `toggleValue` rename behaviour of the generated
// controller + presenter is asserted HERE, against a Flutter-flavoured
// workspace so VPC generation runs (issue #435).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../helpers/vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('issue_302_vpc_output');
    await writeFlutterPubspec(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    '#302 — Barcode (id-less, field `value`): controller + presenter are '
    'generated on a Flutter target and use `toggleValue` for the bool param',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'Barcode',
        fields: const [
          (name: 'value', type: 'String'),
          (name: 'format', type: 'String'),
        ],
      );

      // Same GeneratorConfig shape MakeCommand produces after the resolver
      // resolves `value` as the id field for the id-less Barcode.
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Barcode',
          methods: const ['get', 'update', 'toggle', 'delete'],
          idField: 'value',
          idFieldType: 'String',
          queryField: 'value',
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
        reason: 'Generation failed: ${result.errors.join('; ')}',
      );

      final controllerFile = File(
        '$outputDir/presentation/pages/barcode/barcode_controller.dart',
      );
      expect(
        controllerFile.existsSync(),
        isTrue,
        reason: 'Flutter target must generate the controller',
      );
      final controllerContent = controllerFile.readAsStringSync();
      expect(
        controllerContent,
        contains('toggleValue'),
        reason: 'Controller must rename the toggle bool param to toggleValue',
      );
      expect(controllerContent, contains('Future<void> toggleBarcode'));

      final presenterFile = File(
        '$outputDir/presentation/pages/barcode/barcode_presenter.dart',
      );
      expect(
        presenterFile.existsSync(),
        isTrue,
        reason: 'Flutter target must generate the presenter',
      );
      final presenterContent = presenterFile.readAsStringSync();
      expect(
        presenterContent,
        contains('toggleValue'),
        reason: 'Presenter must rename the toggle bool param to toggleValue',
      );
      expect(
        presenterContent,
        contains('Future<Result<Barcode, AppFailure>> toggleBarcode'),
      );
      // The renamed param must be forwarded into ToggleParams.value.
      expect(
        presenterContent,
        contains('value: toggleValue'),
        reason: 'Presenter must forward toggleValue into ToggleParams.value',
      );
    },
  );

  test(
    '#302 — REGRESSION: canonical Todo (id=`id`) still uses `toggleValue` — '
    'no behavioural break',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeEntityStub(workspace, name: 'Todo');

      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'Todo',
          methods: const ['get', 'update', 'toggle'],
          idField: 'id',
          idFieldType: 'String',
          queryField: 'id',
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
        reason: 'Generation failed: ${result.errors.join('; ')}',
      );

      final controllerFile = File(
        '$outputDir/presentation/pages/todo/todo_controller.dart',
      );
      expect(controllerFile.existsSync(), isTrue);
      final controllerContent = controllerFile.readAsStringSync();
      expect(controllerContent, contains('toggleValue'));
      expect(controllerContent, contains('Future<void> toggleTodo'));
      expect(controllerContent, contains('isToggling'));
      expect(controllerContent, contains('_presenter.toggleTodo'));

      final presenterFile = File(
        '$outputDir/presentation/pages/todo/todo_presenter.dart',
      );
      expect(presenterFile.existsSync(), isTrue);
      final presenterContent = presenterFile.readAsStringSync();
      expect(presenterContent, contains('toggleValue'));
      expect(
        presenterContent,
        contains('Future<Result<Todo, AppFailure>> toggleTodo'),
      );
      expect(presenterContent, contains('value: toggleValue'));
    },
  );
}
