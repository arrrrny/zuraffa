/// `zfa bone` command tree with generate/export/validate subcommands.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'generators/bone_exporter.dart';
import 'generators/bone_generator.dart';
import 'generators/di_choice_resolver.dart';
import 'generators/spec_reader.dart';
import 'models/bone.dart';

/// The `zfa bone` command.
class BoneCommand extends Command<void> {
  /// Creates the [BoneCommand].
  ///
  /// [specsRoot] is the root directory for feature specs (default: CWD).
  /// [featureJsonPath] is the path to `.specify/feature.json` for default
  /// feature resolution (default: `<specsRoot>/.specify/feature.json`).
  BoneCommand({
    BoneGenerator? generator,
    this.specsRoot = '.',
    String? featureJsonPath,
  }) : generator = generator ?? BoneGenerator(),
       featureJsonPath =
           featureJsonPath ?? p.join(specsRoot, '.specify', 'feature.json');

  /// The bone generator for the generate subcommand.
  final BoneGenerator generator;

  /// Root directory for feature specs.
  final String specsRoot;

  /// Path to `.specify/feature.json` for default feature resolution.
  final String featureJsonPath;

  @override
  String get name => 'bone';

  @override
  String get description =>
      'Generate, export, and validate feature bones for delegated agent builds.';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  static const _usage = '''
usage: zfa bone SUBCOMMAND [options]

subcommands:
  generate [<slug>]  Generate the bone for the named feature (or active feature)
  export <slug>      Package a generated bone into a tar.gz artifact
  validate <slug>    Re-check a bone for self-containment and staleness

generate options:
  --spec <path>            Override the source spec path (default: specs/<slug>/spec.md)
  --output <dir>           Bone root directory (default: .zfa/bones)
  --di <mock|firebase|auto>  Data backend wiring (default: auto)
  --flutter                Include pubspec.yaml + runnable lib/main.dart + page
  --include-deps           Inline the minimal transitive shared-entity set
  --export                 Also package the bone as <feature>-<di>.tar.gz''';

  @override
  Future<void> run() async {
    final args = argResults!.arguments;
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      print(_usage);
      return;
    }

    final subcommand = args.first;

