@Tags(['regression', 'slow'])
// https://github.com/arrrrny/zuraffa/issues/359
//
// Before this fix, the route plugin generated per-entity GoRoutes but had
// no concept of a navigation shell — `zfa route shell` did not exist,
// `StatefulShellRoute.indexedStack` + `NavigationBar`/`NavigationRail`
// had to be hand-written, and `getAllRoutes()` was typed as
// `List<GoRoute>` so a `StatefulShellRoute` couldn't be aggregated.
//
// The smoke test for v6 ("any agent should build a ZikZak-class app with
// ONLY zfa commands, intuitively") breaks because the agent had to
// hand-edit `lib/src/routing/app_shell.dart` + the routing index to get
// a primary navigation surface — exactly the gap this test closes.
//
// This test verifies the end-to-end contract:
//   1. `zfa route shell Main --branch Home:/home --branch Deals:/deal
//       --bottom-nav` emits a `StatefulShellRoute.indexedStack` shell
//       module + regenerates `routing/index.dart` aggregating it inside
//       `getAllRoutes()` (now `List<RouteBase>`).
//   2. The generated shell file parses cleanly (no analyzer errors).
//   3. The shell file exports both `<Name>Shell` (mobile, NavigationBar)
//      and `<Name>ShellDesktop` (NavigationRail) when `--adaptive` is
//      passed.
//   4. The capability is wired into the `route` command's subcommand
//      dispatcher so `zfa route shell ...` works at the CLI.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;
  late RouteCommand command;
  late CommandRunner<void> runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('issue_359_shell_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
    await Directory('$projectRoot/lib/src/routing').create(recursive: true);
    plugin = RoutePlugin(
      outputDir: outputDir,
      projectRoot: projectRoot,
      fileSystem: const DefaultFileSystem(),
    );
    command = RouteCommand(plugin);
    runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
      ..addCommand(command);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('issue #359 — shell + bottom navigation in route plugin', () {
    test('`zfa route shell Main --branch Home:/home --branch Deals:/deal '
        '--bottom-nav` emits the shell module + index aggregator', () async {
      await runner.run([
        'route',
        'shell',
        'Main',
        '--branch',
        'Home:/home',
        '--branch',
        'Deals:/deal',
        '--branch',
        'Profile:/profile',
        '--bottom-nav',
        '--force',
      ]);

      final shellFile = File('$outputDir/routing/main_shell.dart');
      expect(
        shellFile.existsSync(),
        isTrue,
        reason: 'main_shell.dart must be emitted',
      );

      final content = shellFile.readAsStringSync();
      expect(content.contains('StatefulShellRoute.indexedStack'), isTrue);
      expect(content.contains('class MainShell'), isTrue);
      expect(content.contains('NavigationBar'), isTrue);
      expect(content.contains('NavigationDestination'), isTrue);
      expect(content.contains('navigationShell.goBranch'), isTrue);
      expect(content.contains("path: '/home'"), isTrue);
      expect(content.contains("path: '/deal'"), isTrue);
      expect(content.contains("path: '/profile'"), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'generated shell file must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );

      final indexFile = File('$outputDir/routing/index.dart');
      expect(indexFile.existsSync(), isTrue);
      final indexContent = indexFile.readAsStringSync();
      expect(
        indexContent.contains('List<RouteBase> getAllRoutes()'),
        isTrue,
        reason: 'getAllRoutes() return type must be List<RouteBase>',
      );
      expect(
        indexContent.contains('...mainShellRoute()'),
        isTrue,
        reason: 'shell getter must be spread into getAllRoutes()',
      );
      // Regression #350 + #359: a shell-only app boots at GoRouter's
      // default initialLocation `/` — the index must emit a root route
      // redirecting to the shell's first branch, otherwise GoRouter
      // throws `no routes for location: /` at the first frame.
      expect(
        indexContent.contains("path: '/', name: 'root'"),
        isTrue,
        reason:
            'shell-only index must emit a root / route so the '
            'generated app boots',
      );
      expect(
        indexContent.contains("redirect: (_, __) => '/home'"),
        isTrue,
        reason:
            'root route must redirect to the shell first branch '
            '(Home:/home)',
      );

      final indexErrors = syntaxErrors(indexContent);
      expect(
        indexErrors,
        isEmpty,
        reason:
            'index must parse cleanly; got: '
            '${indexErrors.map((e) => e.message).join(', ')}',
      );
    });

    test('`zfa route shell App --branch ... --adaptive` emits both '
        'AppShell (mobile) and AppShellDesktop (rail)', () async {
      await runner.run([
        'route',
        'shell',
        'App',
        '--branch',
        'Home:/home:Icons.home',
        '--branch',
        'Settings:/settings:Icons.settings',
        '--adaptive',
        '--force',
      ]);

      final content = File(
        '$outputDir/routing/app_shell.dart',
      ).readAsStringSync();
      expect(content.contains('class AppShell'), isTrue);
      expect(content.contains('class AppShellDesktop'), isTrue);
      expect(content.contains('NavigationRail'), isTrue);
      expect(content.contains('LayoutBuilder'), isTrue);
      expect(content.contains('Icons.home'), isTrue);
      expect(content.contains('Icons.settings'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'adaptive shell must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('shell + entity routes coexist in getAllRoutes() (mixed '
        'List<RouteBase> aggregator)', () async {
      // Seed an entity route module (simulating prior `zfa route create
      // Product`).
      await File('$outputDir/routing/product_routes.dart').writeAsString('''
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

abstract class ProductRoutes {
  static const String product = '/product';
}

List<GoRoute> productRoutes() {
  return [
    GoRoute(
      path: ProductRoutes.product,
      name: 'product',
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ];
}
''');

      await runner.run([
        'route',
        'shell',
        'Main',
        '--branch',
        'Home:/home',
        '--force',
      ]);

      final indexContent = File(
        '$outputDir/routing/index.dart',
      ).readAsStringSync();
      expect(
        indexContent.contains('...productRoutes()'),
        isTrue,
        reason: 'existing entity route getter must still be spread',
      );
      expect(
        indexContent.contains('...mainShellRoute()'),
        isTrue,
        reason: 'shell route getter must be spread too',
      );
      expect(indexContent.contains('List<RouteBase>'), isTrue);
      // #359: go_router resolves a location by first match, so the real
      // entity GoRoute must be emitted BEFORE the shell's placeholder
      // GoRoute for "entity route shadows shell placeholder" to hold —
      // regardless of directory listing order.
      final routesIdx = indexContent.indexOf('...productRoutes()');
      final shellIdx = indexContent.indexOf('...mainShellRoute()');
      expect(routesIdx, isNot(-1));
      expect(shellIdx, isNot(-1));
      expect(
        routesIdx < shellIdx,
        isTrue,
        reason:
            'entity routes must precede the shell module in '
            'getAllRoutes() so the real route shadows the placeholder',
      );

      final errors = syntaxErrors(indexContent);
      expect(
        errors,
        isEmpty,
        reason:
            'mixed aggregator must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('RouteCommand registers the `shell` subcommand (capability is '
        'wired into the dispatcher)', () {
      // The PluginCommand base class auto-registers each capability as a
      // subcommand. Verifying `shell` is in the subcommand map proves the
      // capability is wired (the CLI surface and the usage banner both
      // derive from this map).
      expect(
        command.subcommands.containsKey('shell'),
        isTrue,
        reason: 'shell subcommand must be registered on RouteCommand',
      );
    });
  });
}

List<Diagnostic> syntaxErrors(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.errors.cast<Diagnostic>();
}
