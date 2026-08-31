@Tags(['regression', 'slow'])
library;

import 'dart:io';

import 'package:test/test.dart';

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

  // The view-pattern compliance check ('views use controlled widget builder
  // and view state') moved to
  // zuraffa_flutter/test/vpc/regression/pattern_compliance_test.dart —
  // pure-Dart targets skip VPC generation (issues #431 / #435).
}
