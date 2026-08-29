// Tests for the TddExampleWriter (spec 041-tdd-setup-plugin, U19).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/tdd_example_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tdd_example_writer_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('writes a test that asserts non-null greeting', () async {
    final writer = const TddExampleWriter();
    final path = await writer.write(tmpDir.path, 'myapp');
    expect(path, isNotNull);
    final file = File(p.join(tmpDir.path, 'test/tdd_example_test.dart'));
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('package:myapp/app.dart'));
    expect(content, contains('container.greeting'));
    expect(content, contains('isNotNull'));
  });

  test('the rendered content references AppContainer.greeting', () {
    final writer = const TddExampleWriter();
    final content = writer.render('myapp');
    expect(content, contains('AppContainer'));
    expect(content, contains('greeting'));
    expect(content, contains('expect'));
  });
}
