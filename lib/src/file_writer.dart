import 'dart:io';
import 'package:path/path.dart' as path;

/// Handles writing generated files to the filesystem
class FileWriter {
  final String projectPath;

  FileWriter(this.projectPath);

  /// Write a single file
  /// Creates directories if they don't exist
  Future<void> writeFile(String relativePath, String content) async {
    final fullPath = path.join(projectPath, relativePath);
    final file = File(fullPath);

    // Create parent directories
    await file.parent.create(recursive: true);

    // Write file
    await file.writeAsString(content);
  }

  /// Write multiple files at once
  /// Returns list of written file paths
  Future<List<String>> writeFiles(Map<String, String> files) async {
    final written = <String>[];

    for (final entry in files.entries) {
      await writeFile(entry.key, entry.value);
      written.add(entry.key);
    }

    return written;
  }

  /// Check if file exists
  Future<bool> fileExists(String relativePath) async {
    final fullPath = path.join(projectPath, relativePath);
    return await File(fullPath).exists();
  }

  /// Read file content
  Future<String> readFile(String relativePath) async {
    final fullPath = path.join(projectPath, relativePath);
    return await File(fullPath).readAsString();
  }

  /// Delete file
  Future<void> deleteFile(String relativePath) async {
    final fullPath = path.join(projectPath, relativePath);
    final file = File(fullPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
