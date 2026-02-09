import 'dart:io';

import 'file_operation.dart';

class ConflictDetector {
  static int hashContent(String content) {
    var hash = 0;
    for (final unit in content.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static String? detectConflict(FileOperation operation) {
    final file = File(operation.path);
    switch (operation.type) {
      case FileOperationType.create:
        if (file.existsSync()) {
          return 'File already exists';
        }
        return null;
      case FileOperationType.update:
      case FileOperationType.delete:
        if (!file.existsSync()) {
          return 'File missing';
        }
        if (operation.expectedHash != null) {
          final current = file.readAsStringSync();
          final currentHash = hashContent(current);
          if (currentHash != operation.expectedHash) {
            return 'File modified since planning';
          }
        }
        return null;
    }
  }
}
