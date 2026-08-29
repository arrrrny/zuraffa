// Tests for the DartTestYamlWriter (spec 041-tdd-setup-plugin, U12-U13).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/dart_test_yaml_writer.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('dart_test_yaml_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('writes a parseable dart_test.yaml', () async {
    final writer = const DartTestYamlWriter();
    final path = await writer.write(tmpDir.path);
    expect(path, isNotNull);
    final file = File(p.join(tmpDir.path, 'dart_test.yaml'));
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    final doc = loadYaml(content);
    expect(doc, isA<YamlMap>());
    expect(doc['color'], isTrue);
    expect(doc['concurrency'], 4);
  });

  test('is idempotent — does not clobber an existing file', () async {
    final writer = const DartTestYamlWriter();
    await writer.write(tmpDir.path);
    final file = File(p.join(tmpDir.path, 'dart_test.yaml'));
    await file.writeAsString('# User-edited\n');
    final result = await writer.write(tmpDir.path);
    expect(result, isNull, reason: 'should not overwrite existing file');
    expect(file.readAsStringSync(), '# User-edited\n');
  });
}
