@Tags(['flutter'])
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;
  late RoutePlugin plugin;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shell_cap_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
    await Directory('$projectRoot/lib/src/routing').create(recursive: true);
    plugin = RoutePlugin(
      outputDir: outputDir,
      projectRoot: projectRoot,
      fileSystem: const DefaultFileSystem(),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Map<String, dynamic>> runCapability({
    required String name,
    required List<String> branches,
    bool bottomNav = true,
    bool adaptive = false,
    bool dryRun = false,
    bool force = true,
    bool verbose = false,
  }) async {
    final capability = plugin.capabilities.firstWhere((c) => c.name == 'shell');
    final result = await capability.execute({
      'name': name,
      'branch': branches,
      'bottomNav': bottomNav,
      'adaptive': adaptive,
      'dryRun': dryRun,
      'force': force,
      'verbose': verbose,
    });
    return result.toJson();
  }

  group('ShellRouteCapability.execute', () {
    test('emits <name>_shell.dart with StatefulShellRoute + NavigationBar '
        'that parses cleanly', () async {
      final result = await runCapability(
        name: 'Main',
        branches: ['Home:/home', 'Deals:/deal', 'Profile:/profile'],
      );

      expect(result['success'], isTrue);
      final files = (result['data']?['generatedFiles'] as List?)
          ?.cast<GeneratedFile>();
      expect(files, isNotNull);
      expect(
        files!.any((f) => f.path.endsWith('main_shell.dart')),
        isTrue,
        reason: 'shell route file must be emitted',
      );

      final shellFile = File('$outputDir/routing/main_shell.dart');
      expect(shellFile.existsSync(), isTrue);

      final content = shellFile.readAsStringSync();
      // Structure: MainShell class + mainShellRoute() getter
      expect(content.contains('class MainShell'), isTrue);
      expect(content.contains('mainShellRoute'), isTrue);
      expect(content.contains('StatefulShellRoute.indexedStack'), isTrue);
      expect(content.contains('StatefulShellBranch'), isTrue);
      expect(content.contains('NavigationBar'), isTrue);
      expect(content.contains('NavigationDestination'), isTrue);
      expect(content.contains("path: '/home'"), isTrue);
      expect(content.contains("path: '/deal'"), isTrue);
      expect(content.contains("path: '/profile'"), isTrue);
      expect(content.contains('navigationShell.currentIndex'), isTrue);
      expect(content.contains('navigationShell.goBranch'), isTrue);
      expect(content.contains('package:go_router/go_router.dart'), isTrue);
      expect(content.contains('package:flutter/material.dart'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'generated shell file must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test(
      'returns List<RouteBase> from <nameCamel>ShellRoute() getter',
      () async {
        await runCapability(name: 'Main', branches: ['Home:/home']);

        final content = File(
          '$outputDir/routing/main_shell.dart',
        ).readAsStringSync();
        expect(
          content.contains('List<RouteBase> mainShellRoute()'),
          isTrue,
          reason:
              'getter must return List<RouteBase> so the index '
              'aggregator can include the StatefulShellRoute',
        );
      },
    );

    test('regenerates routing/index.dart aggregating the shell module '
        'in getAllRoutes() with List<RouteBase> return type', () async {
      await runCapability(
        name: 'Main',
        branches: ['Home:/home', 'Deals:/deal'],
      );

      final indexFile = File('$outputDir/routing/index.dart');
      expect(
        indexFile.existsSync(),
        isTrue,
        reason: 'index.dart must be regenerated',
      );
      final indexContent = indexFile.readAsStringSync();
      expect(
        indexContent.contains('main_shell.dart'),
        isTrue,
        reason: 'index must export the new shell module',
      );
      expect(
        indexContent.contains('mainShellRoute'),
        isTrue,
        reason: 'getAllRoutes() must spread mainShellRoute()',
      );
      expect(
        indexContent.contains('List<RouteBase> getAllRoutes()'),
        isTrue,
        reason:
            'getAllRoutes() return type must be List<RouteBase> '
            'so StatefulShellRoute is acceptable',
      );
      expect(indexContent.contains('getAllRoutes'), isTrue);

      final errors = syntaxErrors(indexContent);
      expect(
        errors,
        isEmpty,
        reason:
            'index file must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test(
      'aggregates shell + entity routes together in getAllRoutes()',
      () async {
        // First seed an entity route module so the index has both kinds.
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

        await runCapability(name: 'Main', branches: ['Home:/home']);

        final indexContent = File(
          '$outputDir/routing/index.dart',
        ).readAsStringSync();
        expect(
          indexContent.contains('...productRoutes()'),
          isTrue,
          reason: 'entity routes getter must still be spread',
        );
        expect(
          indexContent.contains('...mainShellRoute()'),
          isTrue,
          reason: 'shell route getter must be spread too',
        );
        expect(indexContent.contains('List<RouteBase>'), isTrue);

        final errors = syntaxErrors(indexContent);
        expect(
          errors,
          isEmpty,
          reason:
              'mixed routes+shell index must parse cleanly; got: '
              '${errors.map((e) => e.message).join(', ')}',
        );
      },
    );

    test('emits MainShellDesktop + NavigationRail when --adaptive', () async {
      await runCapability(
        name: 'App',
        branches: [
          'Home:/home:Icons.home',
          'Settings:/settings:Icons.settings',
        ],
        adaptive: true,
      );

      final content = File(
        '$outputDir/routing/app_shell.dart',
      ).readAsStringSync();
      expect(content.contains('class AppShell'), isTrue);
      expect(
        content.contains('class AppShellDesktop'),
        isTrue,
        reason: 'adaptive variant must emit AppShellDesktop',
      );
      expect(content.contains('NavigationRail'), isTrue);
      expect(content.contains('NavigationRailDestination'), isTrue);
      expect(
        content.contains('LayoutBuilder'),
        isTrue,
        reason:
            'adaptive shell must pick between mobile/desktop via '
            'LayoutBuilder',
      );
      expect(content.contains('Icons.home'), isTrue);
      expect(content.contains('Icons.settings'), isTrue);
      // Mobile variant still has NavigationBar by default.
      expect(content.contains('NavigationBar'), isTrue);

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'adaptive shell file must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('respects --bottom-nav=false (no NavigationBar)', () async {
      await runCapability(
        name: 'Plain',
        branches: ['Home:/home'],
        bottomNav: false,
      );

      final content = File(
        '$outputDir/routing/plain_shell.dart',
      ).readAsStringSync();
      expect(
        content.contains('NavigationBar'),
        isFalse,
        reason: 'no NavigationBar when --bottom-nav=false',
      );
      expect(
        content.contains('StatefulShellRoute.indexedStack'),
        isTrue,
        reason: 'shell route must still be emitted',
      );
      expect(
        content.contains('Scaffold'),
        isTrue,
        reason: 'Scaffold wrapping navigationShell must still be emitted',
      );

      final errors = syntaxErrors(content);
      expect(
        errors,
        isEmpty,
        reason:
            'no-nav shell must parse cleanly; got: '
            '${errors.map((e) => e.message).join(', ')}',
      );
    });

    test('is idempotent — re-running with the same args produces the same '
        'file (single shell module, no duplicates in index)', () async {
      await runCapability(
        name: 'Main',
        branches: ['Home:/home', 'Profile:/profile'],
      );
      await runCapability(
        name: 'Main',
        branches: ['Home:/home', 'Profile:/profile'],
      );

      final indexContent = File(
        '$outputDir/routing/index.dart',
      ).readAsStringSync();
      expect(
        'mainShellRoute()'.allMatches(indexContent).length,
        equals(1),
        reason:
            'shell getter must appear exactly once in getAllRoutes() '
            'after re-run',
      );
      expect(
        "export 'main_shell.dart';".allMatches(indexContent).length,
        equals(1),
        reason: 'shell module export must appear exactly once',
      );
    });

    test('rejects non-PascalCase name with ArgumentError', () async {
      expect(
        () => runCapability(name: 'main-shell', branches: ['Home:/home']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty branches list with ArgumentError', () async {
      expect(
        () => runCapability(name: 'Main', branches: const []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects branch path that does not start with /', () async {
      expect(
        () => runCapability(
          name: 'Main',
          branches: ['Home:home'], // missing leading /
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects malformed --branch argument', () async {
      expect(
        () => runCapability(name: 'Main', branches: ['no-colon-here']),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

/// Returns the syntax (parse) diagnostics from [source]. A syntactically
/// valid file yields an empty list.
List<Diagnostic> syntaxErrors(String source) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  return result.errors.cast<Diagnostic>();
}
