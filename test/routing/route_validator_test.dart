import 'package:test/test.dart';
import 'package:zuraffa/src/routing/route_model.dart';
import 'package:zuraffa/src/routing/route_validator.dart';

RouteDeclaration _route(
  String viewClassName,
  String path, {
  String? parent,
  Map<String, String> params = const {},
  List<String> middleware = const [],
  bool isShell = false,
  String name = '',
}) {
  return RouteDeclaration(
    viewClassName: viewClassName,
    path: path,
    name: name.isEmpty ? viewClassName.toLowerCase() : name,
    parent: parent,
    params: params,
    middleware: middleware,
    isShell: isShell,
    importUri: 'src/views/${viewClassName.toLowerCase()}.dart',
    filePath: '/project/lib/src/views/${viewClassName.toLowerCase()}.dart',
    line: 1,
  );
}

void main() {
  group('RouteValidator', () {
    test('valid configuration passes clean', () {
      final scan = RouteScanResult(
        routes: [
          _route('HomeView', '/home'),
          _route('DashboardView', '/dashboard', isShell: true),
          _route('AnalyticsView', '/analytics', parent: 'dashboardview'),
          _route('ProductView', '/products/:id', params: {'id': 'int'}),
        ],
        redirects: [
          RouteRedirectRule(
              from: '/old', to: '/home', filePath: 'f', line: 1),
        ],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, isEmpty);
    });

    test('duplicate paths error lists BOTH classes', () {
      final scan = RouteScanResult(
        routes: [
          _route('HomeView', '/home'),
          _route('LandingView', '/home'),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('HomeView'));
      expect(errors.first.message, contains('LandingView'));
      expect(errors.first.message, contains('/home'));
    });

    test('missing parent error names the missing parent', () {
      final scan = RouteScanResult(
        routes: [
          _route('AnalyticsView', '/analytics', parent: 'ghost'),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('ghost'));
      expect(errors.first.message, contains('AnalyticsView'));
    });

    test('parent cycle error', () {
      final scan = RouteScanResult(
        routes: [
          _route('AView', '/a', parent: 'bview'),
          _route('BView', '/b', parent: 'aview'),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, isNotEmpty);
      expect(errors.first.message.toLowerCase(), contains('cycle'));
    });

    test('unsupported param type error names the type', () {
      final scan = RouteScanResult(
        routes: [
          _route('ProductView', '/products/:id', params: {'id': 'Money'}),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('Money'));
      expect(errors.first.message, contains('id'));
    });

    test('param key not present in path errors', () {
      final scan = RouteScanResult(
        routes: [
          _route('ProductView', '/products', params: {'id': 'int'}),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('id'));
      expect(errors.first.message, contains(':id'));
    });

    test('undefined redirect target errors', () {
      final scan = RouteScanResult(
        routes: [_route('HomeView', '/home')],
        redirects: [
          RouteRedirectRule(
              from: '/old', to: '/missing', filePath: 'f', line: 1),
        ],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('/missing'));
      expect(errors.first.message, contains('/old'));
    });

    test('unknown middleware guard class errors', () {
      final scan = RouteScanResult(
        routes: [
          _route('SecureView', '/secure', middleware: ['GhostGuard']),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('GhostGuard'));
    });

    test('controller type mismatch errors with both types (SC-004)', () {
      final scan = RouteScanResult(
        routes: [
          _route('ProductView', '/products/:id', params: {'id': 'int'}),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final controllerSource = '''
class ProductController {
  const ProductController({this.id});
  final String id;
}
''';
      final errors = RouteValidator.validate(
        scan,
        controllerSourceOf: (view) =>
            view.viewClassName == 'ProductView' ? controllerSource : null,
      );
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('int'));
      expect(errors.first.message, contains('String'));
      expect(errors.first.message, contains('id'));
      expect(errors.first.message, contains('ProductController'));
    });

    test('controller type match passes', () {
      final scan = RouteScanResult(
        routes: [
          _route('ProductView', '/products/:id', params: {'id': 'int'}),
        ],
        redirects: const [],
        issues: const [],
        classIndex: const {},
      );
      final controllerSource = '''
class ProductController {
  const ProductController({this.id});
  final int id;
}
''';
      final errors = RouteValidator.validate(
        scan,
        controllerSourceOf: (view) => controllerSource,
      );
      expect(errors, isEmpty);
    });

    test('strict non-View scan issues become errors', () {
      final scan = RouteScanResult(
        routes: [_route('HomeView', '/home')],
        redirects: const [],
        issues: [
          RouteScanIssue(
            message: '@Route on non-View class SomeService',
            filePath: 'some_service.dart',
            line: 2,
            isError: true,
          ),
        ],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors, hasLength(1));
      expect(errors.first.message, contains('SomeService'));
    });

    test('lenient non-View scan issues stay warnings', () {
      final scan = RouteScanResult(
        routes: [_route('HomeView', '/home')],
        redirects: const [],
        issues: [
          RouteScanIssue(
            message: '@Route on non-View class SomeService',
            filePath: 'some_service.dart',
            line: 2,
            isError: false,
          ),
        ],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan, strictNonView: false);
      expect(errors, isEmpty);
    });

    test('all errors aggregate (not fail-fast)', () {
      final scan = RouteScanResult(
        routes: [
          _route('HomeView', '/home'),
          _route('LandingView', '/home'), // duplicate
          _route('AnalyticsView', '/analytics', parent: 'ghost'), // parent
        ],
        redirects: [
          RouteRedirectRule(
              from: '/x', to: '/missing', filePath: 'f', line: 1), // redirect
        ],
        issues: const [],
        classIndex: const {},
      );
      final errors = RouteValidator.validate(scan);
      expect(errors.length, greaterThanOrEqualTo(3));
    });
  });
}
