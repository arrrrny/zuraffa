import 'package:test/test.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:zuraffa/src/routing/route_config_generator.dart';
import 'package:zuraffa/src/routing/route_model.dart';

RouteDeclaration _decl(
  String viewClassName,
  String path, {
  String? parent,
  Map<String, String> params = const {},
  List<String> query = const [],
  List<String> middleware = const [],
  bool isShell = false,
  bool deepLinkAware = false,
  bool viewAcceptsChild = false,
  String? guardRedirect,
}) {
  return RouteDeclaration(
    viewClassName: viewClassName,
    path: path,
    name: viewClassName.toLowerCase(),
    parent: parent,
    params: params,
    query: query,
    middleware: middleware,
    isShell: isShell,
    deepLinkAware: deepLinkAware,
    viewAcceptsChild: viewAcceptsChild,
    guardRedirect: guardRedirect,
    importUri: 'src/views/${viewClassName.toLowerCase()}.dart',
    filePath: '/project/lib/src/views/${viewClassName.toLowerCase()}.dart',
    line: 1,
  );
}

void main() {
  group('RouteConfigGenerator', () {
    test('flat route renders GoRoute with params binding + view return', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl('ProductView', '/products/:id', params: {'id': 'int'}),
        ],
        redirects: const [],
        guardIndex: const {},
      );

      expect(config.routerSource, contains("path: '/products/:id'"));
      expect(config.routerSource, contains("name: 'productview'"));
      expect(config.routerSource, contains('ZfaRouteParams.bind('));
      expect(config.routerSource, contains('ProductViewRouteParams.fromMaps('));
      expect(config.routerSource, contains('return const ProductView();'));
      expect(
        config.routerSource,
        contains("import 'package:go_router/go_router.dart';"),
      );
      expect(
        config.routerSource,
        contains("import 'package:zuraffa/zuraffa.dart';"),
      );
      expect(
        config.routerSource,
        contains("import 'package:test_app/src/views/productview.dart';"),
      );
    });

    test('typed RouteParams class renders with typed fields + fromMaps', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl(
            'ProductView',
            '/products/:id',
            params: {'id': 'int'},
            query: ['tab'],
          ),
        ],
        redirects: const [],
        guardIndex: const {},
      );

      expect(
        config.routerSource,
        contains('class ProductViewRouteParams extends ZfaRouteParams {'),
      );
      expect(config.routerSource, contains('final int id;'));
      expect(config.routerSource, contains('final String? tab;'));
      expect(
        config.routerSource,
        contains("ZfaRouteParams.intParam(pathParameters, 'id')"),
      );
      expect(
        config.routerSource,
        contains("ZfaRouteParams.stringParam(queryParameters, 'tab')"),
      );
      expect(
        config.routerSource,
        contains('factory ProductViewRouteParams.fromMaps('),
      );
    });

    test('default (untyped) path params map to String', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [_decl('ItemView', '/items/:id')],
        redirects: const [],
        guardIndex: const {},
      );
      expect(config.routerSource, contains('final String id;'));
      expect(
        config.routerSource,
        contains("ZfaRouteParams.stringParam(pathParameters, 'id')"),
      );
    });

    test('shell route nests children with relative paths', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl(
            'DashboardView',
            '/dashboard',
            isShell: true,
            viewAcceptsChild: true,
          ),
          _decl('AnalyticsView', '/analytics', parent: 'dashboardview'),
          _decl('SettingsView', '/settings', parent: 'dashboardview'),
        ],
        redirects: const [],
        guardIndex: const {},
      );

      expect(config.routerSource, contains('ShellRoute('));
      // Shell view receives child when its constructor declares it.
      expect(
        config.routerSource,
        contains('return DashboardView(child: child);'),
      );
      // Children are nested with RELATIVE paths (leading slash stripped).
      expect(config.routerSource, contains("path: 'analytics'"));
      expect(config.routerSource, contains("path: 'settings'"));
      // The children must appear inside the ShellRoute's routes: [...]
      final shellStart = config.routerSource.indexOf('ShellRoute(');
      final routesStart = config.routerSource.indexOf('routes: [', shellStart);
      final routesEnd = config.routerSource.indexOf('],', routesStart);
      final shellBody = config.routerSource.substring(routesStart, routesEnd);
      expect(shellBody, contains("path: 'analytics'"));
      expect(shellBody, contains("path: 'settings'"));
      expect(shellBody, isNot(contains("path: '/analytics'")));
    });

    test('shell view without child param is rendered without child arg', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl('PlainView', '/plain', isShell: true, viewAcceptsChild: false),
          _decl('ChildView', '/child', parent: 'plainview'),
        ],
        redirects: const [],
        guardIndex: const {},
      );
      expect(config.routerSource, contains('return const PlainView();'));
      expect(config.routerSource, isNot(contains('PlainView(child: child)')));
    });

    test('redirect rules render GoRoute redirect entries', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [_decl('HomeView', '/home')],
        redirects: [
          RouteRedirectRule(
            from: '/old-page',
            to: '/new-page',
            filePath: 'f',
            line: 1,
          ),
        ],
        guardIndex: const {},
      );
      expect(
        config.routerSource,
        contains("path: '/old-page', redirect: (_, __) => '/new-page'"),
      );
    });

    test('guard middleware wraps route with zfaGuardRedirect', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl('SecureView', '/secure', middleware: ['AuthGuard']),
        ],
        redirects: const [],
        guardIndex: {'AuthGuard': 'src/guards/auth_guard.dart'},
      );

      // Guard import emitted.
      expect(
        config.routerSource,
        contains("import 'package:test_app/src/guards/auth_guard.dart';"),
      );
      // Redirect hook present, invoking the guard instance.
      expect(config.routerSource, contains('zfaGuardRedirect('));
      expect(config.routerSource, contains('[const AuthGuard()]'));
      // Guard helper implementation included.
      expect(
        config.routerSource,
        contains('Future<String?> zfaGuardRedirect('),
      );
      expect(config.routerSource, contains('guard.canActivate(state)'));
      expect(config.routerSource, contains('guard.onRejected(state)'));
      expect(config.routerSource, contains('_zfaRouteState(state)'));
    });

    test('guardRedirect option overrides default deny target in helper', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl(
            'SecureView',
            '/secure',
            middleware: ['AuthGuard'],
            guardRedirect: '/sign-in',
          ),
        ],
        redirects: const [],
        guardIndex: {'AuthGuard': 'src/guards/auth_guard.dart'},
      );
      expect(config.routerSource, contains("'/sign-in'"));
    });

    test('generated router file parses back with zero syntax errors', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl(
            'DashboardView',
            '/dashboard',
            isShell: true,
            viewAcceptsChild: true,
          ),
          _decl('AnalyticsView', '/analytics', parent: 'dashboardview'),
          _decl(
            'ProductView',
            '/products/:id',
            params: {'id': 'int'},
            query: ['tab'],
          ),
          _decl('SecureView', '/secure', middleware: ['AuthGuard']),
        ],
        redirects: [
          RouteRedirectRule(
            from: '/old',
            to: '/products/:id',
            filePath: 'f',
            line: 1,
          ),
        ],
        guardIndex: {'AuthGuard': 'src/guards/auth_guard.dart'},
      );

      final result = parseString(
        content: config.routerSource,
        path: 'zfa_router.g.dart',
        throwIfDiagnostics: false,
      );
      final syntaxErrors = result.errors
          .where((e) => e.errorCode.type.name == 'SYNTACTIC_ERROR')
          .toList();
      expect(
        syntaxErrors,
        isEmpty,
        reason: 'generated router must be syntactically valid Dart',
      );
    });

    test('deep link side files include deepLinkAware paths only', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [
          _decl('ShareView', '/share', deepLinkAware: true),
          _decl('HomeView', '/home'),
        ],
        redirects: const [],
        guardIndex: const {},
      );

      expect(
        config.deepLinkFiles.keys,
        contains('.well-known/apple-app-site-association'),
      );
      expect(
        config.deepLinkFiles.keys,
        contains('.well-known/assetlinks.json'),
      );
      final apple =
          config.deepLinkFiles['.well-known/apple-app-site-association']!;
      expect(apple, contains('/share'));
      expect(apple, isNot(contains('/home')));
      final android = config.deepLinkFiles['.well-known/assetlinks.json']!;
      expect(android, contains('/share'));
      expect(android, isNot(contains("'/home'")));
    });

    test('no deepLinkAware routes -> no side files', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: [_decl('HomeView', '/home')],
        redirects: const [],
        guardIndex: const {},
      );
      expect(config.deepLinkFiles, isEmpty);
    });

    test('deterministic ordering: same input -> identical output', () {
      final routes = [
        _decl('HomeView', '/home'),
        _decl('ProductView', '/products/:id', params: {'id': 'int'}),
        _decl('AboutView', '/about'),
      ];
      final a = RouteConfigGenerator.generate(
        packageName: 'pkg',
        routes: routes,
        redirects: const [],
        guardIndex: const {},
      );
      final b = RouteConfigGenerator.generate(
        packageName: 'pkg',
        routes: routes,
        redirects: const [],
        guardIndex: const {},
      );
      expect(a.routerSource, equals(b.routerSource));
    });

    test('empty configuration renders a valid empty router', () {
      final config = RouteConfigGenerator.generate(
        packageName: 'test_app',
        routes: const [],
        redirects: const [],
        guardIndex: const {},
      );
      expect(
        config.routerSource,
        contains('final List<RouteBase> zfaRoutes = [];'),
      );
      expect(
        config.routerSource,
        contains('final List<RouteBase> zfaRouteRedirects = [];'),
      );
      final result = parseString(
        content: config.routerSource,
        path: 'zfa_router.g.dart',
        throwIfDiagnostics: false,
      );
      final syntaxErrors = result.errors
          .where((e) => e.errorCode.type.name == 'SYNTACTIC_ERROR')
          .toList();
      expect(syntaxErrors, isEmpty);
    });
  });
}
