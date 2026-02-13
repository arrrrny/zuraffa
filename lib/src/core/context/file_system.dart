import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

abstract class FileSystem {
  static FileSystem create({String? root}) => DefaultFileSystem(root: root);

  Future<String> read(String path);
  Future<void> write(String path, String content);
  Future<void> delete(String path);
  Future<bool> exists(String path);
  Future<void> createDir(String path, {bool recursive = false});
  Stream<String> watch(String path);
}

class DefaultFileSystem implements FileSystem {
  final String? root;

  DefaultFileSystem({this.root});

  String _resolve(String path) {
    if (root == null) {
      return path;
    }
    if (p.isAbsolute(path)) {
      return path;
    }
    return p.join(root!, path);
  }

  @override
  Future<String> read(String path) async {
    return File(_resolve(path)).readAsString();
  }

  @override
  Future<void> write(String path, String content) async {
    final resolved = _resolve(path);
    print('DEBUG: Writing to $resolved (original: $path, root: $root)');
    final file = File(resolved);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(_resolve(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> exists(String path) async {
    return File(_resolve(path)).exists();
  }

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {
    await Directory(_resolve(path)).create(recursive: recursive);
  }

  @override
  Stream<String> watch(String path) {
    return File(_resolve(path)).watch().map((_) => path);
  }
}
