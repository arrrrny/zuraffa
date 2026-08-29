import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// U25–U33 (SC-003 / FR-006): every misconfiguration category is caught by the
// route validator with an actionable error before any file is written.

void main() {
  group('RouteValidator', () {
    late RouteValidator validator;

    setUp(() => validator = RouteValidator());

    RouteEntryInfo route(
      String path,
      String className, {
      String? name,
      bool isShell = false,
      String? parent,
      Map<String, String> pathParameters = const {},
      Map<String, String> queryParameters = const {},
    }) => RouteEntryInfo(
      path: path,
      name: name ?? className,
      className: className,
      importUri: 'package:app/views/a.dart',
      isShell: isShell,
      parent: parent,
      pathParameters: pathParameters,
      queryParameters: queryParameters,
    );

    test('duplicate path errors naming both classes and the path', () {
      final errors = validator.validate(
        routes: [
          route('/products', 'ProductsView'),
          route('/products', 'CatalogView'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      final dup = errors
          .where((e) => e.code == RouteValidationErrorCode.duplicatePath)
          .toList();
      expect(dup, hasLength(1));
      expect(dup.first.message, contains('/products'));
      expect(dup.first.message, contains('ProductsView'));
      expect(dup.first.message, contains('CatalogView'));
    });

    test('duplicate route name errors', () {
      final errors = validator.validate(
        routes: [
          route('/a', 'AView', name: 'home'),
          route('/b', 'BView', name: 'home'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        errors.where((e) => e.code == RouteValidationErrorCode.duplicateName),
        hasLength(1),
      );
    });

    test('missing parent errors naming parent ref and child class', () {
      final errors = validator.validate(
        routes: [
          route('/dashboard', 'DashboardShell', isShell: true),
          route('/analytics', 'AnalyticsView', parent: 'nonexistent'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      final missing = errors
          .where((e) => e.code == RouteValidationErrorCode.missingParent)
          .toList();
      expect(missing, hasLength(1));
      expect(missing.first.message, contains('nonexistent'));
      expect(missing.first.message, contains('AnalyticsView'));
    });

    test('parent referencing a non-shell route errors', () {
      final errors = validator.validate(
        routes: [
          route('/plain', 'PlainView'),
          route('/plain/child', 'ChildView', parent: '/plain'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        errors.where((e) => e.code == RouteValidationErrorCode.parentNotShell),
        hasLength(1),
      );
    });

    test('non-View annotation target errors with class name and location', () {
      final errors = validator.validate(
        routes: const [],
        redirects: const [],
        nonViewTargets: const [
          NonViewTargetInfo(
            className: 'SomeRandomClass',
            reason: 'class name does not end in View/Shell/Page/Screen',
            filePath: 'lib/src/foo.dart',
            line: 7,
          ),
        ],
        pubspecDeps: const {'go_router'},
      );
      final nonView = errors
          .where((e) => e.code == RouteValidationErrorCode.nonViewTarget)
          .toList();
      expect(nonView, hasLength(1));
      expect(nonView.first.message, contains('SomeRandomClass'));
      expect(nonView.first.filePath, equals('lib/src/foo.dart'));
      expect(nonView.first.line, equals(7));
    });

    test(
      'unsupported path parameter type errors naming type and allowed set',
      () {
        final errors = validator.validate(
          routes: [
            route(
              '/items/:id',
              'ItemsView',
              pathParameters: {'id': 'Duration'},
            ),
          ],
          redirects: const [],
          nonViewTargets: const [],
          pubspecDeps: const {'go_router'},
        );
        final unsupported = errors
            .where(
              (e) => e.code == RouteValidationErrorCode.unsupportedParamType,
            )
            .toList();
        expect(unsupported, hasLength(1));
        expect(unsupported.first.message, contains('Duration'));
        expect(unsupported.first.message, contains('String'));
        expect(unsupported.first.message, contains('int'));
      },
    );

    test('unsupported query parameter type errors too', () {
      final errors = validator.validate(
        routes: [
          route('/search', 'SearchView', queryParameters: {'when': 'DateTime'}),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        errors.where(
          (e) => e.code == RouteValidationErrorCode.unsupportedParamType,
        ),
        hasLength(1),
      );
    });

    test('redirect to an undefined target errors', () {
      final errors = validator.validate(
        routes: [route('/home', 'HomeView')],
        redirects: const [
          RedirectRuleInfo(from: '/legacy', to: '/does-not-exist'),
        ],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      final dangling = errors
          .where(
            (e) => e.code == RouteValidationErrorCode.danglingRedirectTarget,
          )
          .toList();
      expect(dangling, hasLength(1));
      expect(dangling.first.message, contains('/does-not-exist'));
      expect(dangling.first.message, contains('/legacy'));
    });

    test('redirect to a declared route path is accepted', () {
      final errors = validator.validate(
        routes: [route('/home', 'HomeView')],
        redirects: const [RedirectRuleInfo(from: '/legacy', to: '/home')],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        errors.where(
          (e) => e.code == RouteValidationErrorCode.danglingRedirectTarget,
        ),
        isEmpty,
      );
    });

    test(
      'routes present without go_router dependency error with install hint',
      () {
        final errors = validator.validate(
          routes: [route('/home', 'HomeView')],
          redirects: const [],
          nonViewTargets: const [],
          pubspecDeps: const {'http'},
        );
        final missing = errors
            .where((e) => e.code == RouteValidationErrorCode.goRouterMissing)
            .toList();
        expect(missing, hasLength(1));
        expect(missing.first.message, contains('go_router'));
      },
    );

    test('no routes and no go_router is fine (nothing will be generated)', () {
      final errors = validator.validate(
        routes: const [],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'http'},
      );
      expect(errors, isEmpty);
    });

    test('clean project validates with zero errors', () {
      final errors = validator.validate(
        routes: [
          route('/dashboard', 'DashboardShell', isShell: true),
          route('/dashboard/analytics', 'AnalyticsView', parent: 'dashboard'),
          route('/items/:id', 'ItemsView', pathParameters: {'id': 'int'}),
        ],
        redirects: const [RedirectRuleInfo(from: '/legacy', to: '/dashboard')],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router', 'flutter'},
      );
      expect(errors, isEmpty);
    });

    test('parent resolves by name, by path, and by slash-prefixed path', () {
      final byName = validator.validate(
        routes: [
          route('/dashboard', 'DashboardShell', isShell: true),
          route('/analytics', 'AnalyticsView', parent: 'dashboard'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        byName.where((e) => e.code == RouteValidationErrorCode.missingParent),
        isEmpty,
      );

      final byPath = validator.validate(
        routes: [
          route('/dashboard', 'DashboardShell', isShell: true),
          route('/analytics', 'AnalyticsView', parent: '/dashboard'),
        ],
        redirects: const [],
        nonViewTargets: const [],
        pubspecDeps: const {'go_router'},
      );
      expect(
        byPath.where((e) => e.code == RouteValidationErrorCode.missingParent),
        isEmpty,
      );
    });
  });
}
