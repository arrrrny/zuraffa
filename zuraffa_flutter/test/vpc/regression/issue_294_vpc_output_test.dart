@Tags(['regression', 'slow'])
library;
// Full-VPC counterpart of the core regression test for issue #294
// (https://github.com/arrrrny/zuraffa/issues/294).
//
// In the pure-Dart core package the presenter/controller generators correctly
// SKIP output for a pure-Dart target (Constitution VII: Engine Purity — see
// `test/regression/issue_294_entity_without_id_test.dart` in the core, and
// issues #420 / #431). The id-resolution BEHAVIOUR of the generated presenter
// is asserted HERE, in zuraffa_flutter, against a Flutter-flavoured workspace
// so VPC generation runs (issue #435).
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
    workspace = await createWorkspace('issue_294_vpc_output');
    await writeFlutterPubspec(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    '#294 — generated presenter references `StorePriceFields.depotId`, '
    'NOT `StorePriceFields.id` (Flutter target)',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'StorePrice',
        fields: const [
          (name: 'depotId', type: 'String'),
          (name: 'storeName', type: 'String'),
          (name: 'price', type: 'double'),
        ],
      );

      // Same GeneratorConfig shape MakeCommand produces after the
      // EntityFieldResolver resolves `depotId` for the id-less StorePrice.
      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'StorePrice',
          methods: const ['get', 'update', 'toggle'],
          idField: 'depotId',
          idFieldType: 'String',
          queryField: 'depotId',
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

      // The presenter IS generated for a Flutter target...
      final presenterFile = File(
        '$outputDir/presentation/pages/store_price/store_price_presenter.dart',
      );
      expect(
        presenterFile.existsSync(),
        isTrue,
        reason: 'Flutter target must generate the presenter',
      );
      final presenterContent = presenterFile.readAsStringSync();

      // ...and it must reference the RESOLVED id field, never a hardcoded id.
      expect(
        presenterContent,
        contains('StorePriceFields.depotId'),
        reason: 'Presenter should reference StorePriceFields.depotId',
      );
      expect(
        presenterContent,
        isNot(contains('StorePriceFields.id')),
        reason: 'Presenter should NOT reference StorePriceFields.id',
      );

      // The controller is generated alongside the presenter.
      final controllerFile = File(
        '$outputDir/presentation/pages/store_price/store_price_controller.dart',
      );
      expect(
        controllerFile.existsSync(),
        isTrue,
        reason: 'Flutter target must generate the controller',
      );

      // And the view (the VPC trio is complete on a Flutter target).
      final viewFile = File(
        '$outputDir/presentation/pages/store_price/store_price_view.dart',
      );
      expect(
        viewFile.existsSync(),
        isTrue,
        reason: 'Flutter target must generate the view',
      );
    },
  );

  test(
    '#294 — presenter uses the first `*Id` field when multiple exist '
    '(GroceryPriceResult: storeId + itemName — storeId wins)',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeEntityStubWithoutId(
        workspace,
        name: 'GroceryPriceResult',
        fields: const [
          (name: 'storeId', type: 'String'),
          (name: 'itemName', type: 'String'),
          (name: 'price', type: 'double'),
        ],
      );

      final generator = CodeGenerator(
        config: GeneratorConfig(
          name: 'GroceryPriceResult',
          methods: const ['get', 'update'],
          idField: 'storeId',
          idFieldType: 'String',
          queryField: 'storeId',
          generateData: true,
          generateUseCase: true,
          generateVpcs: true,
          generateState: true,
          generateDi: true,
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

      final presenterFile = File(
        '$outputDir/presentation/pages/grocery_price_result/'
        'grocery_price_result_presenter.dart',
      );
      expect(presenterFile.existsSync(), isTrue);
      final presenterContent = presenterFile.readAsStringSync();
      expect(presenterContent, contains('GroceryPriceResultFields.storeId'));
      expect(presenterContent, isNot(contains('GroceryPriceResultFields.id')));
    },
  );
}
