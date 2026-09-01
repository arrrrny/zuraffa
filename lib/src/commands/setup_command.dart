import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../cli/services/corpus_importer.dart';
import '../cli/writers/tdd/app_module_writer.dart';
import '../cli/writers/tdd/dart_test_yaml_writer.dart';
import '../cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import '../cli/writers/tdd/smoke_test_writer.dart';
import '../cli/writers/tdd/tdd_example_writer.dart';
import '../cli/writers/tdd/tdd_profile_writer.dart';
import '../config/zfa_config.dart';
import '../core/branding/branding_writer.dart';
import '../core/dependencies/dependency_wirer.dart';
import '../utils/manifest_writer.dart';

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
///   `zfa setup <name> [--flutter|--dart] [--platforms=<csv>] [--org=com.example] [--specs=<dir>] [-- <flutter/dart create flags>] [--dry-run] [--force]`
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
      help:
          'Create a Flutter app (default). Pass `--platforms`/`--org`, or any '
          'other `flutter create` flag via a `--` separator — everything after '
          '`--` is forwarded verbatim to `flutter create`.',
    );
    argParser.addFlag(
      'dart',
      negatable: false,
      help: 'Create a pure Dart package (dart create -t package).',
    );
    argParser.addOption(
      'platforms',
      valueHelp: 'ios,android',
      help:
          'Comma-separated platforms for `flutter create` (forwarded as-is; '
          'ignored with --dart). For any other `flutter create` flag, use the '
          '`--` passthrough.',
    );
    argParser.addOption(
      'org',
      valueHelp: 'com.example',
      help:
          'Organization name for `flutter create` (e.g. com.example; ignored with --dart).',
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
      help:
          'Delete and recreate the target directory if it already exists '
          '(requires confirmation on a terminal).',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose output.',
    );
    argParser.addFlag(
      'no-git',
      negatable: false,
      help:
          'Skip git initialization of the created project '
          '(useful for CI/automation that manages its own VCS).',
    );
    // #358: pre-seed a URL scheme in the platform manifest files so
    // later `zfa route` commands only need to add paths.
    argParser.addOption(
      'deep-link-scheme',
      valueHelp: 'gozuzu',
      help:
          'Pre-seed a URL scheme in AndroidManifest.xml + Info.plist. '
          'Flutter-only (ignored with --dart).',
    );
    argParser.addOption(
      'deep-link-host',
      valueHelp: 'go.zuzu.dev',
      help:
          'Optional host for App Links (paired with '
          '--deep-link-scheme + --auto-verify).',
    );
    argParser.addFlag(
      'auto-verify',
      negatable: false,
      help:
          'Set android:autoVerify="true" on the intent-filter '
          '(App Links). Paired with --deep-link-scheme.',
    );
    argParser.addFlag(
      'tdd-example',
      negatable: false,
      help:
          'Emit an additional failing example test (test/tdd_example_test.dart) '
          'whose failure is an assertion failure (not a compile error), to '
          'demonstrate the red half of the red-green-refactor loop. See '
          'specs/041-tdd-setup-plugin/spec.md.',
    );
    // spec 050-corpus-import: import an extracted spec corpus into the
    // freshly scaffolded app so `zfa tdd plan/run/verify` can drive every
    // feature immediately (issue #627).
    argParser.addOption(
      'specs',
      valueHelp: 'dir',
      help:
          'Import an extracted spec corpus (a directory of feature '
          'directories, each containing spec.md) into the new app: copies '
          'every spec verbatim, creates per-feature tdd/ dirs, and emits '
          'the corpus manifest for batch driving. See '
          'specs/050-corpus-import/spec.md.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException('App name is required: zfa setup <name>');
    }
    final appName = rest.first;
    // Any tokens after the app name (typically passed via a `--` separator,
    // e.g. `zfa setup x --flutter -- --template plugin`) are forwarded verbatim
    // to `flutter create` / `dart create`. zfa owns only its own flags; every
    // other flag ports straight through to the underlying scaffolder.
    final passthrough = rest.length > 1 ? rest.sublist(1) : const <String>[];
    // zfa setup takes exactly one positional (the app name). Any further tokens
    // are pass-through flags for `flutter create` / `dart create` (introduced via
    // `--`). If they contain no flag-like token, the user likely passed a second
    // app name by mistake — fail fast instead of forwarding a stray word to the
    // scaffolder (which would surface an opaque `flutter create` error).
    if (passthrough.isNotEmpty && !passthrough.any((t) => t.startsWith('-'))) {
      usageException(
        'Unexpected extra argument(s): ${passthrough.join(' ')}. '
        'Pass `flutter create` / `dart create` flags after a `--` separator.',
      );
    }

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
    final noGit = argResults!['no-git'] as bool;
    final deepLinkScheme = argResults!['deep-link-scheme'] as String?;
    final deepLinkHost = argResults!['deep-link-host'] as String?;
    final autoVerify = argResults!['auto-verify'] as bool;
    final tddExample = argResults!['tdd-example'] as bool;
    final specsDir = argResults!['specs'] as String?;
    // With --specs the corpus import becomes step 7 of 8 (after branding
    // step 5a and the TDD baseline); without it the flow has 7 steps.
    final totalSteps = specsDir != null && specsDir.isNotEmpty ? 8 : 7;

    if (specsDir != null && specsDir.isNotEmpty) {
      const CorpusImporter().validateSource(specsDir);
    }

    if (_isInvalidAppName(appName)) {
      usageException(
        'Invalid app name: "$appName". Use snake_case (lowercase letters, digits, underscores).',
      );
    }

    // #364: validate the deep-link scheme/host before any files are
    // created. A malformed scheme would otherwise be written verbatim
    // into AndroidManifest.xml / Info.plist, corrupting the platform
    // build (ManifestWriter re-validates on every write path as the
    // final safety net, but fail fast here with a clean usage error).
    if (deepLinkScheme != null && deepLinkScheme.isNotEmpty) {
      try {
        ManifestWriter.validateScheme(deepLinkScheme);
        ManifestWriter.validateHost(deepLinkHost);
      } on ArgumentError catch (e) {
        usageException('Invalid deep-link scheme/host: ${e.message}');
      }
    } else if ((deepLinkHost != null && deepLinkHost.isNotEmpty) ||
        autoVerify) {
      print(
        '⚠️  --deep-link-host / --auto-verify are ignored without '
        '--deep-link-scheme.',
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
      passthrough: passthrough,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      totalSteps: totalSteps,
    );
    if (!created) return;

    // 1.5 Initialize git so the documented `git add .` next-step works.
    // Skipped with --no-git; idempotent when the project is already a repo.
    await initializeGit(
      projectRoot: appName,
      noGit: noGit,
      dryRun: dryRun,
      verbose: verbose,
    );

    // 2. Wire the standard zuraffa dependency set (dart pub add + overrides).
    print('\n[2/$totalSteps] Wiring zuraffa dependencies...');
    WireResult? wireResult;
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
      wireResult = await DependencyWirer.wire(
        isFlutter: isFlutter,
        dryRun: false,
        projectRoot: appName,
      );
    }

    // 3. Create build.yaml + domain directory structure.
    print('\n[3/$totalSteps] Creating build.yaml + domain structure...');
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
    print('\n[4/$totalSteps] Creating .zfa.json...');
    if (dryRun) {
      print('   Would create: $appName/.zfa.json');
    } else {
      await ZfaConfig.init(projectRoot: appName);
    }

    // 5. Pre-seed the deep-link URL scheme in the platform files
    //    (Flutter only — pure Dart packages have no manifest to write).
    if (isFlutter && deepLinkScheme != null && deepLinkScheme.isNotEmpty) {
      print('\n[5/$totalSteps] Pre-seeding deep-link scheme: $deepLinkScheme');
      await _seedDeepLinkScheme(
        projectRoot: appName,
        scheme: deepLinkScheme,
        host: deepLinkHost,
        autoVerify: autoVerify,
        dryRun: dryRun,
        verbose: verbose,
      );
    } else {
      print(
        '\n[5/$totalSteps] Skipping deep-link pre-seed '
        '(no --deep-link-scheme).',
      );
    }

    // 5a. Apply Zuraffa branding (spec 053).
    //     Flutter apps: icons, pubspec assets, remove flutter defaults.
    //     Dart packages: assets + README banner.
    print('\n[5a/$totalSteps] Applying Zuraffa branding...');
    final brandingWriter = BrandingWriter(zuraffaRoot: findZuraffaRoot());
    if (isFlutter) {
      await brandingWriter.writeFlutterBranding(
        projectRoot: appName,
        dryRun: dryRun,
        verbose: verbose,
      );
    } else {
      await brandingWriter.writeDartBranding(
        projectRoot: appName,
        dryRun: dryRun,
        verbose: verbose,
      );
    }
    if (!dryRun) {
      print('   Zuraffa branding applied.');
    } else {
      print('   (dry-run: no files written)');
    }

    // 6. TDD baseline (Part 1 of spec 041-tdd-setup-plugin).
    if (isFlutter) {
      print('\n[6/$totalSteps] Emitting TDD day-zero baseline...');
      await _emitTddBaseline(
        projectRoot: appName,
        appName: appName,
        tddExample: tddExample,
        dryRun: dryRun,
      );
    } else {
      print(
        '\n[6/$totalSteps] Skipping TDD baseline (pure-Dart project; use '
        '`zfa tdd init` separately).',
      );
    }

    // 7. Corpus import (spec 050-corpus-import): onboarding an extracted
    //    spec corpus so the loop can drive it from day zero.
    if (specsDir != null && specsDir.isNotEmpty) {
      print('\n[7/$totalSteps] Importing spec corpus from $specsDir...');
      final result = await const CorpusImporter().import(
        specsDir,
        projectRoot: appName,
        dryRun: dryRun,
      );
      for (final line in result.reportLines) {
        print('   $line');
      }
      print('   ${result.summaryLine}');
    }

    // 8. Summary.
    print('\n[$totalSteps/$totalSteps] Setup complete!');
    if (wireResult != null && !wireResult.isSuccess) {
      print(
        '\n⚠️  Some dependencies could not be wired automatically: '
        '${wireResult.failed.join(', ')}',
      );
      print('   Add them manually to pubspec.yaml and re-run `zfa init`.');
      // Non-zero exit so CI can distinguish a partial bootstrap.
      throw StateError('Some dependencies could not be wired automatically.');
    }

    // Next steps.
    print('\n── Next steps ──');
    print('   cd $appName');
    print(
      '   zfa entity create -n Product --field id:String --field name:String',
    );
    print('   zfa make Product --preset=crud --with=vpc,state,di,test');
    print('   zfa build');
    print(
      '   zfa app shell      # upgrade the day-zero app module with the generated DI + routes',
    );
    print('');
    if (isFlutter) {
      print('   Run the app:  flutter run');
      print(
        '   Run tests:    flutter test   (green day zero: '
        'test/bootstrap_smoke_test.dart asserts '
        '${AppModuleWriter.containerSymbolFor(appName)})',
      );
    } else {
      print('   Run tests:    dart test');
    }
  }

  /// Emits the Part-1 TDD day-zero baseline (spec 041-tdd-setup-plugin):
  /// `lib/app.dart` + bootstrap DI/routing indexes (issue #626),
  /// `test/bootstrap_smoke_test.dart`, `dart_test.yaml`,
  /// `.specify/memory/tdd-profile.md`, and the testing
  /// `dev_dependencies` merged into `pubspec.yaml`. Optionally also emits
  /// `test/tdd_example_test.dart` when [tddExample] is true.
  ///
  /// The app module + bootstrap indexes are what make day zero
  /// self-consistent (issue #626): the smoke test asserts
  /// `<AppName>Container` from `lib/app.dart`, and the bootstrap barrels
  /// let `zfa app shell` upgrade the minimal shell before the first
  /// entity exists. Every writer is skip-if-exists, so re-running setup
  /// never clobbers real generated DI/routing content.
  Future<void> _emitTddBaseline({
    required String projectRoot,
    required String appName,
    required bool tddExample,
    required bool dryRun,
  }) async {
    // Issue #626: the zfa-attributable app module the smoke test asserts.
    final appModulePath = await const AppModuleWriter(
      isFlutter: true,
    ).write(projectRoot, appName, dryRun: dryRun);
    if (appModulePath == null) {
      print('   ✓ lib/app.dart (already present)');
    } else {
      print('   ✓ $appModulePath (created)');
    }

    // Issue #626: bootstrap DI/routing barrels so `zfa app shell` runs
    // (and upgrades the minimal shell) before the first entity exists.
    final diIndexPath = await const BootstrapDiIndexWriter().write(
      projectRoot,
      dryRun: dryRun,
    );
    if (diIndexPath == null) {
      print('   ✓ lib/src/di/index.dart (already present)');
    } else {
      print('   ✓ $diIndexPath (bootstrap created)');
    }

    final routingIndexPath = await const BootstrapRoutingIndexWriter().write(
      projectRoot,
      dryRun: dryRun,
    );
    if (routingIndexPath == null) {
      print('   ✓ lib/src/routing/index.dart (already present)');
    } else {
      print('   ✓ $routingIndexPath (bootstrap created)');
    }

    final profilePath = await const TddProfileWriter().write(
      projectRoot,
      dryRun: dryRun,
    );
    if (profilePath == null) {
      print('   ✓ .specify/memory/tdd-profile.md (already present)');
    } else {
      print('   ✓ $profilePath (created)');
    }

    final yamlPath = await const DartTestYamlWriter().write(
      projectRoot,
      dryRun: dryRun,
    );
    if (yamlPath == null) {
      print('   ✓ dart_test.yaml (already present)');
    } else {
      print('   ✓ $yamlPath (created)');
    }

    final smokePath = await const SmokeTestWriter().write(
      projectRoot,
      appName,
      dryRun: dryRun,
    );
    if (smokePath == null) {
      print('   ✓ test/bootstrap_smoke_test.dart (already present)');
    } else {
      print('   ✓ $smokePath (created)');
    }

    final added = await PubspecDevDependenciesPatcher(
      isFlutter: true,
    ).ensure(projectRoot, dryRun: dryRun);
    if (added.isEmpty) {
      print('   ✓ pubspec.yaml dev_dependencies (already complete)');
    } else if (dryRun) {
      print(
        '   Would add to pubspec.yaml dev_dependencies: ${added.join(', ')}',
      );
    } else {
      print('   ✓ pubspec.yaml dev_dependencies (added: ${added.join(', ')})');
    }

    if (tddExample) {
      final examplePath = await const TddExampleWriter().write(
        projectRoot,
        appName,
        dryRun: dryRun,
      );
      if (examplePath == null) {
        print('   ✓ test/tdd_example_test.dart (already present)');
      } else {
        print('   ✓ $examplePath (created, --tdd-example)');
      }
    }
  }

  /// Writes the deep-link URL scheme registration to the newly created
  /// Flutter project's `AndroidManifest.xml` and `Info.plist` using the
  /// idempotent [ManifestWriter]. Safe to call multiple times — the
  /// writer skips schemes that are already declared.
  Future<void> _seedDeepLinkScheme({
    required String projectRoot,
    required String scheme,
    String? host,
    required bool autoVerify,
    required bool dryRun,
    required bool verbose,
  }) async {
    // Imported lazily so the `--dart` path (which never reaches here)
    // does not pay the import cost on pure-Dart setups. The route
    // plugin's ManifestWriter is a pure-Dart utility (no Flutter deps).
    // ignore: avoid_relative_lib_imports
    final writer = ManifestWriter();
    final androidPath = '$projectRoot/android/app/src/main/AndroidManifest.xml';
    final iosPath = '$projectRoot/ios/Runner/Info.plist';

    if (dryRun) {
      print(
        '   Would write Android intent-filter for "$scheme://" '
        'to $androidPath',
      );
      print('   Would write iOS CFBundleURLSchemes "$scheme" to $iosPath');
      return;
    }

    final androidFile = await writer.ensureAndroidIntentFilter(
      manifestPath: androidPath,
      scheme: scheme,
      host: host,
      autoVerify: autoVerify,
      verbose: verbose,
    );
    final iosFile = await writer.ensureIosUrlScheme(
      plistPath: iosPath,
      scheme: scheme,
      verbose: verbose,
    );

    if (androidFile != null) {
      print('   Android intent-filter for "$scheme://" registered.');
    } else {
      print(
        '   ⚠️  AndroidManifest.xml not modified '
        '(scheme already present, or file missing).',
      );
    }
    if (iosFile != null) {
      print('   iOS CFBundleURLSchemes for "$scheme" registered.');
    } else {
      print(
        '   ⚠️  Info.plist not modified '
        '(scheme already present, or file missing).',
      );
    }
  }

  /// Runs `flutter create` or `dart create` and returns whether the app was
  /// (or would be) created successfully.
  Future<bool> _createApp({
    required String appName,
    required bool isFlutter,
    required String? platforms,
    required String? org,
    required List<String> passthrough,
    required bool dryRun,
    required bool force,
    required bool verbose,
    required int totalSteps,
  }) async {
    final targetDir = Directory(appName);
    if (targetDir.existsSync()) {
      if (!force) {
        print('❌ Directory already exists: $appName');
        print('   Use --force to overwrite, or pick a different name.');
        return false;
      }
      if (!dryRun) {
        final absolutePath = targetDir.absolute.path;
        final entryCount = _countEntries(targetDir);
        print(
          '   ⚠️  --force will DELETE: $absolutePath ($entryCount entries)',
        );
        if (stdin.hasTerminal) {
          stdout.write('   Type "yes" to confirm deletion: ');
          final answer = stdin.readLineSync()?.trim().toLowerCase();
          if (answer != 'yes') {
            print('   Aborted. Target directory was NOT deleted.');
            return false;
          }
        }
        await targetDir.delete(recursive: true);
        print('   Removed existing $appName (--force)');
      } else {
        print('   Would remove existing $appName (--force)');
      }
    }

    if (isFlutter) {
      // `--platforms` is forwarded as-is when the user supplies it; otherwise
      // no --platforms flag is emitted and flutter create uses its own default.
      // The constitution's SPM-only rule holds out of the box on current Flutter
      // (iOS scaffolds with Swift Package Manager by default — CocoaPods removed).
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
      args.addAll(passthrough);
      if (dryRun) {
        print('\n[1/$totalSteps] Would run: flutter ${args.join(" ")}');
        return true;
      }
      print(
        '\n[1/$totalSteps] Creating Flutter app: $appName'
        '${platforms != null ? ' (platforms: $platforms)' : ''}'
        '${org != null ? ' (org: $org)' : ''}',
      );
      if (verbose) print('   Running: flutter ${args.join(" ")}');
      final result = await Process.run('flutter', args);
      if (result.exitCode != 0) {
        final err = result.stderr.toString().trim();
        final out = result.stdout.toString().trim();
        print('❌ flutter create failed (exit ${result.exitCode}).');
        if (err.isNotEmpty) print('   $err');
        if (out.isNotEmpty) print('   $out');
        print(
          '   Make sure Flutter is installed: https://docs.flutter.dev/get-started/install',
        );
        return false;
      }
      print('   Created Flutter app: $appName');
      return true;
    }

    // Pure Dart package.
    if ((platforms != null && platforms.isNotEmpty) ||
        (org != null && org.isNotEmpty)) {
      print(
        '   ⚠️  --platforms/--org are ignored with --dart '
        '(dart create has no equivalent).',
      );
    }
    final args = <String>['create', '-t', 'package', appName];
    args.addAll(passthrough);
    if (dryRun) {
      print('\n[1/$totalSteps] Would run: dart ${args.join(" ")}');
      return true;
    }
    print('\n[1/$totalSteps] Creating Dart package: $appName');
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

  /// Initializes a git repository in the created project so the documented
  /// `git add .` next-step works.
  ///
  /// - Skipped entirely with `--no-git` (CI/automation that manages its own VCS).
  /// - Idempotent: if `.git` already exists (e.g. `flutter create` initialized
  ///   one, or the target sits inside an existing repo) it does nothing.
  /// - Under `--dry-run` it only prints what it would do.
  /// - On a successful `git init` it also makes an initial commit so the
  ///   project starts clean. A failed `git commit` (e.g. no `user.email`
  ///   configured) is non-fatal — the repository still exists.
  Future<void> initializeGit({
    required String projectRoot,
    required bool noGit,
    required bool dryRun,
    required bool verbose,
  }) async {
    if (noGit) {
      print('   --no-git: skipping git initialization.');
      return;
    }
    final gitDir = Directory(path.join(projectRoot, '.git'));
    if (gitDir.existsSync()) {
      print('   git already initialized (skipping).');
      return;
    }
    if (dryRun) {
      print('   Would run: git init');
      return;
    }
    print('   Initializing git repository...');
    final initResult = await Process.run(
      'git',
      ['init'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (initResult.exitCode != 0) {
      final err = initResult.stderr.toString().trim();
      print('   ⚠️  git init failed (exit ${initResult.exitCode}): $err');
      print('   Initialize git manually: cd $projectRoot && git init');
      return;
    }
    await Process.run(
      'git',
      ['add', '-A'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    final commitResult = await Process.run(
      'git',
      ['commit', '-m', 'Initial commit (zfa setup)'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    if (commitResult.exitCode != 0) {
      final err = commitResult.stderr.toString().trim();
      if (verbose) {
        print('   (git commit skipped: ${err.split('\n').first})');
      }
    } else {
      print('   Created initial commit.');
    }
  }

  /// Counts all files and directories under [dir] (recursively).
  static int _countEntries(Directory dir) {
    var count = 0;
    for (final _ in dir.listSync(recursive: true)) {
      count++;
    }
    return count;
  }

  /// Minimal pubspec for dry-run preview (so findMissing has something to parse).
  String _dryRunPubspec(String name, bool isFlutter) {
    final flutterDep = isFlutter
        ? '''
dependencies:
  flutter:
    sdk: flutter
'''
        : '''
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
