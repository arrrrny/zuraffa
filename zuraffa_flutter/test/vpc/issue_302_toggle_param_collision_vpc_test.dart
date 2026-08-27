// Transported from the pure-Dart `zuraffa` core package (issue #431).
//
// Regression coverage for issue #302 — the VPC side. The toggle method
// generator (controller + presenter) used to hardcode the toggle-value
// parameter name as `value`. When the entity's id field is literally named
// `value` (Barcode: `String get value;`), the id parameter `String value`
// collided with the toggle-value parameter `bool value`:
//
//   Future<void> toggleBarcode(
//     String value,                        // <-- id param named `value`
//     Field<Barcode, dynamic> field,
//     bool value, [                        // <-- toggle-value param ALSO `value`
//     CancelToken? cancelToken,
//   ]) ...
//
// → `duplicate_definition` + `argument_type_not_assignable`.
//
// The fix renames the toggle-value parameter to `toggleValue` (a reserved
// name that can never collide with the id field, `field`, or `cancelToken`).
// `ToggleParams`'s `value:` named field is unaffected (class field, not a
// parameter), so the params object is still constructed as
// `ToggleParams(id: ..., field: ..., value: toggleValue)`.
//
// In the core package this scenario ran against a *pure-Dart* fixture, where
// VPC generation is now correctly skipped (Constitution VII: Engine Purity,
// see #420) — so the controller/presenter assertions were transported into
// THIS package where the fixture pubspec declares `flutter:` and the VPC
// generators actually run.
//
// See: test/regression/issue_302_toggle_param_collision_test.dart (core),
// https://github.com/arrrrny/zuraffa/issues/302,
// https://github.com/arrrrny/zuraffa/issues/431.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import 'vpc_test_utils.dart';

void main() {
  late VpcWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('issue_302_vpc_');
    await writeFlutterPubspec(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  group('#302 — toggle param name collision when entity field is `value`', () {
    test(
      'generated controller + presenter use `toggleValue` for the bool param '
      'and forward it into ToggleParams (no duplicate `value`)',
      () async {
        await writeEntityStubWithoutId(
          workspace,
          name: 'Barcode',
          fields: const [
            (name: 'value', type: 'String'),
            (name: 'format', type: 'String'),
          ],
        );

        // Simulate what MakeCommand.run() does when the user passes
        // `--id-field=value` for the id-less Barcode (#307 contract).
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

        // ---- Controller ----
        final controllerFile = File(
          path.join(
            outputDir,
            'presentation',
            'pages',
            'barcode',
            'barcode_controller.dart',
          ),
        );
        expect(
          controllerFile.existsSync(),
          isTrue,
          reason: 'barcode_controller.dart should be generated for a '
              'Flutter target',
        );
        final controllerSrc = controllerFile.readAsStringSync();

        // Positive: toggle method uses `toggleValue` for the bool param.
        expect(
          controllerSrc,
          contains('bool toggleValue'),
          reason:
              'Controller toggleBarcode must name the bool toggle-value '
              'parameter `toggleValue`, not `value`',
        );
        // Positive: the id parameter keeps the entity's id-field name (`value`).
        expect(
          controllerSrc,
          contains('String value,'),
          reason:
              'Controller toggleBarcode must keep the id parameter named '
              "after the entity's id field (`value` for Barcode)",
        );
        // Negative: NO duplicate `bool value` declaration — the literal
        // pattern `String value,\n  Field<Barcode, dynamic> field,\n  bool value`
        // is what triggered #302.
        expect(
          controllerSrc,
          isNot(contains('bool value,')),
          reason:
              'Controller toggleBarcode must NOT declare `bool value` — '
              'it collides with the id parameter `String value`',
        );
        // Positive: forwards to the presenter.
        expect(
          controllerSrc,
          contains('_presenter.toggleBarcode('),
          reason: 'Controller should forward to _presenter.toggleBarcode',
        );
        // The forward call args come from `_callArgsExpressions('<idField>, '
        // 'field, toggleValue')` — verify the resolved arg string.
        expect(
          controllerSrc,
          contains('toggleValue'),
          reason: 'Controller body should reference `toggleValue`',
        );

        // ---- Presenter ----
        final presenterFile = File(
          path.join(
            outputDir,
            'presentation',
            'pages',
            'barcode',
            'barcode_presenter.dart',
          ),
        );
        expect(
          presenterFile.existsSync(),
          isTrue,
          reason: 'barcode_presenter.dart should be generated for a '
              'Flutter target',
        );
        final presenterSrc = presenterFile.readAsStringSync();

        // Positive: presenter uses `toggleValue` for the bool param.
        expect(
          presenterSrc,
          contains('bool toggleValue'),
          reason:
              'Presenter toggleBarcode must name the bool toggle-value '
              'parameter `toggleValue`, not `value`',
        );
        // Negative: NO `bool value` declaration.
        expect(
          presenterSrc,
          isNot(contains('bool value,')),
          reason: 'Presenter toggleBarcode must NOT declare `bool value`',
        );
        // Positive: `ToggleParams` constructor still uses the `value:` named
        // field (it's a class field name, not a parameter name), but it
        // receives `toggleValue` as the value.
        expect(
          presenterSrc,
          contains('value: toggleValue'),
          reason: 'Presenter must forward `toggleValue` into ToggleParams.value',
        );
        // Positive: `id:` still receives the id param (`value` for Barcode).
        expect(
          presenterSrc,
          contains('id: value,'),
          reason:
              'Presenter must forward the id parameter (`value`) into '
              'ToggleParams.id',
        );
      },
    );

    test(
      'REGRESSION: canonical Todo (id=`id`) case still uses `toggleValue` '
      'for the bool param — no behavioural break',
      () async {
        // Use the standard writeEntityStub helper (writes an entity WITH an
        // `id` field) to confirm the rename doesn't break the canonical
        // id-field scenario.
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
          path.join(
            outputDir,
            'presentation',
            'pages',
            'todo',
            'todo_controller.dart',
          ),
        );
        expect(
          controllerFile.existsSync(),
          isTrue,
          reason: 'todo_controller.dart should be generated for a Flutter '
              'target',
        );
        final controllerSrc = controllerFile.readAsStringSync();

        // The canonical case: id param `String id`, field param
        // `Field<Todo, dynamic> field`, toggle-value param `bool toggleValue`.
        expect(controllerSrc, contains('String id,'));
        expect(controllerSrc, contains('bool toggleValue'));
        expect(controllerSrc, isNot(contains('bool value,')));

        final presenterFile = File(
          path.join(
            outputDir,
            'presentation',
            'pages',
            'todo',
            'todo_presenter.dart',
          ),
        );
        expect(
          presenterFile.existsSync(),
          isTrue,
          reason: 'todo_presenter.dart should be generated for a Flutter '
              'target',
        );
        final presenterSrc = presenterFile.readAsStringSync();

        expect(presenterSrc, contains('bool toggleValue'));
        expect(presenterSrc, contains('value: toggleValue'));
        expect(presenterSrc, isNot(contains('bool value,')));
      },
    );
  });
}
