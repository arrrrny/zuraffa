import 'package:dart_style/dart_style.dart';
import '../core/transaction/file_operation.dart';
import '../core/transaction/generation_transaction.dart';
import '../core/context/file_system.dart';
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
    bool revert = false,
    bool skipRevertIfExisted = false,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();

    if (revert) {
      if (!await fs.exists(filePath)) {
        return GeneratedFile(path: filePath, type: type, action: 'skipped');
      }

      if (skipRevertIfExisted) {
        final existingContent = await fs.read(filePath);
        final existingFirstLine = existingContent.split('\n').first.trim();
        final newFirstLine = content.split('\n').first.trim();

        if (existingFirstLine != newFirstLine) {
          if (verbose) {
            print(
              '  ⏭ Skipping revert for $filePath (content changed or not ours)',
            );
          }
          return GeneratedFile(path: filePath, type: type, action: 'skipped');
        }
      }
      return deleteFile(
        filePath,
        type,
        dryRun: dryRun,
        verbose: verbose,
        fileSystem: fs,
      );
    }

    final exists = await fs.exists(filePath);
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
          ? await FileOperation.update(
              path: filePath,
              content: formattedContent,
              force: force,
              fileSystem: fs,
            )
          : FileOperation.create(
              path: filePath,
              content: formattedContent,
              force: force,
            );
      transaction.addOperation(operation);
    } else if (!dryRun) {
      await fs.write(filePath, formattedContent);
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
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    final exists = await fs.exists(filePath);

    if (!exists) {
      if (verbose) {
        print('  ⏭ Skipping missing file: $filePath');
      }
      return GeneratedFile(path: filePath, type: type, action: 'skipped');
    }

    final transaction = GenerationTransaction.current;
    if (transaction != null) {
      final operation = await FileOperation.delete(
        path: filePath,
        fileSystem: fs,
      );
      transaction.addOperation(operation);
    } else if (!dryRun) {
      await fs.delete(filePath);
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
        return 'id';
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

  static Future<String?> findFileImplementing(
    String directory,
    String interfaceName, {
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();
    if (!await fs.exists(directory)) return null;

    final files = await fs.list(directory);

    for (final filePath in files) {
      if (await fs.isDirectory(filePath)) {
        final result = await findFileImplementing(
          filePath,
          interfaceName,
          fileSystem: fs,
        );
        if (result != null) return result;
        continue;
      }

      if (!filePath.endsWith('.dart')) continue;

      final content = await fs.read(filePath);
      if (content.contains('implements $interfaceName')) {
        return filePath;
      }
    }
    return null;
  }
}