    switch (subcommand) {
      case 'generate':
        await _generate(args.sublist(1));
      case 'export':
        await _export(args.sublist(1));
      case 'validate':
        await _validate(args.sublist(1));
      default:
        print('Unknown bone subcommand: $subcommand');
        print(_usage);
    }
  }

  /// Resolves the active feature slug from `.specify/feature.json`.
  ///
  /// Returns the slug extracted from the `feature_directory` key
  /// (e.g. `"specs/020-foo/"` → `"020-foo"`).
  /// Returns null if the file is missing or malformed.
  String? _resolveActiveFeature() {
    final file = File(featureJsonPath);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final dir = json['feature_directory'] as String?;
      if (dir == null) return null;
      // Strip trailing slash and "specs/" prefix.
      final cleaned = dir.endsWith('/')
          ? dir.substring(0, dir.length - 1)
          : dir;
      final slug = cleaned.startsWith('specs/')
          ? cleaned.substring('specs/'.length)
          : cleaned;
      return slug.isEmpty ? null : slug;
    } catch (_) {
      return null;
    }
  }

  Future<void> _generate(List<String> rest) async {
    final parser = ArgParser()
      ..addOption('spec', help: 'Override the source spec path')
      ..addOption(
        'output',
        help: 'Bone root directory',
        defaultsTo: '.zfa/bones',
      )
      ..addOption(
        'di',
        help: 'Data backend wiring',
        allowed: ['mock', 'firebase', 'auto'],
        defaultsTo: 'auto',
      )
      ..addFlag(
        'flutter',
        help: 'Include pubspec.yaml + runnable lib/main.dart + page',
        negatable: false,
      )
      ..addFlag(
        'include-deps',
        help: 'Inline the minimal transitive shared-entity set',
        negatable: false,
      )
      ..addFlag(
        'export',
        help: 'Also package the bone as <feature>-<di>.tar.gz',
        negatable: false,
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      print(e.message);
      print(_usage);
      exitCode = 1;
      return;
    }

    // Resolve slug: positional arg > feature.json > error.
    String? slug;
    if (results.rest.isNotEmpty) {
      slug = results.rest.first;
    } else {
      slug = _resolveActiveFeature();
    }

    if (slug == null) {
      print(
        'Missing feature slug. Provide a slug or set .specify/feature.json.',
      );
      print(_usage);
      return;
    }

    final specPath =
        results['spec'] as String? ??
        p.join(specsRoot, 'specs', slug, 'spec.md');
    final outputDir = results['output'] as String;
    final diRequested = results['di'] as String;
    final flutter = results['flutter'] as bool;
    final includeDeps = results['include-deps'] as bool;
    final export = results['export'] as bool;

    final specFile = File(specPath);
    if (!await specFile.exists()) {
      print('Error: spec not found: $specPath');
      exitCode = 1;
      return;
    }

    // Resolve the DI choice (042): flag value or auto-detection from the
    // working project's DI config.
    final DiChoice diChoice;
    try {
      diChoice = DiChoiceResolver().resolve(
        requested: diRequested,
        projectRoot: specsRoot,
      );
    } on ArgumentError catch (e) {
      print(e);
      print(_usage);
      exitCode = 1;
      return;
    }

    try {
      final boneDir = await generator.generate(
        specPath: specFile,
        outputDir: outputDir,
        specsRoot: specsRoot,
        diChoice: diChoice,
        flutter: flutter,
        includeDeps: includeDeps,
      );
      print(boneDir);

      if (export) {
        final artifactPath = p.join(
          outputDir,
          '$slug-${diChoice.backendName}.tar.gz',
        );
        final exporter = BoneExporter();
        await exporter.export(Directory(boneDir), artifactPath);
        print(artifactPath);
      }
    } on BoneGenerationError catch (e) {
      print('Error: $e');
      // Ensure no partial output.
      final boneDir = '$outputDir/$slug';
      final dir = Directory(boneDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      exitCode = 1;
    }
  }

  Future<void> _export(List<String> rest) async {
    final parser = ArgParser()
      ..addOption('output', help: 'Output path for the tar.gz', defaultsTo: '')
      ..addOption(
        'bones-dir',
        help: 'Bone root directory (default: .zfa/bones)',
        defaultsTo: '.zfa/bones',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      print(e.message);
      print(_usage);
      return;
    }

    if (results.rest.isEmpty) {
      print('Missing feature slug');
      print(_usage);
      return;
    }

    final slug = results.rest.first;
    final bonesDir = results['bones-dir'] as String;
    final boneDir = p.join(bonesDir, slug);

    if (!await Directory(boneDir).exists()) {
      print(
        'Error: bone not generated for "$slug". Run "zfa bone generate $slug" first.',
      );
      exitCode = 1;
      return;
    }

    final outputPath = (results['output'] as String).isEmpty
        ? '$boneDir.tar.gz'
        : results['output'] as String;

    try {
      final exporter = BoneExporter();
      await exporter.export(Directory(boneDir), outputPath);
      print(outputPath);
    } catch (e) {
      print('Error: $e');
      exitCode = 1;
    }
  }

  Future<void> _validate(List<String> rest) async {
    final parser = ArgParser()
      ..addOption(
        'bones-dir',
        help: 'Bone root directory (default: .zfa/bones)',
        defaultsTo: '.zfa/bones',
      );

    final ArgResults results;
    try {
      results = parser.parse(rest);
    } on FormatException catch (e) {
      print(e.message);
      print(_usage);
      return;
    }

    if (results.rest.isEmpty) {
      print('Missing feature slug');
      print(_usage);
      return;
    }

    final slug = results.rest.first;
    final bonesDir = results['bones-dir'] as String;
    final boneDir = p.join(bonesDir, slug);

    if (!await Directory(boneDir).exists()) {
      print('Error: bone not found at $boneDir. Generate it first.');
      exitCode = 1;
      return;
    }

    final manifestFile = File(p.join(boneDir, 'bone.yaml'));
    if (!await manifestFile.exists()) {
      print('Error: bone.yaml not found in $boneDir.');
      exitCode = 1;
      return;
    }

    final manifestContent = await manifestFile.readAsString();

    // Check staleness: spec_version hash must match the current spec.
    final specPath = p.join(specsRoot, 'specs', slug, 'spec.md');
    final specFile = File(specPath);
    if (await specFile.exists()) {
      final reader = SpecReader();
      final specResult = reader.read(specFile);
      final expectedVersion = 'sha256:${specResult.specVersion}';
      if (!manifestContent.contains(expectedVersion)) {
        print(
          'Error: bone is stale. Source spec has changed since generation.',
        );
        print('Expected spec_version: $expectedVersion');
        exitCode = 1;
        return;
      }
    }

    // Self-containment check: scan Dart imports.
    final boneDirectory = Directory(boneDir);
    final dartFiles = boneDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Extract declared dependency bone slugs (snake_case) from bone.yaml.
    final declaredDeps = _extractDependencySlugs(manifestContent);

    // 042: packages declared in the bone's own pubspec.yaml are resolvable
    // for this bone (flutter, flutter_test) — accept them as imports.
    final pubspecPackages = _extractPubspecPackages(boneDir);

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final imports = RegExp(
        r"^import\s+'([^']+)';",
        multiLine: true,
      ).allMatches(content);

      for (final match in imports) {
        final importPath = match.group(1)!;
        if (importPath.startsWith('dart:')) continue;
        if (importPath.startsWith('package:')) {
          // package: imports are legal only when the package segment
          // (first path component after the colon) matches a declared
          // dependency bone slug or a dependency of the bone's own
          // pubspec.yaml.
          final pkgName = importPath
              .split('/')
              .first
              .substring('package:'.length);
          if (!declaredDeps.contains(pkgName) &&
              !pubspecPackages.contains(pkgName)) {
            print(
              'Error: undeclared package import "$pkgName" in '
              '${p.relative(file.path, from: boneDir)}',
            );
            exitCode = 1;
            return;
          }
          continue;
        }

        final resolved = p.normalize(p.join(p.dirname(file.path), importPath));
        if (!await File(resolved).exists()) {
          print(
            'Error: broken import "$importPath" in ${p.relative(file.path, from: boneDir)}',
          );
          exitCode = 1;
          return;
        }
      }
    }

    print('OK: bone "$slug" is valid.');
  }

  /// Extracts declared dependency bone slugs from a bone.yaml manifest string.
  ///
  /// Returns a set of snake_case bone names from the `dependencies:` section.
  Set<String> _extractDependencySlugs(String manifestContent) {
    final deps = <String>{};
    try {
      final yaml = loadYaml(manifestContent);
      if (yaml is Map && yaml['dependencies'] is List) {
        for (final dep in yaml['dependencies'] as List) {
          if (dep is Map && dep['bone'] is String) {
            deps.add(dep['bone'] as String);
          }
        }
      }
    } catch (_) {
      // Malformed YAML — no deps to check against, all package: imports fail.
    }
    return deps;
  }

  /// Extracts the package names declared in the bone's own pubspec.yaml
  /// (042): both `dependencies:` and `dev_dependencies:` top-level keys.
  Set<String> _extractPubspecPackages(String boneDir) {
    final packages = <String>{};
    final pubspec = File(p.join(boneDir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return packages;
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is! Map) return packages;
      for (final section in ['dependencies', 'dev_dependencies']) {
        final deps = yaml[section];
        if (deps is Map) {
          packages.addAll(deps.keys.cast<String>());
        }
      }
    } catch (_) {
      // Malformed pubspec — contribute no packages.
    }
    return packages;
  }
}
