import 'dart:io';

/// Reads package name from pubspec.yaml
class PackageNameReader {
  /// Get package name from pubspec.yaml in the given directory
  static Future<String> getPackageName(String projectPath) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');

    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml not found at $projectPath');
    }

    final content = await pubspecFile.readAsString();

    // Simple YAML parsing - look for "name: package_name"
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('name:')) {
        final name = trimmed.substring(5).trim();
        // Remove quotes if present
        return name.replaceAll('"', '').replaceAll("'", '');
      }
    }

    throw Exception('Could not find package name in pubspec.yaml');
  }
}
