// Transported from the pure-Dart `zuraffa` core package (issue #431).
//
// Regression coverage for issue #294, Gap 1 — the VPC side. Generators used to
// hardcode `EntityFields.id` regardless of the entity's actual fields,
// breaking entities like `StorePrice` whose id field is `depotId`. The
// presenter generated for such an entity must reference
// `StorePriceFields.depotId`, NOT `StorePriceFields.id`.
//
// In the core package this scenario ran against a *pure-Dart* fixture, where
// VPC generation is now correctly skipped (Constitution VII: Engine Purity,
// see #420) — so the presenter assertion was transported into THIS package
// where the fixture pubspec declares `flutter:` and the presenter generator
// actually runs. The core keeps the resolver + domain/usecase-test coverage
// and the skip assertions.
//
// See: test/regression/issue_294_entity_without_id_test.dart (core),
// https://github.com/arrrrny/zuraffa/issues/294,
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
    workspace = await createWorkspace('issue_294_vpc_');
    await writeFlutterPubspec(workspace);
    outputDir = workspace.outputDir;
  });

  tearDown(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generated presenter references `StorePriceFields.depotId`, NOT '
    '`StorePriceFields.id`',
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

      // Simulate what MakeCommand.run() does after the resolver resolves
      // `depotId`: feed the resolved name into GeneratorConfig. This is
      // exactly the shape the MakeCommand now produces.
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

      // The presenter IS generated here: the fixture pubspec declares
      // `flutter:` so the presenter generator is not skipped (#420/#431).
      final presenterFile = File(
        path.join(
          outputDir,
          'presentation',
          'pages',
          'store_price',
          'store_price_presenter.dart',
        ),
      );
      expect(
        presenterFile.existsSync(),
        isTrue,
        reason: 'store_price_presenter.dart should be generated for a '
            'Flutter target',
      );
      final presenterContent = presenterFile.readAsStringSync();

      expect(
        presenterContent,
        contains('StorePriceFields.depotId'),
        reason: 'Presenter should reference StorePriceFields.depotId',
      );
      expect(
        presenterContent,
        isNot(contains('StorePriceFields.id')),
        reason: 'Presenter must NOT reference StorePriceFields.id — the '
            'entity has no `id` field, its id-like field is `depotId` (#294)',
      );
    },
  );
}
