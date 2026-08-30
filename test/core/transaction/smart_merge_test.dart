@Tags(['slow'])

import 'dart:io';
import 'package:test/test.dart';
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

    test('rethrows permission denied errors without overwriting', () async {
      // Regression test for Finding 2: permission errors should propagate
      final testFile = File('${tempDir.path}/readonly.dart');
      const originalContent = 'class Original {}';
      await testFile.writeAsString(originalContent);

      // Make file read-only (Platform-dependent, but works on Linux/Mac)
      if (!Platform.isWindows) {
        await Process.run('chmod', ['444', testFile.path]);

        await expectLater(
          () async => await SmartMergeWriter.writeMerged(
            fileSystem: fs,
            path: 'readonly.dart',
            newContent: 'class Modified {}',
          ),
          throwsA(isA<FileSystemException>()),
          reason: 'Permission errors should propagate, not be swallowed',
        );

        // Verify original file was not overwritten
        final content = await testFile.readAsString();
        expect(content, equals(originalContent));

        // Restore permissions for cleanup
        await Process.run('chmod', ['644', testFile.path]);
      }
    });
  });
}
