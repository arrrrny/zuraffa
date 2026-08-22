@Tags(['regression', 'slow'])
// Regression tests for issue #302.
//
// `zfa make`'s toggle method generator (controller + presenter) declared
// three positional parameters:
//
//   1. `<idType> <config.idField>`  (the id)
//   2. `Field<Entity, dynamic> field`  (the field to toggle)
//   3. `bool value`  (the new toggle value)
//
// The third parameter was hardcoded to the name `value`. When the entity
// has a field literally named `value` (Barcode: `String get value;
// BarcodeFormat get format;`), `EntityFieldResolver.resolveIdField`
// resolves the id field to `value` (no `id`/`*Id` field → first declared
// field). That made the id parameter `String value` collide with the
// toggle-value parameter `bool value`:
//
//   Future<void> toggleBarcode(
//     String value,                       // <-- id param named `value`
//     Field<Barcode, dynamic> field,
//     bool value, [                       // <-- toggle-value param ALSO `value`
//     CancelToken? cancelToken,
//   ]) ...
//
// → `duplicate_definition` (two `value` params) and
//   `argument_type_not_assignable` (the String `value` shadows the bool
//   `value` when forwarded to `_presenter.toggleBarcode(...)` and
//   `ToggleParams(...)`).
//
// The fix renames the toggle-value parameter to `toggleValue` (a fixed
// reserved name that can never collide with `config.idField`, `field`, or
// `cancelToken` regardless of the entity's field names). The
// `ToggleParams` constructor's `value:` named field is unaffected — it
// is a class field name, not a parameter name — so the params object is
// still constructed as `ToggleParams(id: ..., field: ..., value: ...)`.
//
// These tests:
//   - Reproduce the Barcode scenario from the issue (entity with a field
//     literally named `value`, no `id`/`*Id` field).
//   - Assert the generated controller + presenter use `toggleValue` for
//     the bool param and forward `toggleValue` into `ToggleParams.value`.
//   - Assert no `duplicate_definition` exists in the generated code.
//   - Re-test the canonical `Todo` (id=`id`) case to lock in that the
//     rename doesn't break the standard id-field scenario.

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/utils/entity_field_resolver.dart';

import 'regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late String outputDir;

  setUp(() async {
    workspace = await createWorkspace('issue_302_toggle_param_collision');
    await writePubspec(workspace);
    await runFlutterPubGet(workspace);
    outputDir = workspace.outputDir;
  });

  group('#302 — toggle param name collision when entity field is `value`', () {
    test('#307 contract — an id-less Barcode resolves no id (no silent '
        'first-field fallback to `value`)', () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'Barcode',
        fields: const [
          (name: 'value', type: 'String'),
          (name: 'format', type: 'String'),
        ],
      );

      final resolved = EntityFieldResolver.resolveIdField(
        entityName: 'Barcode',
        projectRoot: workspace.directory.path,
      );

      expect(
        resolved,
        isNotNull,
        reason:
            'Resolver should resolve the id-less Barcode contract without '
            'silently falling back to the first field',
      );
      // #307: no `id` / `*Id` / `autoId` → id-less entity (zfa make fails
      // loudly). The `value`-as-id toggle-collision scenario (#302) now
      // requires an explicit `--id-field=value` on `zfa make`.
      expect(resolved!.kind, EntitySourceKind.entity);
      expect(resolved.autoId, isFalse);
      expect(resolved.idField, isNull);
      expect(resolved.hasId, isFalse);
    });

    test('generated controller + presenter use `toggleValue` for the bool param '
        'and forward it into ToggleParams (no duplicate `value`)', () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'Barcode',
        fields: const [
          (name: 'value', type: 'String'),
          (name: 'format', type: 'String'),
        ],
      );

      // Simulate what MakeCommand.run() does after the resolver resolves
      // `value` as the id field for Barcode.
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
        reason: 'barcode_controller.dart should be generated',
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
            'after the entity\'s id field (`value` for Barcode)',
      );
      // Negative: NO duplicate `bool value` declaration.
      expect(
        controllerSrc,
        isNot(contains('bool value,')),
        reason:
            'Controller toggleBarcode must NOT declare `bool value` — '
            'it collides with the id parameter `String value`',
      );
      // Negative: NO duplicate_definition smoke check — the literal
      // substring `String value,\n  Field<Barcode, dynamic> field,\n  bool value`
      // is the exact pattern that triggered #302.
      expect(
        controllerSrc,
        isNot(contains('bool value,')),
        reason: 'Controller must not contain `bool value,` anywhere',
      );
      // Positive: forwards `toggleValue` (not `value`) to the presenter.
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
        reason: 'barcode_presenter.dart should be generated',
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
    });

    test('REGRESSION: canonical Todo (id=`id`) case still uses `toggleValue` '
        'for the bool param — no behavioural break', () async {
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
      expect(controllerFile.existsSync(), isTrue);
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
      expect(presenterFile.existsSync(), isTrue);
      final presenterSrc = presenterFile.readAsStringSync();

      expect(presenterSrc, contains('bool toggleValue'));
      expect(presenterSrc, contains('value: toggleValue'));
      expect(presenterSrc, isNot(contains('bool value,')));
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Writes an entity file WITHOUT an `id` field — mimics what
/// `zfa entity create -n X --field value:String` produces (a Zorphy
/// abstract class with `Type get fieldName;` getters). Also writes a
/// matching `<Name>Fields` class so the generated code can reference
/// `<Name>Fields.<fieldName>` constants.
///
/// Mirrors the helper in `issue_294_entity_without_id_test.dart` — kept
/// local to this test so #294 and #302 can evolve independently if their
/// entity-stub needs ever diverge.
Future<void> writeEntityStubWithoutId(
  RegressionWorkspace workspace, {
  required String name,
  required List<({String name, String type})> fields,
}) async {
  final entitySnake = _toSnake(name);
  final entityDir = Directory(
    path.join(workspace.outputDir, 'domain', 'entities', entitySnake),
  );
  await entityDir.create(recursive: true);
  final entityFile = File(path.join(entityDir.path, '$entitySnake.dart'));

  final buffer = StringBuffer()
    ..writeln('// Auto-generated entity stub for regression test (#302).')
    ..writeln()
    ..writeln('abstract class \$$name {');

  for (final f in fields) {
    buffer.writeln('  ${f.type} get ${f.name};');
  }
  buffer
    ..writeln('}')
    ..writeln();

  // Stub `<Name>Fields` class with Field constants for each declared field.
  // The mock datasource / presenter / test generators reference these.
  buffer.writeln('abstract final class ${name}Fields {');
  for (final f in fields) {
    buffer.writeln(
      "  static const Field<$name, ${f.type}> ${f.name} = "
      "Field<$name, ${f.type}>(name: '${f.name}');",
    );
  }
  buffer.writeln('}');

  await entityFile.writeAsString(buffer.toString());
}

String _toSnake(String input) {
  final result = <String>[];
  for (var i = 0; i < input.length; i += 1) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char && char != '_') {
      result.add('_');
    }
    result.add(char.toLowerCase());
  }
  return result.join();
}
