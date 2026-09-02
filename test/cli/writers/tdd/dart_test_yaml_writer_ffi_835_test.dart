// Bug #835 (tdd-ffi-ocr-harness): the generated dart_test.yaml carries
// the tier structure that makes the marked integration lane REAL in
// fresh consuming projects — `slow`/`integration` tags declared (no
// unspecified-tag warnings), the slow tier excluded from the default
// run, and an `integration` preset that re-includes it. The lane gate
// command is therefore `dart test --preset=integration`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/cli/writers/tdd/dart_test_yaml_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('dart_test_yaml_835_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('declares the slow + integration tags (the golden lane tags)', () async {
    await const DartTestYamlWriter().write(tmpDir.path);
    final doc =
        loadYaml(File(p.join(tmpDir.path, 'dart_test.yaml')).readAsStringSync())
            as YamlMap;
    expect((doc['tags'] as YamlMap).keys, containsAll(['slow', 'integration']));
  });

  test('excludes the slow tier from the default run', () async {
    await const DartTestYamlWriter().write(tmpDir.path);
    final doc =
        loadYaml(File(p.join(tmpDir.path, 'dart_test.yaml')).readAsStringSync())
            as YamlMap;
    expect(
      doc['exclude_tags'],
      'slow',
      reason: 'the golden fixture lane must not run in the default tier',
    );
  });

  test('provides the integration preset that re-includes the lane', () async {
    await const DartTestYamlWriter().write(tmpDir.path);
    final doc =
        loadYaml(File(p.join(tmpDir.path, 'dart_test.yaml')).readAsStringSync())
            as YamlMap;
    final integration = (doc['presets'] as YamlMap)['integration'] as YamlMap;
    expect(integration['include_tags'], 'integration');
    expect(
      integration['exclude_tags'],
      'false',
      reason:
          'the preset overrides the default slow exclusion '
          '(the same shape the zuraffa repo itself uses)',
    );
  });

  test('the base runner config is unchanged (color/concurrency)', () async {
    await const DartTestYamlWriter().write(tmpDir.path);
    final doc =
        loadYaml(File(p.join(tmpDir.path, 'dart_test.yaml')).readAsStringSync())
            as YamlMap;
    expect(doc['color'], isTrue);
    expect(doc['concurrency'], 4);
  });
}
