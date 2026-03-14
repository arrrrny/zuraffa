import 'dart:io';

class PackageUtils {
  static String getPackageName() {
    final pubspec = File('pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      final nameLine = content.split('\n').firstWhere((l) => l.startsWith('name:'));
      return nameLine.split(':')[1].trim();
    }
    return 'app';
  }

  static String getBaseImport(String outputDir) {
    final packageName = getPackageName();
    var base = 'package:$packageName';
    if (outputDir.startsWith('lib/')) {
      final sub = outputDir.substring(4);
      if (sub.isNotEmpty) {
        base = '$base/$sub';
      }
    } else if (outputDir == 'lib') {
      // base remains package:packageName
    }
    return base;
  }
}
