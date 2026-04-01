import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

abstract class FileSystem {
  static FileSystem create({String? root}) => DefaultFileSystem(root: root);

  Future<String> read(String path);
  String readSync(String path);
  Future<void> write(String path, String content);
  Future<void> delete(String path);
  Future<bool> exists(String path);
  bool existsSync(String path);
  Future<void> createDir(String path, {bool recursive = false});
  Future<bool> isDirectory(String path);
  bool isDirectorySync(String path);
  Future<List<String>> list(String path, {bool recursive = false});
  List<String> listSync(String path, {bool recursive = false});
  Stream<String> watch(String path);
}

class DefaultFileSystem implements FileSystem {
  final String? root;

  const DefaultFileSystem({this.root});

  String resolve(String path) {
    final rootPath = root != null ? p.canonicalize(root!) : null;
    if (rootPath == null) {
      return p.canonicalize(path);
    }
    if (p.isAbsolute(path)) {
      return p.canonicalize(path);
    }
    return p.canonicalize(p.join(rootPath, path));
  }

  @override
  Future<String> read(String path) async {
    return File(resolve(path)).readAsString();
  }

  @override
  String readSync(String path) {
    return File(resolve(path)).readAsStringSync();
  }

  @override
  Future<void> write(String path, String content) async {
    final resolved = resolve(path);
    final file = File(resolved);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<void> delete(String path) async {
    final resolved = resolve(path);
    if (await File(resolved).exists()) {
      await File(resolved).delete();
    } else if (await Directory(resolved).exists()) {
      await Directory(resolved).delete(recursive: true);
    }
  }

  @override
  Future<bool> exists(String path) async {
    final resolved = resolve(path);
    return await File(resolved).exists() || await Directory(resolved).exists();
  }

  @override
  bool existsSync(String path) {
    final resolved = resolve(path);
    return File(resolved).existsSync() || Directory(resolved).existsSync();
  }

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {
    await Directory(resolve(path)).create(recursive: recursive);
  }

  @override
  Future<bool> isDirectory(String path) async {
    return Directory(resolve(path)).exists();
  }

  @override
  bool isDirectorySync(String path) {
    return Directory(resolve(path)).existsSync();
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final dir = Directory(resolve(path));
    if (!await dir.exists()) return [];
    return dir.list(recursive: recursive).map((entity) => entity.path).toList();
  }

  @override
  List<String> listSync(String path, {bool recursive = false}) {
    final dir = Directory(resolve(path));
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: recursive)
        .map((entity) => entity.path)
        .toList();
  }

  @override
  Stream<String> watch(String path) {
    return File(resolve(path)).watch().map((_) => path);
  }
}
