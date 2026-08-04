// Smart merge writer — bridges zorphy's MergeOrchestrator into
// zuraffa's file write pipeline.

// ignore_for_file: implementation_imports

import 'dart:io';

import '../context/file_system.dart';
import 'smart_merge_writer.dart';

/// Re-export merge types for convenience.
export 'package:zorphy/src/merge/merge.dart'
    show MergeOrchestrator, MergeMode, MergeResult;

class SmartMergeWriter {
  static Future<void> writeMerged({
    required FileSystem fileSystem,
    required String path,
    required String newContent,
  }) async {
    try {
      final existingContent = await fileSystem.read(path);
      if (existingContent.isEmpty) {
        // File doesn't exist or is empty - safe to write directly
        await fileSystem.write(path, newContent);
        return;
      }

      // File exists with content - attempt merge
      try {
        final result = MergeOrchestrator.merge(
          existingContent: existingContent,
          generatedContent: newContent,
          mode: MergeMode.smart,
          filePath: path,
        );

        for (final conflict in result.conflicts) {
          print('[merge warning] $path: ${conflict.message}');
          print('  suggestion: ${conflict.suggestion}');
        }

        if (result.hasChanges && result.diffSummary.isNotEmpty) {
          print('[merge] $path: ${_summarizeDiff(result.diffSummary)}');
        }

        await fileSystem.write(path, result.content);
      } catch (mergeError) {
        // Merge failed on existing file - propagate error instead of overwriting
        print('[merge error] $path: Failed to merge: $mergeError');
        rethrow;
      }
    } on FileSystemException catch (fsError) {
      // I/O error reading file
      print('[file system error] $path: $fsError');
      rethrow;
    } catch (error) {
      // Unexpected error
      print('[error] $path: $error');
      rethrow;
    }
  }

  static String _summarizeDiff(String diffSummary) {
    final lines = diffSummary.split('\n');
    if (lines.length <= 3) return diffSummary;
    final added = lines.where((l) => l.startsWith('+')).length;
    final removed = lines.where((l) => l.startsWith('-')).length;
    final modified = lines.where((l) => l.startsWith('~')).length;
    final parts = <String>[];
    if (added > 0) parts.add('$added added');
    if (removed > 0) parts.add('$removed removed');
    if (modified > 0) parts.add('$modified modified');
    return parts.join(', ');
  }
}
