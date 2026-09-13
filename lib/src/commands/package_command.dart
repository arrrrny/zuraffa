import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/module/post_scaffold_gate.dart';
import '../package/package_scaffold.dart';
import '../package/plugin_scaffold.dart';

/// Thrown by [PackageCommand] for operator-fixable failures (invalid
/// names, existing targets, bad options). The CLI surfaces the message
/// with a non-zero exit code.
class PackageCommandException implements Exception {
  PackageCommandException(this.message);

  final String message;

  @override
  String toString() => 'PackageCommandException: $message';
}

/// `zfa package` — v6 package SDK commands (spec 025, issue #389).
///
/// Subcommands:
/// - `create <name>` — scaffold a new Zuraffa-native reusable package.
/// - `create-plugin <name>` — scaffold a publish-ready federated plugin
///   monorepo (issue #1604).
class PackageCommand extends Command<void> {
  @override
  String get name => 'package';

  @override
  String get description =>
      'Zuraffa-native package SDK (spec 025): create reusable packages '
      'that contribute architecture to consuming apps via auto-DI, runtime '
      'modules, and namespaced agent tools';

  PackageCommand() {
    addSubcommand(_PackageCreateCommand());
    addSubcommand(_PackageCreatePluginCommand());
  }
}

class _PackageCreateCommand extends Command<void> {
  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a new Zuraffa-native package scaffold (standard domain/data '
      'layout, runtime module, package registrar, test harness) that '
      'passes analysis and codegen with zero manual edits';

  @override
  String get invocation => 'zfa package create <name> [options]';

  _PackageCreateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Parent directory the package is created in '
          '(default: current directory).',
      defaultsTo: '.',
    );
    argParser.addOption(
      'description',
      help: 'Package description (pubspec.yaml + README).',
    );
    argParser.addOption(
      'zuraffa-path',
      help:
          'Pin zuraffa as a path dependency (local checkout) instead of the '
          'published version — for developing packages against a local '
          'zuraffa tree.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview the scaffold without writing files.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('Package name is required: zfa package create <name>');
    }
    final name = rest.first;
    if (rest.length > 1) {
      usageException(
        'Unexpected extra argument(s): ${rest.sublist(1).join(' ')}. '
        'Usage: zfa package create <name> [options]',
      );
    }

    final outputParent = argResults!['output'] as String;
    final description = argResults!['description'] as String?;
    final zuraffaPath = argResults!['zuraffa-path'] as String?;
    final dryRun = argResults!['dry-run'] as bool;

    print('\nZuraffa package: $name');
    print('=' * 40);

    try {
      final result = await PackageScaffold().create(
        name: name,
        outputParent: outputParent,
        description: description,
        zuraffaPath: zuraffaPath,
        dryRun: dryRun,
      );

      if (dryRun) {
        print(
          '\n[dry-run] Would create ${result.createdFiles.length} files '
          'in ${result.packagePath}:',
        );
        for (final rel in result.createdFiles) {
          print('   • $rel');
        }
        return;
      }

      print('   Created package: ${result.packagePath}');
      print('   Files: ${result.createdFiles.length}');
      print('\n── Next steps ──');
      print('   cd ${result.packagePath}');
      print('   dart pub get');
      print(
        '   zfa entity create -n Product --field id:String '
        '--field name:String',
      );
      print('   zfa make Product datasource repository usecase di');
      print('   zfa build');
      print('   dart test');
      print('');
      print('   See docs/writing_zuraffa_packages.md for the full guide.');
    } on PackageScaffoldException catch (e) {
      // FR-014: clear error, non-zero exit, existing content untouched.
      throw PackageCommandException(e.message);
    }
  }
}

class _PackageCreatePluginCommand extends Command<void> {
  @override
  String get name => 'create-plugin';

  /// `zfa package plugin <name>` — the spec-1601 alias for the same
  /// scaffold (FR-001), so the command reads as a sibling of `create`.
  @override
  List<String> get aliases => ['plugin'];

  @override
  String get description =>
      'Create a publish-ready federated plugin monorepo (app-facing '
      'package, shared platform envelope core, and android/ios/macos '
      'adapters with the zikzak publish pipeline) — the shape '
      'zuraffa_auth and zuraffa_permissions follow (issue #1604, #678)';

