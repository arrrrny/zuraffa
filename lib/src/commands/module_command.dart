import 'dart:io';

import 'package:args/command_runner.dart';
import '../cli/exit_protocol.dart';

import '../core/context/file_system.dart';
import '../core/generator_options.dart';
import '../core/project/project_root.dart';
import '../models/generator_config.dart';
import '../plugins/module/builders/module_orchestrator_builder.dart';
import '../core/module/post_scaffold_gate.dart';
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
    // Issue #1149 (kill list — module merge): post-scaffold honesty gate.
    // After scaffolding, run `dart pub get` + `dart analyze` inside the
    // new package and surface real failures. --no-gate opts out.
    argParser.addFlag(
      'no-gate',
      negatable: false,
      help: 'Skip the post-scaffold `dart pub get` + `dart analyze` gate',
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
      exitCode = ExitProtocol.usage;
      return;
    }

    final featureName = rest.first;
    final outputDir = argResults!['output'] as String;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final runGate = !(argResults!['no-gate'] as bool);

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
      // Bug #1139 (exit-code sweep, #856 pattern): refusing to clobber an
      // existing package without --force is a failure — never a lying
      // exit 0.
      print('Error: Package directory already exists: $packageDir');
      print('Use --force to overwrite existing files.');
      exitCode = 1;
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
      // Issue #1149 (kill list — module merge): the FeaturePlugin class
      // is emitted by the ONE surviving generator
      // (ModuleOrchestratorBuilder, shared with `zfa make --with=module`)
      // instead of a second drifting string-template copy.
      await _writePluginOrchestrator(packageDir, featureName, verbose);
    }

    print('  Feature package $packageName scaffolded successfully.');

    if (!dryRun && runGate) {
      final gate = PostScaffoldGate(
        packageDir: packageDir,
        packageName: packageName,
      );
      final gateOk = await gate.run();
      if (!gateOk) exitCode = 1;
    }
  }

  /// Emits the FeaturePlugin orchestrator through
  /// [ModuleOrchestratorBuilder] — the single generator shared with the
  /// `zfa make --with=module` pipeline (issue #1149). The builder persists
  /// through FileUtils.writeFile with force so re-scaffolding works.
  Future<void> _writePluginOrchestrator(
    String dir,
    String featureName,
    bool verbose,
  ) async {
    final builder = ModuleOrchestratorBuilder(
      outputDir: '$dir/lib/src',
      options: const GeneratorOptions(force: true),
    );
    final files = await builder.generate(
      GeneratorConfig(
        name: featureName,
        outputDir: '$dir/lib/src',
        force: true,
      ),
    );
    for (final file in files) {
      if (verbose) print('  Created plugin orchestrator: ${file.path}');
    }
  }

  /// Runs the post-scaffold honesty gate (issue #1149) via
  /// [PostScaffoldGate]: `dart pub get` then `dart analyze` inside the
  /// scaffolded package. Failures propagate as exit 1; --no-gate skips.
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

  String _toSnake(String name) => name
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .replaceFirst(RegExp(r'^_'), '');
}
