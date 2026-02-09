import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('FileSystem', () {
    test('reads file content', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/read.txt');
      await file.writeAsString('content');

      final fs = FileSystem.create(root: dir.path);
      final result = await fs.read('read.txt');

      expect(result, equals('content'));
    });

    test('writes file with directories', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));

      final fs = FileSystem.create(root: dir.path);
      await fs.write('nested/dir/file.txt', 'data');

      final file = File('${dir.path}/nested/dir/file.txt');
      expect(await file.readAsString(), equals('data'));
    });

    test('checks file existence', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));
      final fs = FileSystem.create(root: dir.path);

      expect(await fs.exists('missing.txt'), isFalse);
      await fs.write('exists.txt', 'ok');
      expect(await fs.exists('exists.txt'), isTrue);
    });

    test('deletes existing file', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));
      final fs = FileSystem.create(root: dir.path);
      await fs.write('delete.txt', 'remove');

      await fs.delete('delete.txt');

      expect(await fs.exists('delete.txt'), isFalse);
    });

    test('watches file changes', () async {
      final dir = await Directory.systemTemp.createTemp('zuraffa_fs_');
      addTearDown(() => dir.delete(recursive: true));
      final fs = FileSystem.create(root: dir.path);
      await fs.write('watch.txt', 'start');

      final stream = fs.watch('watch.txt');
      final expected = expectLater(stream, emits('watch.txt'));
      await fs.write('watch.txt', 'updated');
      await expected;
    });
  });
}
