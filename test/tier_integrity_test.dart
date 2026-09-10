// Issue #1382 — the epic regression exit criterion (`dart test
// test/regression/`) was a FALSE GREEN: dart_test.yaml excludes `slow`
// by default, so the literal invocation loaded ~12 of the tier's files
// and exited 0 while the majority of the tier never executed.
//
// This fast-tier pin closes the coverage hole permanently: EVERY file in
// `test/regression/` must carry the `regression` tag, so
// `dart test --preset=regression` (the honest invocation) covers 100% of
// the tier. A future regression file missing the tag — invisible to both
// the preset and (when slow-tagged) the literal command — fails this pin
// by construction.
//
// Behaviors:
//   B1 — every regression-tier test file carries the `regression` tag.
//   B2 — dart_test.yaml defines the regression preset (include_tags
//        regression).

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final tierDir = Directory('test/regression');
  final configFile = File('dart_test.yaml');

  final tierFiles = tierDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'))
      .toList();

  test('the regression tier exists and is non-trivial', () {
    expect(
      tierFiles.length,
      greaterThanOrEqualTo(60),
      reason:
          'the epic regression corpus is ~64 files — a sudden drop '
          'means the tier was renamed or excluded en masse',
    );
  });

  test('B1: every regression-tier file carries the regression tag', () async {
    expect(tierFiles, isNotEmpty);
    final untagged = <String>[];
    for (final file in tierFiles) {
      final source = await file.readAsString();
      final hasTag = RegExp('@Tags\\([^)]*regression').hasMatch(source);
      if (!hasTag) untagged.add(file.path);
    }
    expect(
      untagged,
      isEmpty,
      reason:
          'files without the regression tag are invisible to '
          '`dart test --preset=regression` — the #1382 false-green '
          'class: $untagged',
    );
  });

  test('B2: dart_test.yaml defines the regression preset', () {
    final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;
    final presets = doc['presets'] as YamlMap?;
    expect(presets, isNotNull);
    expect((presets!['regression'] as YamlMap?)?['include_tags'], 'regression');
  });
}
