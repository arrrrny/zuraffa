import 'package:args/command_runner.dart';

import '../package/package_scaffold.dart';

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
