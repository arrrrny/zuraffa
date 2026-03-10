import 'dart:io';

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
  }) async {
    final file = File(path);
    final previous = await file.readAsString();
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

  static Future<FileOperation> delete({required String path}) async {
    final file = File(path);
    final previous = await file.readAsString();
    return FileOperation._(
      type: FileOperationType.delete,
      path: path,
      content: null,
      previousContent: previous,
      expectedHash: ConflictDetector.hashContent(previous),
      existedAtPlan: true,
    );
  }

  String? detectConflict() => ConflictDetector.detectConflict(this);

  Future<void> apply() async {
    switch (type) {
      case FileOperationType.create:
      case FileOperationType.update:
        if (content == null) {
          throw StateError('Missing content for $path');
        }
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString(content!);
        return;
      case FileOperationType.delete:
        final file = File(path);
        if (!await file.exists()) {
          throw FileSystemException('File not found', path);
        }
        await file.delete();
        return;
    }
  }

  Future<void> rollback() async {
    switch (type) {
      case FileOperationType.create:
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        return;
      case FileOperationType.update:
      case FileOperationType.delete:
        if (previousContent == null) {
          return;
        }
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsString(previousContent!);
        return;
    }
  }
}