  @override
  String get invocation => 'zfa package create-plugin <name> [options]';

  _PackageCreatePluginCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Parent directory the monorepo is created in (default: current '
          'directory).',
      defaultsTo: '.',
    );
    argParser.addOption(
      'platforms',
      help:
          'Comma-separated adapter platforms to scaffold '
          '(android, ios, macos).',
      defaultsTo: 'android,ios,macos',
    );
    argParser.addOption(
      'description',
      help: 'Package description (pubspec.yaml + READMEs).',
    );
    argParser.addOption(
      'repo',
      help:
          'GitHub owner/name slug stamped into repository + issue_tracker '
          'metadata (default: arrrrny/<name>).',
    );
    argParser.addOption(
      'zuraffa-path',
      help:
          'Resolve zuraffa from a local checkout via dependency_overrides '
          'instead of the published version — for developing the plugin '
          'family against a local zuraffa tree.',
    );
    argParser.addFlag(
      'no-gate',
      help:
          'Skip the post-scaffold `dart pub get` + `dart analyze` gate per '
          'package.',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview the scaffold without writing files.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException(
        'Plugin name is required: zfa package create-plugin <name>',
      );
    }
    final name = rest.first;
    if (rest.length > 1) {
      usageException(
        'Unexpected extra argument(s): ${rest.sublist(1).join(' ')}. '
        'Usage: zfa package create-plugin <name> [options]',
      );
    }

    final platforms = _parsePlatforms(argResults!['platforms'] as String);
    final outputParent = argResults!['output'] as String;
    final description = argResults!['description'] as String?;
    final repository = argResults!['repo'] as String?;
    final zuraffaPath = argResults!['zuraffa-path'] as String?;
    final dryRun = argResults!['dry-run'] as bool;
    final runGate = !(argResults!['no-gate'] as bool);

    print(
      '\nZuraffa federated plugin: $name '
      '(${platforms.map((platform) => platform.label).join(', ')})',
    );
    print('=' * 40);

    try {
      final result = await PluginScaffold().create(
        name: name,
        outputParent: outputParent,
        platforms: platforms,
        description: description,
        repository: repository,
        zuraffaPath: zuraffaPath,
        dryRun: dryRun,
      );

      if (dryRun) {
        print(
          '\n[dry-run] Would create ${result.createdFiles.length} files '
          'in ${result.rootPath}:',
        );
        for (final rel in result.createdFiles) {
          print('   • $rel');
        }
        return;
      }

      print('   Created monorepo: ${result.rootPath}');
      print('   Packages: ${result.packagePaths.length}');
      print('   Files: ${result.createdFiles.length}');

      if (runGate) {
        print('\n── Post-scaffold gate (pub get + analyze per package) ──');
        for (final packagePath in result.packagePaths) {
          final gate = PostScaffoldGate(
            packageDir: packagePath,
            packageName: p.basename(packagePath),
          );
          final ok = await gate.run();
          if (!ok) exitCode = 1;
        }
      } else {
        print(
          '\n(skipping post-scaffold gate — run `dart pub get` + '
          '`dart analyze` in each package yourself)',
        );
      }

      print('\n── Next steps ──');
      print('   cd ${result.rootPath}');
      print(
        '   git init && git add -A && git commit -m '
        '"feat: initial federated scaffold"',
      );
      print('   dart test in each packages/<name> for the full green board');
      print(
        '   Publish: write release notes into CHANGELOG.md, then '
        './scripts/prepare_for_publish.sh <version>',
      );
      print('');
    } on PackageScaffoldException catch (e) {
      // FR-014: clear error, non-zero exit, existing content untouched.
      throw PackageCommandException(e.message);
    }
  }

  /// Delegates the --platforms contract to the engine's
  /// [PluginScaffold.platformsFromCsv] and surfaces failures as CLI usage
  /// errors (spec 1601 FR-005: one parser, one message set).
  List<PluginPlatform> _parsePlatforms(String raw) {
    try {
      return PluginScaffold.platformsFromCsv(raw).toList();
    } on PackageScaffoldException catch (e) {
      usageException(e.message);
    }
  }
}
