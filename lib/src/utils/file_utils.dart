import 'dart:io';
import 'package:dart_style/dart_style.dart';
import '../core/transaction/file_operation.dart';
import '../core/transaction/generation_transaction.dart';
import '../models/generated_file.dart';

class FileUtils {
  static final DartFormatter _formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );

  static Future<GeneratedFile> writeFile(
    String filePath,
    String content,
    String type, {
    bool force = false,
    bool dryRun = false,
    bool verbose = false,
  }) async {
    final file = File(filePath);
    final exists = file.existsSync();
    final formattedContent = _formatDart(content, filePath);

    if (exists && !force) {
      if (verbose) {
        print('  ⏭ Skipping existing file: $filePath');
      }
      return GeneratedFile(
        path: filePath,
        type: type,
        action: 'skipped',
        content: formattedContent,
      );
    }

    final transaction = GenerationTransaction.current;
    if (transaction != null) {
      final operation = exists
          ? await FileOperation.update(path: filePath, content: formattedContent)
          : FileOperation.create(path: filePath, content: formattedContent);
      transaction.addOperation(operation);
    } else if (!dryRun) {
      await file.parent.create(recursive: true);
      await file.writeAsString(formattedContent);
    }

    if (verbose) {
      final action = exists ? 'Overwriting' : 'Creating';
      print('  ✓ $action: $filePath');
    }

    return GeneratedFile(
      path: filePath,
      type: type,
      action: exists ? 'overwritten' : 'created',
      content: formattedContent,
    );
  }

  static Future<GeneratedFile> deleteFile(
    String filePath,
    String type, {
    bool dryRun = false,
    bool verbose = false,
  }) async {
    final file = File(filePath);
    final exists = file.existsSync();

    if (!exists) {
      if (verbose) {
        print('  ⏭ Skipping missing file: $filePath');
      }
      return GeneratedFile(path: filePath, type: type, action: 'skipped');
    }

    final transaction = GenerationTransaction.current;
    if (transaction != null) {
      final operation = await FileOperation.delete(path: filePath);
      transaction.addOperation(operation);
    } else if (!dryRun) {
      await file.delete();
    }

    if (verbose) {
      print('  ✓ Deleting: $filePath');
    }

    return GeneratedFile(path: filePath, type: type, action: 'deleted');
  }

  static String getParamName(String method, String entityCamel) {
    switch (method) {
      case 'get':
      case 'watch':
      case 'getList':
      case 'watchList':
        return 'params';
      case 'delete':
        return 'id'; // Will update this to use config if I had config here, but FileUtils doesn't have config.
      case 'create':
      case 'update':
        return entityCamel;
      default:
        return 'params';
    }
  }

  static String _formatDart(String content, String filePath) {
    if (!filePath.endsWith('.dart')) {
      return content;
    }
    try {
      return _formatter.format(content);
    } catch (_) {
      return content;
    }
  }
}
