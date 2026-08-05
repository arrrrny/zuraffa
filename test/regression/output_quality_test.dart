import 'dart:io';

import 'package:test/test.dart';

import 'regression_test_utils.dart';

/// CWD-safe project root resolution.
String _findProjectRoot() {
  // Strategy 1: Walk up from Platform.script.
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}
  // Strategy 2: Walk up from CWD (fallback).
  try {
    var dir = Directory.current;
    for (var i = 0; i < 15; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}
  return Directory.current.path;
}

void main() {
  final zfaRoot = _findProjectRoot();

  late RegressionWorkspace workspace;
  late List<String> generatedPaths;

  setUpAll(() async {
    workspace = await createWorkspace('zuraffa_output_quality_');
    await writePubspec(workspace, repoRootOverride: zfaRoot);
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
      // Run dart format in check mode to verify formatting without modifying files.
      final format = await Process.run(
        'dart',
        ['format', '--output=none', '--set-exit-if-changed', ...generatedPaths],
        workingDirectory: workspace.directory.path,
      );
      expect(
        format.exitCode,
        equals(0),
        reason: 'Generated files are not properly formatted:\n${format.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
