import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/transaction/smart_merge_writer.dart';
import 'package:zuraffa/src/core/context/file_system.dart';

void main() {
  group('SmartMergeWriter', () {
    late Directory tempDir;
    late FileSystem fs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smart_merge_test_');
      fs = FileSystem.create(root: tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates file when no existing content', () async {
      const newContent = 'class Foo { final int x; }';
      await SmartMergeWriter.writeMerged(
        fileSystem: fs,
        path: 'test.dart',
        newContent: newContent,
      );
      final result = await fs.read('test.dart');
      expect(result, contains('class Foo'));
    });

    test('merges when file exists with GENERATED markers', () async {
      final existing = '''// GENERATED - DO NOT EDIT
class \$Todo {
  final String title;
}
// END GENERATED

class TodoHelper { static String hi() => "hi"; }
''';
      await fs.write('test.dart', existing);

      final generated = '''// GENERATED - DO NOT EDIT
class \$Todo {
  final String title;
  final bool done;
}
// END GENERATED
''';

      await SmartMergeWriter.writeMerged(
        fileSystem: fs,
        path: 'test.dart',
        newContent: generated,
      );

      final result = await fs.read('test.dart');
      expect(result, contains('done'));
      expect(result, contains('TodoHelper'));
    });
  });
}
