import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../config/zfa_config.dart';

import '../core/context/file_system.dart';
import '../models/generated_file.dart';
import '../plugins/app_shell/builders/app_shell_builder.dart';
import '../utils/file_utils.dart';

/// `zfa app shell` — generates the app-shell glue files for a zfa-only
/// Flutter app.
///
/// Emits three files that wire the generated DI tree and routing tree
/// into a runnable Flutter app:
///
///  * `lib/main.dart` — `void main()` → `await setupDependencies()` →
///    `runApp(const MyApp())`.
///  * `<outputDir>/app/my_app.dart` — `MyApp` widget (`MaterialApp.router`
///    bound to [appRouter]).
///  * `<outputDir>/routing/app_router.dart` —
///    `final GoRouter appRouter = GoRouter(routes: getAllRoutes());`.
///
/// The `app/` and `routing/` glue files land under `--output` (default
/// `lib/src`, and it must be under `lib/` so `main.dart`'s `package:`
/// imports resolve).
///
/// This closes the last hand-written gap in the zfa-only workflow:
/// after `zfa setup` + `zfa entity create` + `zfa make` + `zfa build`
/// + this command, a full app compiles and runs with zero hand-written
/// Dart. See issue #345.
///
/// The command refuses to overwrite an existing `lib/main.dart` unless
/// `--force` is passed (user apps often customize main with error
/// zones, observability, or `WidgetsFlutterBinding.ensureInitialized()`
/// calls). `my_app.dart` and `app_router.dart` are pure glue and are
/// always overwritten.
class AppShellCommand extends Command<void> {
  AppShellCommand({FileSystem? fileSystem, AppShellBuilder? builder})
    : _fileSystem = fileSystem ?? const DefaultFileSystem(),
      _builder = builder ?? const AppShellBuilder() {
    argParser
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing')
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite an existing lib/main.dart',
      )
      ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Verbose output')
      ..addFlag(
        'mock',
        negatable: false,
        help:
            'Emit a mock-mode hint in main.dart (the mock-vs-real decision '
            'is made at DI-generation time via `zfa di <Entity> --use-mock`; '
            'this flag only adds a documenting comment).',
      )
      ..addFlag(
        'xray',
        negatable: false,
        help: 'Wire the X-Ray bridge server into main.dart (debug mode) and wrap MyApp in XRayScope. Defaults to the xray key in .zfa.json plugins.defaults. Emits the <outputDir>/xray/xray_decks.dart barrel so the import in main.dart always resolves.',
      )
      ..addOption(
        'title',
        help: 'Application title (default: "Zuraffa App")',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output directory (project-root-relative, must be under lib/) '
            'for the src/ glue files (default: lib/src; the main.dart '
            'entrypoint always lands at lib/main.dart).',
        defaultsTo: 'lib/src',
      );
  }

  final FileSystem _fileSystem;
  final AppShellBuilder _builder;

  @override
  String get name => 'shell';

  @override
  String get description =>
      'Generate the app shell (main.dart + MyApp + app_router.dart)';

  @override
  String get invocation => 'zfa app shell [options]';

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final force = argResults!['force'] as bool;
    final verbose = argResults!['verbose'] as bool;
    final mock = argResults!['mock'] as bool;
    final title = argResults!['title'] as String?;
    final outputDir = argResults!['output'] as String;
    final xrayFlag = argResults!['xray'] as bool? ?? false;

    // --output must live under lib/: main.dart (always at lib/main.dart)
    // imports the glue files via package: URIs, which only resolve inside
    // lib/. Reject anything else instead of silently emitting a main.dart
    // whose imports point at files that were never written.
    final normalizedOutput = p.normalize(outputDir);
    final insideLib =
        normalizedOutput == 'lib' || p.isWithin('lib', normalizedOutput);
    if (!insideLib) {
      throw AppShellException(
        'Invalid --output "$outputDir": the src/ glue files must live '
        'under lib/ so main.dart can import them via package: URIs.\n'
        '   Use a path like "lib/src" (default) or "lib/custom".',
      );
    }

    final projectRoot = Directory.current.path;
    final config = ZfaConfig.load(projectRoot: projectRoot);
    final xray = xrayFlag || (config?.xrayByDefault ?? false);
    final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    if (!await _fileSystem.exists(pubspecPath) && !pubspecFile.existsSync()) {
      throw AppShellException(
        'No pubspec.yaml found at $pubspecPath.\n'
        '   Run `zfa app shell` from the root of a Flutter/Dart project.',
      );
    }

    final pubspecContent = await _fileSystem.read(pubspecPath);
    final appName = AppShellBuilder.parseAppName(pubspecContent);
    if (appName == null || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(appName)) {
      throw AppShellException(
        'Could not parse a valid Dart package name from $pubspecPath.\n'
        '   Expected a top-level `name: <identifier>` field.',
      );
    }

    // Validate the generated DI + routing barrels exist. The shell cannot
    // compile without setupDependencies() and getAllRoutes(); pointing the
    // user at the right `zfa` command is the actionable error.
    final diIndexPath = p.join(outputDir, 'di', 'index.dart');
    final routingIndexPath = p.join(outputDir, 'routing', 'index.dart');

    final diMissing = !await _fileSystem.exists(diIndexPath) ||
        !(await _fileSystem.read(diIndexPath)).contains('setupDependencies');
    if (diMissing) {
      throw AppShellException(
        '$diIndexPath does not export setupDependencies().\n'
        '   Generate DI first:  zfa di <Entity>   (or `zfa make <Entity> '
        '--with=di`).',
      );
    }

    final routingMissing = !await _fileSystem.exists(routingIndexPath) ||
        !(await _fileSystem.read(routingIndexPath)).contains('getAllRoutes');
    if (routingMissing) {
      throw AppShellException(
        '$routingIndexPath does not export getAllRoutes().\n'
        '   Generate routes first:  zfa route <Entity>   (or `zfa make '
        '<Entity> --with=route`).',
      );
    }

    if (verbose) {
      print('🚀 Generating app shell for package "$appName"...');
      print('   output:  $outputDir');
      print('   title:   ${title ?? "Zuraffa App"}');
      print('   mock:    $mock');
    }

    final files = <GeneratedFile>[];

    // 1. lib/src/routing/app_router.dart — pure glue, always overwritten.
    final appRouterPath = p.join(outputDir, 'routing', 'app_router.dart');
    files.add(
      await FileUtils.writeFile(
        appRouterPath,
        _builder.buildAppRouter(),
        'app_router',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        fileSystem: _fileSystem,
      ),
    );

    // 2. lib/src/app/my_app.dart — pure glue, always overwritten.
    final myAppPath = p.join(outputDir, 'app', 'my_app.dart');
    files.add(
      await FileUtils.writeFile(
        myAppPath,
        _builder.buildMyApp(title: title, xray: xray),
        'my_app',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        fileSystem: _fileSystem,
      ),
    );

    // 2b. <outputDir>/xray/xray_decks.dart - X-Ray Control Deck
    // registration barrel. Only emitted when --xray is set so the
    // import in main.dart resolves. Existing barrels are preserved
    // unless --force is passed (zfa xray deck appends to it over
    // time and we must not clobber those registrations).
    if (xray) {
      final xrayDecksPath = p.join(outputDir, 'xray', 'xray_decks.dart');
      final xrayDecksExists = await _fileSystem.exists(xrayDecksPath);
      if (!xrayDecksExists || force) {
        files.add(
          await FileUtils.writeFile(
            xrayDecksPath,
            _builder.buildXRayDecksBarrel(),
            'xray_decks',
            force: true,
            dryRun: dryRun,
            verbose: verbose,
            fileSystem: _fileSystem,
          ),
        );
      } else if (verbose) {
        print('  skipped: $xrayDecksPath already exists (use --force to overwrite).');
      }
    }

    // 3. lib/main.dart — entrypoint; respect --force like every other glue
    //    file but print a clearer message when skipping.
    final mainPath = p.join(projectRoot, 'lib', 'main.dart');
    final mainExists = await _fileSystem.exists(mainPath);
    final mainContent = _builder.buildMain(
      appName: appName,
      mockHint: mock,
      outputDir: outputDir,
      xray: xray,
    );
    files.add(
      await FileUtils.writeFile(
        mainPath,
        mainContent,
        'main',
        force: force,
        dryRun: dryRun,
        verbose: verbose,
        fileSystem: _fileSystem,
      ),
    );

    _logSummary(files, dryRun: dryRun, verbose: verbose);

    if (mainExists && !force && !dryRun) {
      print(
        '\nℹ️  lib/main.dart already exists — skipped (use --force to '
        'overwrite). my_app.dart and app_router.dart were regenerated.',
      );
    }

    if (!dryRun) {
      print('\n\u2705 App shell generated.');
      if (xray) {
        print('   \u{1FA7B} X-Ray bridge wired: server starts in debug mode, MyApp wrapped in XRayScope.');
        print('   Run `zfa xray deck --entity <Entity>` to populate the Control Deck barrel.');
      }
      print('\n\u2500\u2500 Next steps \u2500\u2500');
      print('   flutter run   # or `flutter build apk` / `dart run`');
    }  }

  void _logSummary(
    List<GeneratedFile> files, {
    required bool dryRun,
    required bool verbose,
  }) {
    if (dryRun) {
      print('\n📋 Dry run — would write:');
      for (final f in files.where((f) => f.action != 'skipped')) {
        print('   ${f.path}');
      }
      return;
    }

    final created = files.where((f) => f.action == 'created').length;
    final overwritten = files.where((f) => f.action == 'overwritten').length;
    final skipped = files.where((f) => f.action == 'skipped').length;

    if (created > 0) print('  ✨ Created: $created file(s)');
    if (overwritten > 0) print('  📝 Overwritten: $overwritten file(s)');
    if (skipped > 0) print('  ⏭ Skipped: $skipped file(s)');

    if (verbose) {
      for (final file in files) {
        final prefix = switch (file.action) {
          'created' => '  ✨',
          'overwritten' => '  📝',
          'deleted' => '  🗑',
          _ => '  ⏭',
        };
        if (file.action != 'skipped') print('$prefix ${file.path}');
      }
    }
  }
}

/// Top-level `app` command group: `zfa app shell`.
///
/// Introduced in #345 so future app-level generators (e.g. `zfa app
/// theme`, `zfa app icons`) have a natural home.
class AppCommand extends Command<void> {
  AppCommand() {
    addSubcommand(AppShellCommand());
  }

  @override
  String get name => 'app';

  @override
  String get description =>
      'App-level generators (shell, theme, …). Currently exposes `shell`.';
}

/// Thrown when `zfa app shell` cannot proceed because of a missing
/// prerequisite (no pubspec.yaml, no `setupDependencies()`, no
/// `getAllRoutes()`, etc.).
///
/// The CLI runner's catch-all prints the message and exits 1; tests using
/// `runCapturing` catch it without terminating the isolate. Mirrors the
/// `MakeCommandException` pattern in `make_command.dart`.
class AppShellException implements Exception {
  final String message;

  const AppShellException(this.message);

  @override
  String toString() => message;
}
