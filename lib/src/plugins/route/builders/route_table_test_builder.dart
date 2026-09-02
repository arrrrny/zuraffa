import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as path;

import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/package_utils.dart';
import '../../../utils/string_utils.dart';

/// One declared route path and the route module that declares it.
class DeclaredRoute {
  final String path;
  final String owner;

  const DeclaredRoute({required this.path, required this.owner});
}

/// One deep-link pattern with its typed path-parameter names.
class DeepLinkPattern {
  final String pattern;
  final List<String> params;
  final String owner;

  const DeepLinkPattern({
    required this.pattern,
    required this.params,
    required this.owner,
  });
}

/// One adaptive shell discovered in the routing directory.
class AdaptiveShellSpec {
  final String namePascal;
  final String nameSnake;
  final List<String> branchRoots;

  const AdaptiveShellSpec({
    required this.namePascal,
    required this.nameSnake,
    required this.branchRoots,
  });

  String get nameCamel => StringUtils.pascalToCamel(namePascal);
}

/// The route table discovered from the target project's routing directory.
///
/// "Manifest as data" — the generated route-table test embeds this manifest
/// so the suite asserts the DECLARED table against the REAL
/// `getAllRoutes()` aggregator on every test run.
class RouteTableManifest {
  final List<DeclaredRoute> declaredRoutes;
  final List<DeepLinkPattern> deepLinks;
  final List<AdaptiveShellSpec> adaptiveShells;

  const RouteTableManifest({
    required this.declaredRoutes,
    required this.deepLinks,
    required this.adaptiveShells,
  });

  bool get isEmpty =>
      declaredRoutes.isEmpty && deepLinks.isEmpty && adaptiveShells.isEmpty;
}

/// Emits the route-table tests required by #842:
///
/// 1. `test/routing/route_table_test.dart` — every declared route resolves to
///    a builder, unknown paths hit the 404 handler, deep-link patterns parse
///    into typed params via `routeInformationProvider` URI fixtures.
/// 2. `test/routing/<name>_deep_link_test.dart` — the dedicated deep-link
///    behavior suite (057/058): barcode-path + URL-encoded-query fixtures,
///    deterministic, no platform channel.
/// 3. `test/routing/<name>_shell_layout_test.dart` — the platform-divergence
///    matrix (adaptive layout manifest as data + widget-level presence
///    checks: mobile bottom nav vs macOS/desktop sidebar).
///
/// All three drive go_router's PUBLIC surface only
/// (`GoRouter(routes:, initialLocation:, onException:, errorBuilder:)`,
/// `routeInformationProvider.value.uri`,
/// `routerDelegate.currentConfiguration`), so the generated suites are
/// deterministic: no platform channel, and the route sweep never builds a
/// destination view (matching is proven via the matcher's `onException`
/// signal), which keeps view-level DI out of the route-table suite.
class RouteTableTestBuilder {
  /// Literal unknown path embedded in every generated suite: guaranteed to
  /// match no declared route, so it always falls through to the 404 handler.
  static const String unknownPathLiteral = '/__zfa_unknown_404__';

  final FileSystem fileSystem;

  const RouteTableTestBuilder({FileSystem? fileSystem})
    : fileSystem = fileSystem ?? const DefaultFileSystem();

  // ---------------------------------------------------------------------------
  // Manifest discovery
  // ---------------------------------------------------------------------------

