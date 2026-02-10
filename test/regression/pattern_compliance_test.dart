import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'regression_test_utils.dart';

void main() {
  test('usecases include cancel token handling', () async {
    final workspace = await createWorkspace('zuraffa_patterns_');
    await generateFullFeature(workspace, name: 'Product');

    final usecasePath =
        '${workspace.outputDir}/domain/usecases/product/get_product_usecase.dart';
    final usecaseContent = File(usecasePath).readAsStringSync();
    expect(usecaseContent.contains('extends UseCase<Product'), isTrue);
    expect(usecaseContent.contains('CancelToken? cancelToken'), isTrue);
    expect(usecaseContent.contains('cancelToken?.throwIfCancelled()'), isTrue);

    await disposeWorkspace(workspace);
  });

  test('views use controlled widget builder and view state', () async {
    final workspace = await createWorkspace('zuraffa_view_patterns_');
    await generateFullFeature(workspace, name: 'Product');

    final viewPath =
        '${workspace.outputDir}/presentation/pages/product/product_view.dart';
    final viewContent = File(viewPath).readAsStringSync();
    expect(viewContent.contains('ControlledWidgetBuilder'), isTrue);
    expect(viewContent.contains('viewState'), isTrue);

    await disposeWorkspace(workspace);
  });
}
