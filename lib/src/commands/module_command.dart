import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/context/file_system.dart';
import '../utils/project_flavor.dart';

/// CLI command that scaffolds a new Zuraffa feature package.
///
/// Usage: `zfa module <FeatureName> [options]`
///
/// Creates a directory `zuraffa_feature_<name>/` with:
/// - pubspec.yaml (depends on zuraffa)
/// - analysis_options.yaml
/// - lib/src/{datasource,repository,usecase,controller,state,view,plugin}/
/// - test/
import '../core/project/project_root.dart';

/// Flutter import emitted into *generated* feature-package files.
///
/// Kept as a string constant (never a real import) so this pure-Dart core
/// command file has no `package:flutter/` dependency. See issue #495.
const String _flutterMaterialImport = "import 'package:flutter/material.dart';";

class ModuleCommand extends Command<void> {
  static const String defaultOutputDir = '.';

  ModuleCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Parent directory for the new package (default: current directory)',
      defaultsTo: defaultOutputDir,
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview the scaffold without writing files',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
  }

  @override
  String get name => 'module';

  @override
  String get description =>
      'Scaffold a new Zuraffa feature package with plugin orchestrator';

  @override
  String get invocation => 'zfa module <FeatureName> [options]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      printUsage();
      exitCode = 64;
      return;
    }

    final featureName = rest.first;
    final outputDir = argResults!['output'] as String;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final packageName = 'zuraffa_feature_${_toSnake(featureName)}';
    final packageDir = '$outputDir/$packageName';

    // #512: `zfa module` scaffolds a Flutter feature package (its pubspec
    // declares `flutter:` + `zuraffa_flutter`). In a pure-Dart target project
    // (pubspec.yaml without a `flutter:` dependency) scaffolding it would
    // violate Constitution VII (Engine Purity) and produce a package that
    // cannot resolve Flutter symbols under `dart analyze`. Skip with a clear
    // warning. (No pubspec found => unknown flavor => preserve historical
    // Flutter scaffolding.)
    final flavor = await detectProjectFlavor(
      ProjectRoot.safeCurrentPath(),
      FileSystem.create(),
    );
    if (flavor == ProjectFlavor.pureDart) {
      print(
        '⚠️ Skipping module scaffold: the current project is a pure-Dart '
        'package (no `flutter:` in pubspec.yaml). `zfa module` scaffolds a '
        'Flutter feature package (it depends on zuraffa_flutter). Run '
        '`zfa module` inside a Flutter project.',
      );
      return;
    }

    if (verbose) {
      print('Scaffolding feature package: $packageName');
      print('  Directory: $packageDir');
    }

    // Check if package already exists
    if (!force && Directory(packageDir).existsSync()) {
      print('Error: Package directory already exists: $packageDir');
      print('Use --force to overwrite existing files.');
      return;
    }

    if (!dryRun) {
      final dirs = [
        '$packageDir/lib/src/datasource',
        '$packageDir/lib/src/repository',
        '$packageDir/lib/src/usecase',
        '$packageDir/lib/src/controller',
        '$packageDir/lib/src/state',
        '$packageDir/lib/src/view',
        '$packageDir/lib/src/plugin',
        '$packageDir/test',
      ];
      for (final dir in dirs) {
        Directory(dir).createSync(recursive: true);
      }

      _writePubspec(packageDir, packageName, verbose);
      _writeAnalysisOptions(packageDir);
      _writeBarrel(packageDir, featureName);
      _writePlaceholderFiles(packageDir, featureName, verbose);
    }

    print('  Feature package $packageName scaffolded successfully.');
  }

  void _writePubspec(String dir, String packageName, bool verbose) {
    // Calculate relative path from generated package to zuraffa package
    final packageDirUri = Uri.directory(dir);
    final zuraffaDirUri = Uri.directory(ProjectRoot.safeCurrentPath());
    final relativePath = packageDirUri.toFilePath().endsWith('/')
        ? zuraffaDirUri.toFilePath().replaceAll(
            packageDirUri.toFilePath(),
            '../',
          )
        : '../';

    final content =
        '''
name: $packageName
description: Zuraffa feature package: ${_toSnake(packageName)}
publish_to: none
version: 1.0.0

environment:
  sdk: ^3.11.0
  flutter: ">=3.41.0"

dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: $relativePath
  zuraffa_flutter:
    path: ${relativePath}zuraffa_flutter

flutter:
  uses-material-design: true

dependency_overrides:
  meta: ^1.19.0
  analyzer: 14.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
''';
    File('$dir/pubspec.yaml').writeAsStringSync(content);
    if (verbose) print('  Created $dir/pubspec.yaml');
  }

  void _writeAnalysisOptions(String dir) {
    File(
      '$dir/analysis_options.yaml',
    ).writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
  }

  void _writeBarrel(String dir, String featureName) {
    final snake = _toSnake(featureName);
    final packageName = 'zuraffa_feature_$snake';
    File('$dir/lib/zuraffa_feature_$snake.dart').writeAsStringSync(
      '/// Feature package: $packageName\nlibrary;\n\n'
      "export 'src/plugin/${snake}_feature_plugin.dart';\n",
    );
  }

  void _writePlaceholderFiles(String dir, String featureName, bool verbose) {
    final snake = _toSnake(featureName);
    final className = '${_toPascal(featureName)}FeaturePlugin';
    File('$dir/lib/src/plugin/${snake}_feature_plugin.dart').writeAsStringSync(
      '''
$_flutterMaterialImport
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

/// Orchestrator plugin for the $snake feature.
class $className extends ZuraffaPlugin {
  @override
  String get pluginId => '$snake';

  @override
  void registerDependencies(ZuraffaDIContainer di) {
    // TODO: register this feature's dependencies.
  }

  @override
  Map<String, ZuraffaRouteBuilder> get routes => {
    // TODO: expose this feature's routes.
  };
}
''',
    );
    if (verbose) print('  Created plugin orchestrator');
  }

  String _toSnake(String name) => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .replaceFirst(RegExp(r'^_'), '');

  String _toPascal(String name) => name
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join();
}
