import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

/// Engine for finding existing files without hardcoded path assumptions.
class DiscoveryEngine {
  final String projectRoot;

  const DiscoveryEngine({required this.projectRoot});

  /// Finds a file by its name (PascalCase or snake_case) in the project.
  ///
  /// Searches under [lib/src] by default.
  Future<File?> findFile(String name, {String subDir = ''}) async {
    final searchBase = p.join(projectRoot, 'lib', 'src', subDir);
    if (!Directory(searchBase).existsSync()) return null;

    // Support both PascalCase and snake_case naming conventions
    final fileName = name.endsWith('.dart') ? name : '$name.dart';
    final snakeName = _camelToSnake(name.replaceAll('.dart', '')) + '.dart';

    final patterns = [
      '**/$fileName',
      if (fileName != snakeName) '**/$snakeName',
    ];

    for (final pattern in patterns) {
      final glob = Glob(pattern);
      try {
        final matches = glob.listSync(root: searchBase);
        if (matches.isNotEmpty) {
          return File(matches.first.path);
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
    if (!Directory(searchBase).existsSync()) return [];

    final glob = Glob('**/*.dart');
    return glob.listSync(root: searchBase).whereType<File>().toList();
  }

  /// Synchronous version of [findFile].
  File? findFileSync(String name, {String subDir = ''}) {
    final searchBase = p.join(projectRoot, 'lib', 'src', subDir);
    if (!Directory(searchBase).existsSync()) return null;

    final fileName = name.endsWith('.dart') ? name : '$name.dart';
    final snakeName = _camelToSnake(name.replaceAll('.dart', '')) + '.dart';

    final patterns = [
      '**/$fileName',
      if (fileName != snakeName) '**/$snakeName',
    ];

    for (final pattern in patterns) {
      final glob = Glob(pattern);
      try {
        final matches = glob.listSync(root: searchBase);
        if (matches.isNotEmpty) {
          return File(matches.first.path);
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
