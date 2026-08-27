// Plugin-level regression lock for issue #294 (Gap 1).
//
// The presenter/toggle/get generators used to hardcode `EntityFields.id`
// regardless of the entity's actual fields, breaking entities whose id-like
// field is named differently (e.g. `StorePrice.depotId`,
// `GroceryPriceResult.storeId`, ...). The fix reads the MakeCommand-resolved
// id field name from `GeneratorConfig.idField` / `queryField` and uses it in
// the generated method signatures and `UpdateParams`/`ToggleParams`/`QueryParams`
// expressions instead of the literal `id`.
//
// This test drives the presenter plugin directly (no `zfa make` / flutter
// subprocess) and asserts the generated presenter references the resolved field
// name, never a hardcoded `id`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/vpc_test_utils.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_294_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    // Declare a Flutter pubspec so the VPC generators run on their
    // intended target instead of relying on the no-pubspec
    // (unknown flavour) fallback — issues #431 / #435.
    await writeFlutterPubspecAt(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'presenter uses the resolved id field (depotId), not hardcoded `id`',
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
        name: 'StorePrice',
        methods: const ['get', 'update', 'toggle'],
        idField: 'depotId',
        idFieldType: 'String',
        queryField: 'depotId',
        generatePresenter: true,
        outputDir: outputDir,
      );

      final files = await plugin.generate(config);
      final content = files.first.content ?? '';

      // The id parameter is named after the resolved field.
      expect(
        content,
        contains('String depotId'),
        reason: 'toggle/get/update id parameter must use the resolved depotId',
      );
      // The query filter references the resolved field constant.
      expect(
        content,
        contains('StorePriceFields.depotId'),
        reason: 'get query filter must reference StorePriceFields.depotId',
      );
      // UpdateParams / ToggleParams ids use the resolved field.
      expect(
        content,
        contains('UpdateParams<String, StorePricePatch>(id: depotId'),
        reason: 'UpdateParams.id must be the resolved depotId',
      );
      expect(
        content,
        contains(
          'ToggleParams<String, Field<StorePrice, dynamic>>(\n'
          '        id: depotId,',
        ),
        reason: 'ToggleParams.id must be the resolved depotId',
      );
      // Negative: the hardcoded `id` must not appear as a field reference.
      expect(
        content,
        isNot(contains('StorePriceFields.id')),
        reason: 'presenter must NOT reference a hardcoded StorePriceFields.id',
      );
      expect(
        content,
        isNot(contains('String id,')),
        reason: 'presenter must NOT declare a hardcoded `id` id-parameter',
      );
    },
  );
}
