import '../context/file_system.dart';
import 'file_operation.dart';

class ConflictDetector {
  static int hashContent(String content) {
    var hash = 0;
    for (final unit in content.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static Future<String?> detectConflict(
    FileOperation operation,
    FileSystem fileSystem,
  ) async {
    final path = operation.path;
    final exists = await fileSystem.exists(path);

    switch (operation.type) {
      case FileOperationType.create:
        if (exists && !operation.force) {
          return 'File already exists';
        }
        return null;
      case FileOperationType.update:
      case FileOperationType.delete:
        if (!exists) {
          return 'File missing';
        }
        if (operation.expectedHash != null && !operation.force) {
          final current = await fileSystem.read(path);
          final currentHash = hashContent(current);
          if (currentHash != operation.expectedHash) {
            return 'File modified since planning';
          }
        }
        return null;
    }
  }
}
