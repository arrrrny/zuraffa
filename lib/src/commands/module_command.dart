import 'dart:io';

import 'package:args/command_runner.dart';

/// CLI command that scaffolds a new Zuraffa feature package.
///
/// Usage: `zfa module <FeatureName> [options]`
///
/// Creates a directory `zuraffa_feature_<name>/` with:
/// - pubspec.yaml (depends on zuraffa)
/// - analysis_options.yaml
/// - lib/src/{datasource,repository,usecase,controller,state,view,plugin}/
/// - test/
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
      return;
    }

    final featureName = rest.first;
    final outputDir = argResults!['output'] as String;
    final dryRun = argResults!['dry-run'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final packageName = 'zuraffa_feature_${_toSnake(featureName)}';
    final packageDir = '$outputDir/$packageName';

    if (verbose) {
      print('Scaffolding feature package: $packageName');
      print('  Directory: $packageDir');
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
      _writeBarrel(packageDir, packageName);
      _writePlaceholderFiles(packageDir, verbose);
    }

    print('  Feature package $packageName scaffolded successfully.');
  }

  void _writePubspec(String dir, String packageName, bool verbose) {
    final content = '''
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
    path: ../

flutter:
  uses-material-design: true

dependency_overrides:
  meta: ^1.19.0
  analyzer: 14.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
''';
    File('$dir/pubspec.yaml').writeAsStringSync(content);
    if (verbose) print('  Created $dir/pubspec.yaml');
  }

  void _writeAnalysisOptions(String dir) {
    File('$dir/analysis_options.yaml')
        .writeAsStringSync('include: package:flutter_lints/flutter.yaml\n');
  }

  void _writeBarrel(String dir, String packageName) {
    final snake = _toSnake(packageName);
    File('$dir/lib/$snake.dart').writeAsStringSync(
      '/// Feature package: $packageName\nlibrary;\n\n'
      "export 'src/plugin/${snake}_feature_plugin.dart';\n",
    );
  }

  void _writePlaceholderFiles(String dir, bool verbose) {
    final snake = _toSnake(dir.split('/').last);
    final className = '${_toPascal(snake)}FeaturePlugin';
    File('$dir/lib/src/plugin/${snake}_feature_plugin.dart')
        .writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

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
''');
    if (verbose) print('  Created plugin orchestrator');
  }

  String _toSnake(String name) => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase}')
      .replaceFirst(RegExp(r'^_'), '');

  String _toPascal(String name) => name
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join();
}
