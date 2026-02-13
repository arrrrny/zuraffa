import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';

void main() {
  group('DefaultFileSystem', () {
    test('writes, reads, and deletes with root', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));

      final fs = DefaultFileSystem(root: dir.path);
      await fs.write('nested/file.txt', 'hello');

      expect(await fs.exists('nested/file.txt'), isTrue);
      expect(await fs.read('nested/file.txt'), equals('hello'));

      await fs.delete('nested/file.txt');
      expect(await fs.exists('nested/file.txt'), isFalse);
    });

    test('creates directories', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));

      final fs = DefaultFileSystem(root: dir.path);
      await fs.createDir('a/b', recursive: true);

      expect(Directory('${dir.path}/a/b').existsSync(), isTrue);
    });
  });
}
