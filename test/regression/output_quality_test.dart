import 'package:flutter_test/flutter_test.dart';

import 'regression_test_utils.dart';

void main() {
  late RegressionWorkspace workspace;
  late List<String> generatedPaths;

  setUpAll(() async {
    workspace = await createWorkspace('zuraffa_output_quality_');
    await writePubspec(workspace);
    final pubGet = await runFlutterPubGet(workspace);
    expect(pubGet.exitCode, equals(0), reason: pubGet.stderr.toString());
    final result = await generateFullFeature(workspace);
    await writeEntityStub(workspace, name: 'Product');
    await writeMainStub(workspace);
    generatedPaths = result.files
        .map((f) => f.path)
        .where((path) => !path.endsWith('_state.dart'))
        .toList();
  });

  tearDownAll(() async {
    await disposeWorkspace(workspace);
  });

  test(
    'generated output passes dart analyze',
    () async {
      final analyze = await runDartAnalyzePaths(workspace, generatedPaths);
      expect(analyze.exitCode, equals(0), reason: analyze.stdout.toString());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'generated output is properly formatted',
    () async {
      final format = await runDartFormatCheckPaths(workspace, generatedPaths);
      expect(format.exitCode, equals(0), reason: format.stdout.toString());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
