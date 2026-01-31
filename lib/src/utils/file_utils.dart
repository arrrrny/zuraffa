import 'dart:io';
import '../models/generated_file.dart';

class FileUtils {
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

    if (exists && !force) {
      if (verbose) {
        print('  ⏭ Skipping existing file: $filePath');
      }
      return GeneratedFile(
        path: filePath,
        type: type,
        action: 'skipped',
        content: content,
      );
    }

    if (!dryRun) {
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }

    if (verbose) {
      final action = exists ? 'Overwriting' : 'Creating';
      print('  ✓ $action: $filePath');
    }

    return GeneratedFile(
      path: filePath,
      type: type,
      action: exists ? 'overwritten' : 'created',
      content: content,
    );
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
}
