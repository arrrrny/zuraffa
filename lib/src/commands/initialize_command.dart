import 'dart:io';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import '../config/zfa_config.dart';
import '../core/dependencies/dependency_wirer.dart';
import '../utils/file_utils.dart';
import '../utils/string_utils.dart';

class InitializeCommand {
  static const String fixedEntityOutput = ZfaConfig.fixedEntityOutput;

  /// The parser used by [execute]. Exposed so tests exercise the real parser
  /// instead of a duplicated copy.
  static ArgParser buildParser() {
    return ArgParser()
      ..addOption(
        'entity',
        abbr: 'e',
        defaultsTo: 'Product',
        help: 'Entity name to generate (default: Product)',
      )
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: fixedEntityOutput,
        help:
            'Entity output directory (fixed to lib/src/domain/entities in v5; custom values are ignored)',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Overwrite existing files',
        negatable: false,
      )
      ..addFlag(
        'dry-run',
        help: 'Preview what would be generated without writing files',
        negatable: false,
      )
      ..addFlag(
        'deps-only',
        negatable: false,
        help:
            'Only wire zuraffa dependencies into pubspec.yaml; skip entity scaffolding.',
      )
      ..addFlag(
        'no-deps',
        negatable: false,
        help:
            'Skip dependency wiring; only scaffold the test entity (legacy behavior).',
      )
      ..addFlag(
        'dart',
        negatable: false,
        help:
            'Bootstrap a pure-Dart package in-place: if pubspec.yaml is missing, '
            'synthesize a minimal one, then wire the pure-Dart dependency set. '
            'Cannot be combined with --flutter.',
      )
      ..addFlag(
        'flutter',
        negatable: false,
        help:
            'Force the Flutter dependency set (default is auto-detect from '
            'pubspec.yaml). Cannot be combined with --dart.',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose output',
        negatable: false,
      )
      ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false);
  }

  Future<void> execute(List<String> args) async {
    final parser = buildParser();

    final results = parser.parse(args);

    if (results['help'] as bool) {
      _printHelp(parser);
      return;
    }

    final entityName = results['entity'] as String;
    final force = results['force'] as bool;
    final dryRun = results['dry-run'] as bool;
    final verbose = results['verbose'] as bool;
    final depsOnly = results['deps-only'] as bool;
    final noDeps = results['no-deps'] as bool;
    final dartMode = results['dart'] as bool;
    final flutterMode = results['flutter'] as bool;

    if (depsOnly && noDeps) {
      throw UsageException(
        '--deps-only and --no-deps are mutually exclusive.',
        parser.usage,
      );
    }
    if (dartMode && flutterMode) {
      throw UsageException(
        '--dart and --flutter are mutually exclusive.',
        parser.usage,
      );
    }

    // --- Dependency wiring (issue #275) -----------------------------------
    // `zfa init` / `zfa initialize` now wires the standard zuraffa dependency
    // set (build_runner, zuraffa[_flutter], zorphy_annotation, analyzer
    // override) into pubspec.yaml before scaffolding the test entity. This
    // makes the "only zfa commands" contract viable on a fresh project.
    if (!noDeps) {
      final pubspecFile = File('pubspec.yaml');
      var isFlutter = flutterMode;

      if (!pubspecFile.existsSync()) {
        if (!dartMode) {
          throw UsageException(
            'No pubspec.yaml found in current directory.\n'
            '   Run `zfa setup <name>` to create a new app, or re-run with '
            '`zfa init --dart` to bootstrap a pure-Dart package in-place.',
            parser.usage,
          );
        }
        // In-place pure-Dart bootstrap (issue #393): synthesize a minimal
        // pubspec.yaml from the directory name so an existing repository can
        // be initialized without creating an out-of-place subdirectory.
        if (dryRun) {
          print('🔍 Would create: pubspec.yaml '
              '(minimal pure-Dart package, name: '
              '${_validPackageName(path.basename(Directory.current.absolute.path)) ?? 'zuraffa_package'})');
          print('🔍 Would wire the pure-Dart dependency set '
              '(zuraffa, zorphy_annotation, json_annotation, build_runner …)');
          print('🔍 Dry-run: skipping dependency wiring '
              '(pubspec.yaml does not exist yet).');
          if (depsOnly) {
            print('🔍 Dry-run: would skip entity scaffolding (--deps-only).');
          }
          return;
        }
        pubspecFile.writeAsStringSync(synthesizeMinimalPubspec(
          path.basename(Directory.current.absolute.path),
        ));
        print('✅ Bootstrapped pure-Dart package in-place: pubspec.yaml');
        // A synthesized pubspec is never a Flutter project.
        isFlutter = false;
      } else if (!flutterMode && !dartMode) {
        isFlutter = DependencyWirer.isFlutterProject(
          pubspecFile.readAsStringSync(),
        );
      } else if (dartMode) {
        // Explicit --dart on an existing pubspec still forces the Dart set.
        isFlutter = false;
      }

      print(
        '🔧 Wiring zuraffa dependencies'
        '${isFlutter ? ' (Flutter project)' : ' (Dart project)'}...\n',
      );
      final wireResult = await DependencyWirer.wire(
        isFlutter: isFlutter,
        dryRun: dryRun,
        projectRoot: '.',
      );

      if (!wireResult.isSuccess) {
        print(
          '\n⚠️  Some dependencies could not be wired automatically: '
          '${wireResult.failed.join(', ')}',
        );
        print('   Add them manually and re-run `zfa init`.');
        // Non-zero exit so CI can distinguish a partial wiring.
        throw StateError('Some dependencies could not be wired automatically.');
      }

      // Ensure build.yaml + domain directory structure exist.
      print('');
      await DependencyWirer.ensureProjectStructure(dryRun: dryRun);

      // Ensure .zfa.json exists.
      final config = ZfaConfig.load();
      if (config == null) {
        print('');
        if (dryRun) {
          print('🔍 Would create: .zfa.json (default configuration)');
        } else {
          await ZfaConfig.init();
        }
      }
      print('');
    }

    if (depsOnly) {
      if (dryRun) {
        print('🔍 Dry-run: would skip entity scaffolding (--deps-only).');
      } else {
        print(
          '✅ Dependencies wired. Skipping entity scaffolding (--deps-only).',
        );
      }
      print('\n📝 Next steps:');
      print(
        '   • Create an entity:  zfa entity create -n Product --field id:String',
      );
      print(
        '   • Generate feature:  zfa make Product --preset=crud --with=vpc,state,di,test',
      );
      return;
    }

    // --- Entity scaffolding (existing behavior) ---------------------------
    final entitySnake = StringUtils.camelToSnake(entityName);

    // Create entity directory path
    final entityDir = path.join(fixedEntityOutput, entitySnake);
    final entityFile = path.join(entityDir, '$entitySnake.dart');

    // Generate entity content
    final content = _generateEntityContent(entityName);

    try {
      final result = await FileUtils.writeFile(
        entityFile,
        content,
        'entity',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
      );

      if (dryRun) {
        print('✓ Would generate: ${result.path}');
      } else {
        print('✓ Generated: ${result.path}');
      }

      print('\n📝 Next steps:');
      print('   • Generate complete feature:');
      print('     zfa make $entityName --preset=crud --with=vpc,state,di,test');
      print('   • Or generate with adaptive layouts:');
      print(
        '     zfa make $entityName --preset=adaptive-feature --methods=get,getList',
      );
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  void _printHelp(ArgParser parser) {
    print('''
Initialize a project for Zuraffa: wire dependencies + scaffold a test entity

USAGE:
  zfa initialize [options]
  zfa init [options]

OPTIONS:
${parser.usage}

EXAMPLES:
  zfa initialize                           # Wire deps + generate Product entity
  zfa init                                 # Same as above (alias)
  zfa initialize --entity=User             # Wire deps + generate User entity
  zfa init --deps-only                     # Wire deps only, skip entity
  zfa init --no-deps -e Order              # Skip deps, only scaffold entity
  zfa initialize --dart                    # Bootstrap pure-Dart package in-place
  zfa init --dart --deps-only              # In-place bootstrap, no test entity
  zfa initialize --dry-run                 # Preview without writing files

DESCRIPTION:
  Wires the standard zuraffa dependency set (build_runner, zuraffa/zuraffa_flutter,
  zorphy_annotation, analyzer override) into pubspec.yaml, creates build.yaml with
  zorphy builder registration, ensures .zfa.json exists, then creates a sample
  entity with common fields under lib/src/domain/entities.

  For a brand-new app, prefer `zfa setup <name>` which runs flutter/dart create
  AND wires dependencies in one step. To initialize an EXISTING pure-Dart
  repository that has no pubspec.yaml yet, use `zfa init --dart` (synthesizes a
  minimal pubspec.yaml in-place from the directory name).

  Use --deps-only to wire dependencies without scaffolding an entity.
  Use --no-deps to scaffold only the entity (legacy behavior).
''');
  }

  String _generateEntityContent(String entityName) {
    return '''
import 'package:zorphy_annotation/zorphy.dart';

part '$entityName.zorphy.dart';

@Zorphy(
  json: true,
  copyWith: true,
  equal: true,
)
class $entityName with _\$$entityName {
  const $entityName._();

  const factory $entityName({
    @Default('') String id,
    required String name,
    String? description,
    required double price,
    String? category,
    @Default(true) bool isActive,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _\$$entityName${entityName}Impl;

  factory $entityName.fromJson(Map<String, dynamic> json) =>
      _\$${entityName}FromJson(json);
}
''';
  }

  /// Returns [dirName] if it is a valid Dart package name (lowercase
  /// snake_case, digits, underscores; not starting with a digit), else null.
  String? _validPackageName(String dirName) {
    final name = dirName.trim().toLowerCase().replaceAll('-', '_');
    final valid = RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
    return valid ? name : null;
  }

  /// Minimal pure-Dart pubspec.yaml content for an in-place bootstrap
  /// (issue #393). The package name is derived from [dirName]; invalid
  /// names fall back to `zuraffa_package`.
  static String synthesizeMinimalPubspec(String dirName) {
    final packageName = _validPackageNameStatic(dirName) ?? 'zuraffa_package';
    return 'name: $packageName\n'
        'description: A Zuraffa package (bootstrapped by zfa init --dart).\n'
        'publish_to: none\n'
        '\n'
        'environment:\n'
        '  sdk: ^3.0.0\n';
  }

  static String? _validPackageNameStatic(String dirName) {
    final name =
        dirName.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    final valid = RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
    return valid ? name : null;
  }
}
