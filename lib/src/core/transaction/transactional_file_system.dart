import '../context/file_system.dart';
import 'generation_transaction.dart';
import 'file_operation.dart';

/// A [FileSystem] implementation that respects pending operations in the
/// current [GenerationTransaction].
class TransactionalFileSystem implements FileSystem {
  final FileSystem base;

  TransactionalFileSystem(this.base);

  String _resolve(String path) {
    if (base is DefaultFileSystem) {
      return (base as DefaultFileSystem).resolve(path);
    }
    return path;
  }

  @override
  Future<bool> exists(String path) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      final op = transaction.operations
          .where((o) => _resolve(o.path) == resolvedPath)
          .lastOrNull;
      if (op != null) {
        return op.type != FileOperationType.delete;
      }
      // Check if any pending file is within this directory
      final anySubFile = transaction.operations.any(
        (o) =>
            _resolve(o.path).startsWith(resolvedPath) &&
            o.type != FileOperationType.delete,
      );
      if (anySubFile) return true;
    }
    return base.exists(path);
  }

  @override
  bool existsSync(String path) {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      final op = transaction.operations
          .where((o) => _resolve(o.path) == resolvedPath)
          .lastOrNull;
      if (op != null) {
        return op.type != FileOperationType.delete;
      }
      // Check if any pending file is within this directory
      final anySubFile = transaction.operations.any(
        (o) =>
            _resolve(o.path).startsWith(resolvedPath) &&
            o.type != FileOperationType.delete,
      );
      if (anySubFile) return true;
    }
    return base.existsSync(path);
  }

  @override
  Future<String> read(String path) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      final op = transaction.operations
          .where((o) => _resolve(o.path) == resolvedPath)
          .lastOrNull;
      if (op != null) {
        if (op.type == FileOperationType.delete) {
          throw Exception('File deleted in transaction: $path');
        }
        return op.content ?? '';
      }
    }
    return base.read(path);
  }

  @override
  String readSync(String path) {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      final op = transaction.operations
          .where((o) => _resolve(o.path) == resolvedPath)
          .lastOrNull;
      if (op != null) {
        if (op.type == FileOperationType.delete) {
          throw Exception('File deleted in transaction: $path');
        }
        return op.content ?? '';
      }
    }
    return base.readSync(path);
  }

  @override
  Future<void> write(String path, String content) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      final exists = await base.exists(resolvedPath);
      final op = exists
          ? await FileOperation.update(path: resolvedPath, content: content)
          : FileOperation.create(path: resolvedPath, content: content);
      transaction.addOperation(op);
    } else {
      await base.write(resolvedPath, content);
    }
  }

  @override
  Future<void> delete(String path) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      transaction.addOperation(await FileOperation.delete(path: resolvedPath));
    } else {
      await base.delete(resolvedPath);
    }
  }

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {
    final resolvedPath = _resolve(path);
    await base.createDir(resolvedPath, recursive: recursive);
  }

  @override
  Future<bool> isDirectory(String path) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      // If there's a pending operation for exactly this path, it's a file, not a directory
      final op = transaction.operations
          .where((o) => o.path == resolvedPath)
          .lastOrNull;
      if (op != null) return false;

      // If any pending file is within this directory, it's a directory
      final anySubFile = transaction.operations.any(
        (o) =>
            o.path.startsWith(resolvedPath) &&
            o.type != FileOperationType.delete,
      );
      if (anySubFile) return true;
    }
    return base.isDirectory(resolvedPath);
  }

  @override
  bool isDirectorySync(String path) {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    if (transaction != null) {
      // If there's a pending operation for exactly this path, it's a file, not a directory
      final op = transaction.operations
          .where((o) => o.path == resolvedPath)
          .lastOrNull;
      if (op != null) return false;

      // If any pending file is within this directory, it's a directory
      final anySubFile = transaction.operations.any(
        (o) =>
            o.path.startsWith(resolvedPath) &&
            o.type != FileOperationType.delete,
      );
      if (anySubFile) return true;
    }
    return base.isDirectorySync(resolvedPath);
  }

  @override
  Future<List<String>> list(String path, {bool recursive = false}) async {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    final diskItems = await base.list(resolvedPath, recursive: recursive);
    if (transaction == null) return diskItems;

    final results = <String>{...diskItems.map(_resolve)};
    for (final op in transaction.operations) {
      if (op.path.startsWith(resolvedPath)) {
        if (op.type == FileOperationType.delete) {
          results.remove(op.path);
        } else {
          results.add(op.path);
        }
      }
    }
    return results.toList();
  }

  @override
  List<String> listSync(String path, {bool recursive = false}) {
    final transaction = GenerationTransaction.current;
    final resolvedPath = _resolve(path);
    final diskItems = base.listSync(resolvedPath, recursive: recursive);
    if (transaction == null) return diskItems;

    final results = <String>{...diskItems.map(_resolve)};
    for (final op in transaction.operations) {
      if (op.path.startsWith(resolvedPath)) {
        if (op.type == FileOperationType.delete) {
          results.remove(op.path);
        } else {
          results.add(op.path);
        }
      }
    }
    return results.toList();
  }

  @override
  Stream<String> watch(String path) {
    return base.watch(_resolve(path));
  }
}
