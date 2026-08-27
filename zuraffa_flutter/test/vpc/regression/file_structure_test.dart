@Tags(['regression', 'slow'])
library;
// Full-layout counterpart of the core `test/regression/file_structure_test.dart`.
// The core keeps only the pure-Dart-relevant layout assertions; the FULL clean
// architecture layout (including the presentation pages trio) is asserted here
// against a Flutter-flavoured workspace so VPC generation runs
// (issues #431 / #435).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/vpc_test_utils.dart';

void main() {
  test('entity generation produces clean architecture layout', () async {
    final workspace = await createWorkspace('zuraffa_structure_');
    addTearDown(() => disposeWorkspace(workspace));
    await writeFlutterPubspec(workspace);
    await generateFullFeature(workspace, name: 'Product');

    final expected = [
      '${workspace.outputDir}/domain/repositories/product_repository.dart',
      '${workspace.outputDir}/domain/usecases/product/get_product_usecase.dart',
      '${workspace.outputDir}/data/datasources/product/product_datasource.dart',
      '${workspace.outputDir}/data/datasources/product/product_remote_datasource.dart',
      '${workspace.outputDir}/data/repositories/data_product_repository.dart',
      '${workspace.outputDir}/presentation/pages/product/product_view.dart',
      '${workspace.outputDir}/presentation/pages/product/product_presenter.dart',
      '${workspace.outputDir}/presentation/pages/product/product_controller.dart',
      '${workspace.outputDir}/presentation/pages/product/product_state.dart',
      '${workspace.outputDir}/di/repositories/product_repository_di.dart',
      '${workspace.outputDir}/di/datasources/product_remote_datasource_di.dart',
    ];

    for (final path in expected) {
      expect(File(path).existsSync(), isTrue, reason: 'missing: $path');
    }

  });
}
