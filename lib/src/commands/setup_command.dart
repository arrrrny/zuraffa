import 'dart:io';

import 'package:args/command_runner.dart';

import '../config/zfa_config.dart';
import '../core/dependencies/dependency_wirer.dart';

/// `zfa setup <name>` — Bootstrap a new Flutter/Dart app with the standard
/// zuraffa dependency set wired in.
///
/// This is the app-creation flow that `zfa init`/`zfa initialize` deliberately
/// does not provide: it runs `flutter create` (or `dart create`), wires the
/// zuraffa dependency set into the new project's pubspec.yaml, creates
/// `build.yaml` with zorphy builder registration, writes a default `.zfa.json`,
/// and scaffolds the domain directory structure.
///
/// Usage:
///   `zfa setup <name> [--flutter] [--dart] [--platforms=ios,macos] [--org=com.example] [--dry-run] [--force]`
class SetupCommand extends Command<void> {
  @override
  final String name = 'setup';

  @override
  final String description =
      'Bootstrap a new Flutter/Dart app with zuraffa dependencies wired in';

  @override
  String get invocation => 'zfa setup <name> [options]';

  SetupCommand() {
    argParser.addFlag(
      'flutter',
      negatable: false,
      help: 'Create a Flutter app (default). Passes --platforms through to flutter create.',
    );
    argParser.addFlag(
      'dart',
      negatable: false,
      help: 'Create a pure Dart package (dart create -t package).',
    );
    argParser.addOption(
      'platforms',
      valueHelp: 'ios,macos',
      help: 'Comma-separated platforms for `flutter create` (ignored with --dart).',
    );
    argParser.addOption(
      'org',
      valueHelp: 'com.example',
      help: 'Organization name for `flutter create` (e.g. com.example).',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview what would be created/wired without writing files.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite the target directory if it already exists.',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose output.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('App name is required: zfa setup <name>');
    }
    final appName = rest.first;

    final wantDart = argResults!['dart'] as bool;
    final wantFlutter = argResults!['flutter'] as bool;
    if (wantDart && wantFlutter) {
      usageException('Pass either --flutter or --dart, not both.');
    }
    final isFlutter = !wantDart; // default: Flutter

    final platforms = argResults!['platforms'] as String?;
    final org = argResults!['org'] as String?;
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;

    if (_isInvalidAppName(appName)) {
      usageException(
        'Invalid app name: "$appName". Use snake_case (lowercase letters, digits, underscores).',
      );
    }

    print('\nBootstrap: $appName (${isFlutter ? "Flutter" : "Dart"})');
    print('=' * 40);

    // 1. Create the app (flutter create / dart create).
    final created = await _createApp(
      appName: appName,
      isFlutter: isFlutter,
      platforms: platforms,
      org: org,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    if (!created) return;

    // 2. Wire the standard zuraffa dependency set (dart pub add + overrides).
    print('\n[2/5] Wiring zuraffa dependencies...');
    if (dryRun) {
      final missing = DependencyWirer.findMissing(
        _dryRunPubspec(appName, isFlutter),
        isFlutter: isFlutter,
      );
      print('   Would add ${missing.length} dependencies:');
      for (final spec in missing) {
        print('     • $spec');
      }
    } else {
      await DependencyWirer.wire(
        isFlutter: isFlutter,
        dryRun: false,
        projectRoot: appName,
      );
    }

    // 3. Create build.yaml + domain directory structure.
    print('\n[3/5] Creating build.yaml + domain structure...');
    if (dryRun) {
      await DependencyWirer.ensureProjectStructure(
        projectRoot: appName,
        dryRun: true,
      );
    } else {
      await DependencyWirer.ensureProjectStructure(
        projectRoot: appName,
        dryRun: false,
      );
      print('   Created: build.yaml + domain directories');
    }

    // 4. Create default .zfa.json in the new project.
    print('\n[4/5] Creating .zfa.json...');
    if (dryRun) {
      print('   Would create: $appName/.zfa.json');
    } else {
      await ZfaConfig.init(projectRoot: appName);
    }

    // 5. Summary.
    print('\n[5/5] Setup complete!');

    // Next steps.
    print('\n── Next steps ──');
    print('   cd $appName');
    print('   zfa entity create -n Product --field id:String --field name:String');
    print('   zfa make Product --preset=crud --with=vpc,state,di,test');
    print('   zfa build');
    print('');
    if (isFlutter) {
      print('   Run the app:  flutter run');
    } else {
      print('   Run tests:    dart test');
    }
  }

  /// Runs `flutter create` or `dart create` and returns whether the app was
  /// (or would be) created successfully.
  Future<bool> _createApp({
    required String appName,
    required bool isFlutter,
    required String? platforms,
    required String? org,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final targetDir = Directory(appName);
    if (targetDir.existsSync()) {
      if (!force) {
        print('❌ Directory already exists: $appName');
        print('   Use --force to overwrite, or pick a different name.');
        return false;
      }
      if (!dryRun) {
        await targetDir.delete(recursive: true);
        print('   Removed existing $appName (--force)');
      } else {
        print('   Would remove existing $appName (--force)');
      }
    }

    if (isFlutter) {
      final args = <String>['create', '--empty', appName];
      if (platforms != null && platforms.isNotEmpty) {
        for (final plat in platforms.split(',')) {
          final trimmed = plat.trim();
          if (trimmed.isNotEmpty) {
            args.addAll(['--platforms', trimmed]);
          }
        }
      }
      if (org != null && org.isNotEmpty) {
        args.addAll(['--org', org]);
      }
      if (dryRun) {
        print('\n[1/5] Would run: flutter ${args.join(" ")}');
        return true;
      }
      print('\n[1/5] Creating Flutter app: $appName'
          '${platforms != null ? ' (platforms: $platforms)' : ''}'
          '${org != null ? ' (org: $org)' : ''}');
      if (verbose) print('   Running: flutter ${args.join(" ")}');
      final result = await Process.run('flutter', args);
      if (result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        final out = result.stdout.toString().trim();
        print('❌ flutter create failed (exit ${result.exitCode}).');
        if (err.isNotEmpty) print('   $err');
        if (out.isNotEmpty) print('   $out');
        print('   Make sure Flutter is installed: https://docs.flutter.dev/get-started/install');
        return false;
      }
      print('   Created Flutter app: $appName');
      return true;
    }

    // Pure Dart package.
    final args = <String>['create', '-t', 'package', appName];
    if (dryRun) {
      print('\n[1/5] Would run: dart ${args.join(" ")}');
      return true;
    }
    print('\n[1/5] Creating Dart package: $appName');
    if (verbose) print('   Running: dart ${args.join(" ")}');
    final result = await Process.run('dart', args);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      final out = result.stdout.toString().trim();
      print('❌ dart create failed (exit ${result.exitCode}).');
      if (err.isNotEmpty) print('   $err');
      if (out.isNotEmpty) print('   $out');
      return false;
    }
    print('   Created Dart package: $appName');
    return true;
  }

  /// Minimal pubspec for dry-run preview (so findMissing has something to parse).
  String _dryRunPubspec(String name, bool isFlutter) {
    final flutterDep = isFlutter ? '''
dependencies:
  flutter:
    sdk: flutter
''' : '''
dependencies:
''';
    return '''
name: $name
environment:
  sdk: ^3.11.0
$flutterDep
''';
  }

  bool _isInvalidAppName(String name) {
    return !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }
}
