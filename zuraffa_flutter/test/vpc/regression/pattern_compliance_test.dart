@Tags(['regression', 'slow'])
library;
// View-pattern counterpart of the core
// `test/regression/pattern_compliance_test.dart` (which keeps the pure-Dart
// usecase-pattern checks). The generated view output is Flutter-dependent, so
// its pattern compliance is asserted here against a Flutter-flavoured
// workspace (issues #431 / #435).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/vpc_test_utils.dart';

void main() {
  test('views use controlled widget builder and view state', () async {
    final workspace = await createWorkspace('zuraffa_view_patterns_');
    addTearDown(() => disposeWorkspace(workspace));
    await writeFlutterPubspec(workspace);
    await generateFullFeature(workspace, name: 'Product');

    final viewPath =
        '${workspace.outputDir}/presentation/pages/product/product_view.dart';
    final viewContent = File(viewPath).readAsStringSync();
    expect(viewContent.contains('ControlledWidgetBuilder'), isTrue);
    expect(viewContent.contains('viewState'), isTrue);

  });
}
