import 'dart:io';

import '../context/file_system.dart';
import 'conflict_detector.dart';

enum FileOperationType { create, update, delete }

class FileOperation {
  final FileOperationType type;
  final String path;
  final String? content;
  final String? previousContent;
  final int? expectedHash;
  final bool existedAtPlan;

  final bool force;

  const FileOperation._({
    required this.type,
    required this.path,
    required this.content,
    required this.previousContent,
    required this.expectedHash,
    required this.existedAtPlan,
    this.force = false,
  });

  factory FileOperation.create({
    required String path,
    required String content,
    bool force = false,
  }) {
    return FileOperation._(
      type: FileOperationType.create,
      path: path,
      content: content,
      previousContent: null,
      expectedHash: null,
      existedAtPlan: false,
      force: force,
    );
  }

  static Future<FileOperation> update({
    required String path,
    required String content,
    bool force = false,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    final previous = await fs.read(path);
    return FileOperation._(
      type: FileOperationType.update,
      path: path,
      content: content,
      previousContent: previous,
      expectedHash: ConflictDetector.hashContent(previous),
      existedAtPlan: true,
      force: force,
    );
  }

  static Future<FileOperation> delete({
    required String path,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    final previous = await fs.read(path);
    return FileOperation._(
      type: FileOperationType.delete,
      path: path,
      content: null,
      previousContent: previous,
      expectedHash: ConflictDetector.hashContent(previous),
      existedAtPlan: true,
    );
  }

  Future<String?> detectConflict(FileSystem fileSystem) =>
      ConflictDetector.detectConflict(this, fileSystem);

  Future<void> apply({FileSystem? fileSystem}) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    switch (type) {
      case FileOperationType.create:
      case FileOperationType.update:
        if (content == null) {
          throw StateError('Missing content for $path');
        }
        await fs.write(path, content!);
        return;
      case FileOperationType.delete:
        if (!await fs.exists(path)) {
          throw FileSystemException('File not found', path);
        }
        await fs.delete(path);
        return;
    }
  }

  Future<void> rollback({FileSystem? fileSystem}) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    switch (type) {
      case FileOperationType.create:
        if (await fs.exists(path)) {
          await fs.delete(path);
        }
        return;
      case FileOperationType.update:
      case FileOperationType.delete:
        if (previousContent == null) {
          return;
        }
        await fs.write(path, previousContent!);
        return;
    }
  }
}
