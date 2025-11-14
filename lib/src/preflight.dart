import 'dart:io';
import 'exceptions.dart';

/// Pre-flight checks before running Zuraffa
class PreflightChecker {
  final String projectPath;

  PreflightChecker(this.projectPath);

  /// Run all pre-flight checks
  /// Throws ZuraffaException if any check fails
  Future<void> runChecks({bool skipDependencyCheck = false}) async {
    await _checkProjectStructure();

    if (!skipDependencyCheck) {
      await _checkDependencies();
    }
  }

  /// Check if we're in a valid Dart/Flutter project
  Future<void> _checkProjectStructure() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');

    if (!await pubspecFile.exists()) {
      throw ZuraffaException(
        'Not a Dart/Flutter project (pubspec.yaml not found)',
        hint: 'Run this command from your project root directory, or create a new project:\n'
            '  flutter create my_app\n'
            '  cd my_app\n'
            '  zuraffa create entity Product --from-json product.json',
      );
    }
  }

  /// Check if required dependencies are in pubspec.yaml
  Future<void> _checkDependencies() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    final content = await pubspecFile.readAsString();

    // Check for zikzak_morphy
    if (!content.contains('zikzak_morphy:')) {
      throw DependencyException.morphyNotFound();
    }

    // Check if .dart_tool exists (indicates pub get was run)
    final dartToolDir = Directory('$projectPath/.dart_tool');
    if (!await dartToolDir.exists()) {
      throw DependencyException.pubGetNeeded();
    }
  }

  /// Quick check - just verifies project directory
  Future<void> quickCheck() async {
    await _checkProjectStructure();
  }
}
