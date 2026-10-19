import 'package:path/path.dart' as path;

import '../core/context/file_system.dart';

class PackageUtils {
  static String getPackageName({String? outputDir, FileSystem? fileSystem}) {
    final fs = fileSystem ?? const DefaultFileSystem();
    String? pubspecPath;

    if (outputDir != null) {
      // 1. Try to find pubspec.yaml in outputDir or its parents (including
      //    the project root itself, so relative output dirs like `lib/src`
      //    resolve to the consuming project's pubspec instead of falling
      //    back to the `zuraffa` default — issue #1718 Gap 3).
      var currentPath = outputDir;
      while (true) {
        final p = path.join(currentPath, 'pubspec.yaml');
        if (fs.existsSync(p)) {
          pubspecPath = p;
          break;
        }
        if (currentPath == '.' || currentPath == '/' || currentPath == '') {
          break;
        }
        currentPath = path.dirname(currentPath);
      }
    }

    // 2. Fallback to current directory if no outputDir was provided
    if (pubspecPath == null && outputDir == null) {
      pubspecPath = 'pubspec.yaml';
    }

    if (pubspecPath != null && fs.existsSync(pubspecPath)) {
      final content = fs.readSync(pubspecPath);
      final nameLine = content
          .split('\n')
          .firstWhere((l) => l.startsWith('name:'), orElse: () => '');
      if (nameLine.isNotEmpty) {
        return nameLine.split(':')[1].trim();
      }
    }
    return 'zuraffa';
  }

  @Deprecated(
    'Use relative imports instead. '
    'See CommonPatterns.entityImports() for the new approach.',
  )
  static String getBaseImport(String outputDir, {FileSystem? fileSystem}) {
    final fs = fileSystem ?? const DefaultFileSystem();
    final packageName = getPackageName(outputDir: outputDir, fileSystem: fs);
    var base = 'package:$packageName';

    // If outputDir is inside lib/, we need to extract the sub-import path
    final segments = path.split(outputDir);
    final libIndex = segments.indexOf('lib');

    if (libIndex != -1 && libIndex < segments.length - 1) {
      final subPath = path.joinAll(segments.sublist(libIndex + 1));
      if (subPath.isNotEmpty) {
        base = '$base/$subPath';
      }
    }

    return base;
  }
}
