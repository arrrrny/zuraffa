// Plugin-level regression lock for issue #302.
//
// `zfa make`'s toggle method generator declared three positional parameters:
//   1. `<idType> <config.idField>`  (the id)
//   2. `Field<Entity, dynamic> field`  (the field to toggle)
//   3. `bool value`  (the new toggle value)
//
// The third parameter was hardcoded to the name `value`. When the entity has a
// field literally named `value` (e.g. `Barcode: String get value`), the id
// parameter resolved to `String value` and collided with the toggle-value
// parameter `bool value` → `duplicate_definition`.
//
// The fix renames the toggle-value parameter to the reserved name `toggleValue`,
// so it can never collide with `config.idField`, `field`, or `cancelToken`.
//
// This test drives the presenter and controller plugins directly (no `zfa make`
// / flutter subprocess) and asserts the generated toggle method uses
// `bool toggleValue` and forwards it into `ToggleParams.value`, with no
// duplicate `value` parameter — even when the entity's id field is `value`.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_302_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('#302 — toggle-value param rename (entity field named `value`)', () {
    test('presenter toggle uses `toggleValue`, no `value` collision', () async {
      final plugin = PresenterPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final config = GeneratorConfig(
        name: 'Barcode',
        methods: const ['get', 'update', 'toggle'],
        idField: 'value',
        idFieldType: 'String',
        queryField: 'value',
        generatePresenter: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // The id parameter is named after the entity's id field (`value`).
      expect(
        content,
        contains('String value,'),
        reason:
            'id parameter must be named after the resolved id field (value)',
      );
      // The toggle-value parameter is the fixed reserved name `toggleValue`.
      expect(
        content,
        contains('bool toggleValue'),
        reason: '#302: toggle value param must be `toggleValue`, not `value`',
      );
      // No duplicate `bool value` parameter (the original collision).
      expect(
        content,
        isNot(contains('bool value')),
        reason: '#302: must NOT have a duplicate `bool value` parameter',
      );
      // The bool is forwarded into ToggleParams.value (named field, not param).
      expect(
        content,
        contains(
          'ToggleParams<String, Field<Barcode, dynamic>>(\n'
          '        id: value,\n'
          '        field: field,\n'
          '        value: toggleValue,',
        ),
        reason: '#302: toggleValue must be forwarded into ToggleParams.value',
      );
    });

    test(
      'controller toggle uses `toggleValue`, no `value` collision',
      () async {
        final plugin = ControllerPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Barcode',
          methods: const ['get', 'update', 'toggle'],
          idField: 'value',
          idFieldType: 'String',
          queryField: 'value',
          generateController: true,
          outputDir: outputDir,
        );

        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        expect(
          content,
          contains('String value,'),
          reason:
              'id parameter must be named after the resolved id field (value)',
        );
        expect(
          content,
          contains('bool toggleValue'),
          reason: '#302: toggle value param must be `toggleValue`, not `value`',
        );
        expect(
          content,
          isNot(contains('bool value')),
          reason: '#302: must NOT have a duplicate `bool value` parameter',
        );
      },
    );

    test(
      'canonical id field still uses `toggleValue` (no behavioural break)',
      () async {
        final plugin = PresenterPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final config = GeneratorConfig(
          name: 'Todo',
          methods: const ['toggle'],
          idField: 'id',
          idFieldType: 'String',
          queryField: 'id',
          generatePresenter: true,
          outputDir: outputDir,
        );

        final files = await plugin.generate(config);
        final content = files.first.content ?? '';

        expect(content, contains('bool toggleValue'));
        expect(
          content,
          isNot(contains('bool value')),
          reason: 'canonical id-field case must also use toggleValue',
        );
      },
    );
  });
}
