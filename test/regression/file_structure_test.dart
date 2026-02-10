import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'regression_test_utils.dart';

void main() {
  test('entity generation produces clean architecture layout', () async {
    final workspace = await createWorkspace('zuraffa_structure_');
    await generateFullFeature(workspace, name: 'Product');

    final expected = [
      '${workspace.outputDir}/domain/repositories/product_repository.dart',
      '${workspace.outputDir}/domain/usecases/product/get_product_usecase.dart',
      '${workspace.outputDir}/data/data_sources/product/product_data_source.dart',
      '${workspace.outputDir}/data/data_sources/product/product_remote_data_source.dart',
      '${workspace.outputDir}/data/repositories/data_product_repository.dart',
      '${workspace.outputDir}/presentation/pages/product/product_view.dart',
      '${workspace.outputDir}/presentation/pages/product/product_presenter.dart',
      '${workspace.outputDir}/presentation/pages/product/product_controller.dart',
      '${workspace.outputDir}/presentation/pages/product/product_state.dart',
      '${workspace.outputDir}/di/repositories/product_repository_di.dart',
      '${workspace.outputDir}/di/datasources/product_remote_data_source_di.dart',
    ];

    for (final path in expected) {
      expect(File(path).existsSync(), isTrue);
    }

    await disposeWorkspace(workspace);
  });
}
