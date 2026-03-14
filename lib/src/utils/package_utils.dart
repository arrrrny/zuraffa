import 'dart:io';
import 'package:path/path.dart' as path;

class PackageUtils {
  static String getPackageName({String? outputDir}) {
    File? pubspec;
    if (outputDir != null) {
      // 1. Try to find pubspec.yaml in outputDir or its parents
      var current = Directory(outputDir);
      while (current.path != '.' && current.path != '/') {
        final p = File(path.join(current.path, 'pubspec.yaml'));
        if (p.existsSync()) {
          pubspec = p;
          break;
        }
        current = current.parent;
      }
    }

    // 2. Fallback to current directory
    pubspec ??= File('pubspec.yaml');

    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final nameLine = content
          .split('\n')
          .firstWhere((l) => l.startsWith('name:'));
      return nameLine.split(':')[1].trim();
    }
    return 'app';
  }

  static String getBaseImport(String outputDir) {
    final packageName = getPackageName(outputDir: outputDir);
    var base = 'package:$packageName';

    // If outputDir is inside lib/, we need to extract the sub-import path
    // e.g. lib/src -> package:name/src
    // e.g. lib/core -> package:name/core
    // e.g. lib -> package:name

    // First, find where 'lib' is in the path
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