  /// Scans `<outputDir>/routing/` and builds the route-table manifest:
  /// declared constants from `*_routes.dart`, branch roots from
  /// `*_shell.dart`, deep-link patterns (paths containing `:param`
  /// segments) and adaptive shells (shell modules carrying BOTH nav
  /// surfaces).
  Future<RouteTableManifest> discover({
    required String outputDir,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? this.fileSystem;
    final routingDir = path.join(outputDir, 'routing');
    if (!await fs.exists(routingDir)) {
      return const RouteTableManifest(
        declaredRoutes: [],
        deepLinks: [],
        adaptiveShells: [],
      );
    }

    final declared = <DeclaredRoute>[];
    final deepLinks = <DeepLinkPattern>[];
    final shells = <AdaptiveShellSpec>[];

    for (final entry in await fs.list(routingDir)) {
      if (await fs.isDirectory(entry)) continue;
      final fileName = path.basename(entry);
      if (fileName.endsWith('index.dart') ||
          fileName.endsWith('app_routes.dart')) {
        continue;
      }

      if (fileName.endsWith('_routes.dart')) {
        final moduleBase = fileName.replaceAll('_routes.dart', '');
        final ownerClass =
            '${StringUtils.convertToPascalCase(moduleBase)}Routes';
        final constants = parseRouteConstants(await fs.read(entry));
        for (final constant in constants.entries) {
          declared.add(
            DeclaredRoute(
              path: constant.value,
              owner: '$ownerClass.${constant.key}',
            ),
          );
          final params = extractPathParams(constant.value);
          if (params.isNotEmpty) {
            deepLinks.add(
              DeepLinkPattern(
                pattern: constant.value,
                params: params,
                owner: '$ownerClass.${constant.key}',
              ),
            );
          }
        }
        continue;
      }

      if (fileName.endsWith('_shell.dart')) {
        final nameSnake = fileName.replaceAll('_shell.dart', '');
        final namePascal = StringUtils.convertToPascalCase(nameSnake);
        final source = await fs.read(entry);
        final branchRoots = parseGoRoutePaths(source);
        for (final branchPath in branchRoots) {
          declared.add(
            DeclaredRoute(path: branchPath, owner: '${namePascal}Shell.branch'),
          );
        }
        // An adaptive shell declares BOTH nav surfaces (bottom nav +
        // rail) — that is the platform divergence #842 asks to assert.
        if (source.contains('NavigationRail') &&
            source.contains('NavigationBar')) {
          shells.add(
            AdaptiveShellSpec(
              namePascal: namePascal,
              nameSnake: nameSnake,
              branchRoots: branchRoots,
            ),
          );
        }
        continue;
      }
    }

    return RouteTableManifest(
      declaredRoutes: declared,
      deepLinks: deepLinks,
      adaptiveShells: shells,
    );
  }

  /// Parses `static const String <name> = '<path>';` route constants from a
  /// generated route module source, in declaration order.
  Map<String, String> parseRouteConstants(String source) {
    final constants = <String, String>{};
    final pattern = RegExp(
      r"static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*'([^']*)'\s*;",
    );
    for (final match in pattern.allMatches(source)) {
      constants[match.group(1)!] = match.group(2)!;
    }
    return constants;
  }

  /// Parses all `path: '<path>'` literals from a generated shell module.
  List<String> parseGoRoutePaths(String source) {
    final paths = <String>[];
    final pattern = RegExp(r"path:\s*'([^']*)'");
    for (final match in pattern.allMatches(source)) {
      paths.add(match.group(1)!);
    }
    return paths;
  }

  /// Extracts the `:param` names from a deep-link pattern.
  List<String> extractPathParams(String pattern) {
    final params = <String>[];
    for (final match in RegExp(
      r':([A-Za-z_][A-Za-z0-9_]*)',
    ).allMatches(pattern)) {
      params.add(match.group(1)!);
    }
    return params;
  }

  // ---------------------------------------------------------------------------
  // Emission
  // ---------------------------------------------------------------------------

  /// Emits the whole-table route-table test at
  /// `<projectRoot>/test/routing/route_table_test.dart`. Returns `null`
  /// when the manifest is empty (nothing to prove).
  Future<GeneratedFile?> emitRouteTableTest({
    required String outputDir,
    required bool dryRun,
    required bool verbose,
  }) async {
    final manifest = await discover(outputDir: outputDir);
    if (manifest.isEmpty) return null;

    final testPath = path.join(
      resolveProjectRoot(outputDir),
      'test',
      'routing',
      'route_table_test.dart',
    );
    final content = buildRouteTableTest(
      manifest: manifest,
      indexImport: moduleImport(outputDir, 'routing/index.dart'),
    );
    return FileUtils.writeFile(
      testPath,
      content,
      'route_table_test',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: fileSystem,
    );
  }

  /// Emits the dedicated deep-link route-table test for one deep link at
  /// `<projectRoot>/test/routing/<name_snake>_deep_link_test.dart`.
  Future<GeneratedFile?> emitDeepLinkTest({
    required String outputDir,
    required String namePascal,
    required String routePath,
    required bool dryRun,
    required bool verbose,
  }) async {
    final params = extractPathParams(routePath);
    final nameSnake = StringUtils.camelToSnake(namePascal);
    final testPath = path.join(
      resolveProjectRoot(outputDir),
      'test',
      'routing',
      '${nameSnake}_deep_link_test.dart',
    );
    final content = buildDeepLinkTest(
      namePascal: namePascal,
      pattern: routePath,
      params: params,
      indexImport: moduleImport(outputDir, 'routing/index.dart'),
    );
    return FileUtils.writeFile(
      testPath,
      content,
      'deep_link_route_table_test',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: fileSystem,
    );
  }

  /// Emits the adaptive-shell platform-divergence test at
  /// `<projectRoot>/test/routing/<name_snake>_shell_layout_test.dart`.
  /// Returns `null` for non-adaptive shells (no divergence to assert) or
  /// when the shell module is missing.
  Future<GeneratedFile?> emitShellLayoutTest({
    required String outputDir,
    required String namePascal,
    required bool dryRun,
    required bool verbose,
  }) async {
    final nameSnake = StringUtils.camelToSnake(namePascal);
    final shellModule = 'routing/${nameSnake}_shell.dart';
    final shellSourcePath = path.join(outputDir, shellModule);
    if (!await fileSystem.exists(shellSourcePath)) return null;
    final shellSource = await fileSystem.read(shellSourcePath);
    // Divergence exists only when the shell declares BOTH surfaces.
    if (!shellSource.contains('NavigationRail') ||
        !shellSource.contains('NavigationBar')) {
      return null;
    }

    final testPath = path.join(
      resolveProjectRoot(outputDir),
      'test',
      'routing',
      '${nameSnake}_shell_layout_test.dart',
    );
    final content = buildShellLayoutTest(
      namePascal: namePascal,
      branchRoots: parseGoRoutePaths(shellSource),
      shellImport: moduleImport(outputDir, shellModule),
    );
    return FileUtils.writeFile(
      testPath,
      content,
      'shell_layout_test',
      force: true,
      dryRun: dryRun,
      verbose: verbose,
      fileSystem: fileSystem,
    );
  }

  // ---------------------------------------------------------------------------
  // Code templates
  // ---------------------------------------------------------------------------

  /// Builds the whole-table route-table test source.
  String buildRouteTableTest({
    required RouteTableManifest manifest,
    required String indexImport,
  }) {
    final declaredEntries = manifest.declaredRoutes
        .map((r) => "    '${_dartEscape(r.path)}': '${_dartEscape(r.owner)}',")
        .join('\n');
    final patternEntries = manifest.deepLinks
        .map(
          (d) =>
              "    '${_dartEscape(d.pattern)}': "
              "<String>[${d.params.map((p) => "'$p'").join(', ')}],",
        )
        .join('\n');
    final fixtureGroups = manifest.deepLinks
        .map(_buildDeepLinkFixtureGroup)
        .join('\n');

    return _format('''
// Generated by zfa — route-table test (issue #842).
//
// Proves the declared route table with go_router's PUBLIC surface only:
//   - every declared route resolves to a builder (no 404),
//   - every GoRoute in getAllRoutes() carries a builder or redirect,
//   - unknown paths hit the 404 handler,
//   - deep-link patterns parse into typed params from URI fixtures.
//
// Deterministic by construction: no platform channel, and the route sweep
// never builds a destination view (matching is proven via the matcher's
// onException signal), so view-level DI never leaks into this suite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '$indexImport';

/// Declared route table (manifest as data) — regenerated by zfa on every
/// route run. Maps a declared path to the route module that declares it.
const Map<String, String> kDeclaredRoutes = <String, String>{
$declaredEntries
};

/// Deep-link patterns declared in the table, with their typed path params.
const Map<String, List<String>> kDeepLinkPatterns = <String, List<String>>{
$patternEntries
};

/// Marker 404 page used to prove unknown paths hit the error handler.
class RouteTableTestNotFound extends StatelessWidget {
  const RouteTableTestNotFound({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('404 — route not found')));
}

void main() {
  group('route table (#842)', () {
    test('every GoRoute in getAllRoutes() carries a builder or redirect', () {
      final routes = _flattenRoutes(getAllRoutes());
      expect(routes, isNotEmpty, reason: 'the route table must not be empty');
      for (final route in routes) {
        expect(
          route.builder != null ||
              route.pageBuilder != null ||
              route.redirect != null,
          isTrue,
          reason: 'route \${route.path} has no builder/pageBuilder/redirect',
        );
      }
    });

    test('every declared route resolves to a builder (no 404)', () async {
      expect(kDeclaredRoutes, isNotEmpty);
      for (final declared in kDeclaredRoutes.keys) {
        expect(
          await _resolvesWithoutException(declared),
          isTrue,
          reason: 'declared route \$declared does not resolve to a route',
        );
      }
    });

    test('unknown paths hit the 404 handler', () async {
      expect(
        await _resolvesWithoutException('$unknownPathLiteral'),
        isFalse,
        reason: 'an unknown path must NOT resolve — it must hit 404',
      );
    });

    testWidgets('unknown path renders the 404 error page', (tester) async {
      final router = GoRouter(
        initialLocation: '$unknownPathLiteral',
        routes: getAllRoutes(),
        errorBuilder: (context, state) => const RouteTableTestNotFound(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.byType(RouteTableTestNotFound), findsOneWidget);
    });

    test('deep-link patterns parse into typed params', () async {
$fixtureGroups
    });
  });
}

/// A synthetic root guarantees the router boots on '/' without touching the
/// declared table — every assertion then drives the REAL table via go().
List<RouteBase> _tableWithSyntheticRoot() => <RouteBase>[
  GoRoute(
    path: '/',
    builder: (context, state) => const SizedBox.shrink(),
  ),
  ...getAllRoutes(),
];

List<GoRoute> _flattenRoutes(List<RouteBase> routes) {
  final flat = <GoRoute>[];
  void walk(List<RouteBase> rs) {
    for (final r in rs) {
      if (r is GoRoute) {
        flat.add(r);
        walk(r.routes);
      } else if (r is ShellRoute) {
        walk(r.routes);
      } else if (r is StatefulShellRoute) {
        for (final branch in r.branches) {
          walk(branch.routes);
        }
      }
    }
  }

  walk(routes);
  return flat;
}

/// Builds an in-memory router over the REAL route table (plus a synthetic
/// root) and reports whether [location] resolves without hitting the 404
/// path (onException).
Future<bool> _resolvesWithoutException(String location) async {
  var exceptional = false;
  final router = GoRouter(
    initialLocation: '/',
    routes: _tableWithSyntheticRoot(),
    onException: (context, state, router) => exceptional = true,
  );
  addTearDown(router.dispose);
  router.go(location);
  await Future<void>.delayed(Duration.zero);
  return !exceptional;
}
''');
  }

  /// Builds one self-contained fixture block for a deep-link pattern:
  /// barcode-style path fixture + URL-encoded fixture, asserting the
  /// `routeInformationProvider` round-trip and the typed params.
  String _buildDeepLinkFixtureGroup(DeepLinkPattern d) {
    final plainFixture = _fillPattern(d.pattern, '123456');
    final encodedFixture = _fillPattern(d.pattern, 'a%20b');
    final firstParam = d.params.isNotEmpty ? d.params.first : 'param';
    return '''
    {
      var exceptional = false;
      // Barcode-style path fixture.
      final router = GoRouter(
        initialLocation: '/',
        routes: _tableWithSyntheticRoot(),
        onException: (context, state, router) => exceptional = true,
      );
      addTearDown(router.dispose);
      router.go('${_dartEscape(plainFixture)}');
      await Future<void>.delayed(Duration.zero);
      expect(exceptional, isFalse,
          reason: 'deep link fixture must resolve: ${_dartEscape(plainFixture)}');
      // routeInformationProvider round-trips the delivered URI.
      expect(
        router.routeInformationProvider.value.uri.path,
        '${_dartEscape(plainFixture)}',
      );
      final params = router.routerDelegate.currentConfiguration.pathParameters;
      expect(params['$firstParam'], equals('123456'));

      // URL-encoded fixture: encoded segment + query survive parsing.
      exceptional = false;
      final encodedRouter = GoRouter(
        initialLocation: '/',
        routes: _tableWithSyntheticRoot(),
        onException: (context, state, router) => exceptional = true,
      );
      addTearDown(encodedRouter.dispose);
      encodedRouter.go('${_dartEscape(encodedFixture)}?source=qr');
      await Future<void>.delayed(Duration.zero);
      expect(exceptional, isFalse,
          reason:
              'URL-encoded deep link must resolve: ${_dartEscape(encodedFixture)}');
      expect(
        encodedRouter.routeInformationProvider.value.uri.path,
        '${_dartEscape(encodedFixture)}',
      );
      final encodedParams =
          encodedRouter.routerDelegate.currentConfiguration.pathParameters;
      expect(encodedParams['$firstParam'], equals('a b'));
      expect(
        encodedRouter
            .routerDelegate
            .currentConfiguration
            .uri
            .queryParameters['source'],
        equals('qr'),
      );
    }
''';
  }

  /// Builds the dedicated deep-link route-table test source.
  String buildDeepLinkTest({
    required String namePascal,
    required String pattern,
    required List<String> params,
    required String indexImport,
  }) {
    final nameSnake = StringUtils.camelToSnake(namePascal);
    final fixtureGroup = _buildDeepLinkFixtureGroup(
      DeepLinkPattern(
        pattern: pattern,
        params: params,
        owner: '${namePascal}Routes',
      ),
    );

    return _format('''
// Generated by zfa — deep-link route-table test for $namePascal (#842).
//
// Drives go_router's routeInformationProvider with URI fixtures (barcode
// path, URL-encoded query) asserting destination + typed params.
// Deterministic: no platform channel — the fixture URI is what the engine
// delivers after platform dispatch strips the scheme.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '$indexImport';

/// The declared deep-link pattern.
const String k${namePascal}Pattern = '${_dartEscape(pattern)}';

/// Unknown-path control: must fall through to the 404 handler.
const String k${namePascal}Unknown = '$unknownPathLiteral';

void main() {
  group('deep link $nameSnake (#842)', () {
    test('declared pattern resolves (destination found, no 404)', () async {
      var exceptional = false;
      final router = GoRouter(
        initialLocation: '/',
        routes: _tableWithSyntheticRoot(),
        onException: (context, state, router) => exceptional = true,
      );
      addTearDown(router.dispose);
      router.go(k${namePascal}Pattern.replaceFirst(RegExp(r':[A-Za-z_][A-Za-z0-9_]*'), '123456'));
      await Future<void>.delayed(Duration.zero);
      expect(exceptional, isFalse,
          reason: 'the declared deep link must resolve to its route');
    });

    test('routeInformationProvider + typed params from URI fixtures',
        () async {
$fixtureGroup
    });

    test('unmatched deep link falls through to the 404 handler', () async {
      var exceptional = false;
      final router = GoRouter(
        initialLocation: '/',
        routes: _tableWithSyntheticRoot(),
        onException: (context, state, router) => exceptional = true,
      );
      addTearDown(router.dispose);
      router.go(k${namePascal}Unknown + '/deep');
      await Future<void>.delayed(Duration.zero);
      expect(exceptional, isTrue,
          reason: 'an unknown deep link must hit the 404 handler');
    });
  });
}

/// A synthetic root guarantees the router boots on '/' without touching the
/// declared table — every assertion then drives the REAL table via go().
List<RouteBase> _tableWithSyntheticRoot() => <RouteBase>[
  GoRoute(
    path: '/',
    builder: (context, state) => const SizedBox.shrink(),
  ),
  ...getAllRoutes(),
];
''');
  }

  /// Builds the adaptive-shell platform-divergence test source.
  String buildShellLayoutTest({
    required String namePascal,
    required List<String> branchRoots,
    required String shellImport,
  }) {
    final initialLocation = branchRoots.isNotEmpty ? branchRoots.first : '/';
    final getter = '${StringUtils.pascalToCamel(namePascal)}ShellRoute';

    return _format('''
// Generated by zfa — adaptive shell layout matrix test ($namePascal, #842).
//
// Asserts the platform divergence via the adaptive layout manifest as data,
// plus widget-level presence checks: mobile renders the bottom nav
// (NavigationBar), macOS/desktop render the sidebar (NavigationRail).
// Deterministic: surface sizes are forced via tester.view, no platform
// channel. Shell branch placeholders are const SizedBox.shrink(), so
// pumping the shell module never builds an entity view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '$shellImport';

/// Adaptive layout manifest as data: layout target -> expected nav widget.
const Map<String, String> k${namePascal}LayoutManifest = <String, String>{
  'mobile': 'NavigationBar',
  'tablet': 'NavigationBar',
  'desktop': 'NavigationRail',
  'macos': 'NavigationRail',
};

/// Compact vs expanded surfaces used by the widget-level checks.
const Map<String, Size> k${namePascal}LayoutSurfaces = <String, Size>{
  'mobile': Size(390, 844),
  'macos': Size(1280, 800),
};

void main() {
  group('adaptive shell layout matrix ($namePascal, #842 / 003 US3)', () {
    testWidgets('mobile target renders the bottom nav', (tester) async {
      await _pumpShellAt(tester, k${namePascal}LayoutSurfaces['mobile']!);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('macOS target renders the sidebar', (tester) async {
      await _pumpShellAt(tester, k${namePascal}LayoutSurfaces['macos']!);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    test('manifest covers both diverging surfaces', () {
      expect(k${namePascal}LayoutManifest['mobile'], equals('NavigationBar'));
      expect(k${namePascal}LayoutManifest['macos'], equals('NavigationRail'));
    });
  });
}

Future<void> _pumpShellAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: '${_dartEscape(initialLocation)}',
    routes: $getter(),
    errorBuilder: (context, state) => const SizedBox.shrink(),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}
''');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Fills every `:param` in [pattern] with [value].
  String _fillPattern(String pattern, String value) =>
      pattern.replaceAll(RegExp(r':[A-Za-z_][A-Za-z0-9_]*'), value);

  /// Resolves the project root from an output dir ending in `lib/src`
  /// (canonical zfa layout), `lib`, or anything else.
  String resolveProjectRoot(String outputDir) {
    final normalized = path.normalize(outputDir);
    final parts = path.split(normalized);
    if (parts.length >= 2 &&
        parts[parts.length - 2] == 'lib' &&
        parts.last == 'src') {
      return path.joinAll(parts.sublist(0, parts.length - 2));
    }
    if (parts.isNotEmpty && parts.last == 'lib') {
      return path.joinAll(parts.sublist(0, parts.length - 1));
    }
    return path.dirname(normalized);
  }

  /// `package:<pkg>[/<lib subpath>]/<relativeModule>` import URI.
  String moduleImport(String outputDir, String relativeModule) {
    final packageName = PackageUtils.getPackageName(
      outputDir: outputDir,
      fileSystem: fileSystem,
    );
    final segments = path.split(path.normalize(outputDir));
    final libIndex = segments.indexOf('lib');
    final subPath = libIndex != -1 && libIndex < segments.length - 1
        ? '/${path.joinAll(segments.sublist(libIndex + 1))}'
        : '';
    return 'package:$packageName$subPath/$relativeModule';
  }

  /// Escapes a value for embedding inside a single-quoted Dart string.
  String _dartEscape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  /// Formats emitted Dart with the repo's formatter; falls back to the raw
  /// template on a formatting error (mirrors ShellRoutesBuilder).
  String _format(String raw) {
    try {
      return DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(raw);
    } catch (_) {
      return raw;
    }
  }
}
