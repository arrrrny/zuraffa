import 'package:test/test.dart';

import 'regression_test_utils.dart';

import 'dart:io';

/// CWD-safe project root by searching for zuraffa's pubspec.yaml.
String _findProjectRoot() {
  // Try Platform.script first (reliable in dart test's VM runner).
  final scriptPath = Platform.script.toFilePath();
  if (!scriptPath.contains('.dart_tool')) {
    var dir = File(scriptPath).parent;
    for (var i = 0; i < 5; i++) {
      final ps = File('${dir.path}/pubspec.yaml');
      if (ps.existsSync()) {
        final content = ps.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(content)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }
  // Fallback: search upward from CWD.
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final ps = File('${dir.path}/pubspec.yaml');
    if (ps.existsSync()) {
      final content = ps.readAsStringSync();
      if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(content)) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current.path;
}

void main() {
  // Resolve eagerly before any test can change CWD.
  final zfaRoot = _findProjectRoot();

  late RegressionWorkspace workspace;
  late List<String> generatedPaths;

  setUpAll(() async {
    workspace = await createWorkspace('zuraffa_output_quality_');
    await writePubspec(workspace, repoRoot: zfaRoot);
    final pubGet = await runFlutterPubGet(workspace);
    expect(pubGet.exitCode, equals(0), reason: pubGet.stderr.toString());
    await writeEntityStub(workspace, name: 'Product');
    final result = await generateFullFeature(workspace);
    await writeMainStub(workspace);
    generatedPaths = result.files
        .map((f) => f.path)
        .where((path) => !path.endsWith('_state.dart'))
        // After the package split, presentation-layer files depend on
        // zuraffa_flutter and cannot be analyzed in a pure-Dart workspace.
        .where((path) => !path.contains('/presentation/'))
        .where((path) => !path.contains('/routing/'))
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
      // Run dart format (without --set-exit-if-changed) to verify
      // the generated code is valid and formattable.
      final format = await Process.run(
        'dart', ['format', ...generatedPaths],
        workingDirectory: workspace.directory.path,
      );
      expect(format.exitCode, equals(0), reason: format.stderr.toString());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
