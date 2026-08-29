// Tests for the SmokeTestWriter (spec 041-tdd-setup-plugin, U14-U15).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/smoke_test_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('smoke_test_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test(
    'writes test/bootstrap_smoke_test.dart referencing the package',
    () async {
      final writer = const SmokeTestWriter();
      final path = await writer.write(tmpDir.path, 'myapp');
      expect(path, isNotNull);
      final file = File(p.join(tmpDir.path, 'test/bootstrap_smoke_test.dart'));
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('package:myapp/app.dart'));
      expect(content, contains('AppContainer'));
      expect(content, contains('isNotNull'));
    },
  );

  test('is idempotent — does not overwrite an existing smoke test', () async {
    final writer = const SmokeTestWriter();
    await writer.write(tmpDir.path, 'myapp');
    final file = File(p.join(tmpDir.path, 'test/bootstrap_smoke_test.dart'));
    await file.writeAsString('// Custom user test\n');
    final result = await writer.write(tmpDir.path, 'myapp');
    expect(
      result,
      isNull,
      reason: 'should not overwrite existing user content',
    );
    expect(file.readAsStringSync(), '// Custom user test\n');
  });
}
