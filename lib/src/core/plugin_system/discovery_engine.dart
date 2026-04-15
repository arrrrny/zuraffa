import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import '../context/file_system.dart';
import '../transaction/generation_transaction.dart';
import '../transaction/file_operation.dart';

/// Engine for finding existing files without hardcoded path assumptions.
class DiscoveryEngine {
  final String projectRoot;
  final FileSystem fileSystem;

  const DiscoveryEngine({
    required this.projectRoot,
    this.fileSystem = const DefaultFileSystem(),
  });

  /// Finds a file by its name (PascalCase or snake_case) in the project.
  ///
  /// Searches under [lib/src] by default.
  Future<File?> findFile(String name, {String subDir = ''}) async {
    // If the projectRoot itself contains 'lib/src', don't append it again
    var searchBase = projectRoot;
    if (!projectRoot.endsWith('lib/src') &&
        !projectRoot.contains('/lib/src/')) {
      final libSrc = p.join(projectRoot, 'lib', 'src');
      if (await fileSystem.exists(libSrc)) {
        searchBase = libSrc;
      }
    }

    if (subDir.isNotEmpty) {
      searchBase = p.join(searchBase, subDir);
    }

    if (!await fileSystem.exists(searchBase)) return null;

    // Support both PascalCase and snake_case naming conventions
    final fileName = name.endsWith('.dart') ? name : '$name.dart';
    final snakeName = '${_camelToSnake(name.replaceAll('.dart', ''))}.dart';

    // 1. Check current transaction first
    final transaction = GenerationTransaction.current;
    if (transaction != null) {
      final pendingFiles = transaction.operations
          .where((o) => o.type != FileOperationType.delete)
          .map((o) => o.path);
      for (final path in pendingFiles) {
        final base = p.basename(path);
        if (base == fileName || base == snakeName) {
          final absolutePath = p.isAbsolute(path)
              ? p.canonicalize(path)
              : p.canonicalize(p.join(projectRoot, path));
          final absoluteSearchBase = p.isAbsolute(searchBase)
              ? p.canonicalize(searchBase)
              : p.canonicalize(p.join(projectRoot, searchBase));
          if (absolutePath.startsWith(absoluteSearchBase)) {
            return File(path);
          }
        }
      }
    }

    final patterns = [
      '**/$fileName',
      if (fileName != snakeName) '**/$snakeName',
    ];

    for (final pattern in patterns) {
      final glob = Glob(pattern);
      try {
        // Note: glob.listSync still uses physical disk.
        // For deep integration, we'd need a glob implementation on top of FileSystem.
        // For now, we list from disk and then overlay transaction state.
        final matches = glob.listSync(root: searchBase);
        if (matches.isNotEmpty) {
          final firstPath = matches.first.path;
          // Verify it hasn't been deleted in the transaction
          if (transaction != null) {
            final op = transaction.operations
                .where((o) => o.path == firstPath)
                .lastOrNull;
            if (op != null && op.type == FileOperationType.delete) {
              continue;
            }
          }
          return File(firstPath);
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  /// Finds all files in a specific layer (e.g., 'domain/usecases').
  Future<List<File>> findInLayer(String layer) async {
    final searchBase = p.join(projectRoot, 'lib', 'src', layer);

    // Check transaction first
    final transaction = GenerationTransaction.current;
    final results = <File>[];
    final deletedPaths = <String>{};

    if (transaction != null) {
      for (final op in transaction.operations) {
        if (op.path.startsWith(searchBase)) {
          if (op.type == FileOperationType.delete) {
            deletedPaths.add(op.path);
          } else {
            results.add(File(op.path));
          }
        }
      }
    }

    if (!await fileSystem.exists(searchBase)) return results;

    final glob = Glob('**/*.dart');
    final diskFiles = glob.listSync(root: searchBase).whereType<File>();

    for (final file in diskFiles) {
      if (!deletedPaths.contains(file.path) &&
          !results.any((r) => r.path == file.path)) {
        results.add(file);
      }
    }

    return results;
  }

  /// Synchronous version of [findFile].
  File? findFileSync(String name, {String subDir = ''}) {
    // If the projectRoot itself contains 'lib/src', don't append it again
    var searchBase = projectRoot;
    if (!projectRoot.endsWith('lib/src') &&
        !projectRoot.contains('/lib/src/')) {
      final libSrc = p.join(projectRoot, 'lib', 'src');
      if (fileSystem.existsSync(libSrc)) {
        searchBase = libSrc;
      }
    }

    if (subDir.isNotEmpty) {
      searchBase = p.join(searchBase, subDir);
    }

    if (!fileSystem.existsSync(searchBase)) return null;

    final fileName = name.endsWith('.dart') ? name : '$name.dart';
    final snakeName = '${_camelToSnake(name.replaceAll('.dart', ''))}.dart';

    // 1. Check current transaction first (best effort)
    final transaction = GenerationTransaction.current;
    if (transaction != null) {
      final pendingFiles = transaction.operations
          .where((o) => o.type != FileOperationType.delete)
          .map((o) => o.path);
      for (final path in pendingFiles) {
        final base = p.basename(path);
        if (base == fileName || base == snakeName) {
          final absolutePath = p.isAbsolute(path)
              ? p.canonicalize(path)
              : p.canonicalize(p.join(projectRoot, path));
          final absoluteSearchBase = p.isAbsolute(searchBase)
              ? p.canonicalize(searchBase)
              : p.canonicalize(p.join(projectRoot, searchBase));
          if (absolutePath.startsWith(absoluteSearchBase)) {
            return File(path);
          }
        }
      }
    }

    final patterns = [
      '**/$fileName',
      if (fileName != snakeName) '**/$snakeName',
    ];

    for (final pattern in patterns) {
      final glob = Glob(pattern);
      try {
        final matches = glob.listSync(root: searchBase);
        if (matches.isNotEmpty) {
          final firstPath = matches.first.path;
          if (transaction != null) {
            final op = transaction.operations
                .where((o) => o.path == firstPath)
                .lastOrNull;
            if (op != null && op.type == FileOperationType.delete) {
              continue;
            }
          }
          return File(firstPath);
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  String _camelToSnake(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (i > 0 && char.toUpperCase() == char && char != '_') {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
