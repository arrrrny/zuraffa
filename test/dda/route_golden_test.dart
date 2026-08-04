import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Golden: Track 6.1 — @Route DDA Plugin', () {
    late RouteGenerator gen;

    setUp(() => gen = RouteGenerator());

    // ── Route Registration ──

    test('golden: basic route generates GoRouter config', () {
      gen.addRoute(
        path: '/home',
        name: 'home',
        className: 'HomeView',
        importUri: 'package:myapp/views/home_view.dart',
        deepLinkAware: false,
      );

      final output = gen.generate();

      expect(output, contains('createZfaRouter'));
      expect(output, contains('GoRouter'));
      expect(output, contains("path: '/home'"));
      expect(output, contains("name: 'home'"));
      expect(output, contains('HomeView'));
      expect(output, contains('zfa DDA pipeline'));
    });

    test('golden: path parameter :id generates RouteParams class', () {
      gen.addRoute(
        path: '/products/:id',
        name: 'productDetail',
        className: 'ProductDetailView',
        importUri: 'package:myapp/views/product_detail_view.dart',
        deepLinkAware: true,
      );

      final output = gen.generate();

      expect(output, contains('ProductDetailViewRouteParams'));
      expect(output, contains('class ProductDetailViewRouteParams'));
      expect(output, contains('extends RouteParams'));
      expect(output, contains('fromGoRouterState'));
      expect(output, contains("path: '/products/:id'"));
      expect(output, contains('Deep-link-aware'));
    });

    test('golden: redirect generates redirect rules', () {
      gen.addRedirect(from: '/old-products', to: '/products');

      final output = gen.generate();

      expect(output, contains('/old-products'));
      expect(output, contains('/products'));
    });

    test('golden: nested routes via parentPath', () {
      gen.addRoute(
        path: '/dashboard',
        name: 'dashboard',
        className: 'DashboardShell',
        importUri: 'package:myapp/views/dashboard_shell.dart',
        parentPath: '/dashboard',
      );
      gen.addRoute(
        path: '/dashboard/settings',
        name: 'dashboardSettings',
        className: 'DashboardSettingsView',
        importUri: 'package:myapp/views/settings_view.dart',
        parentPath: '/dashboard',
      );

      final output = gen.generate();

      expect(output, contains('ShellRoute'));
      expect(output, contains('/dashboard'));
      expect(output, contains('DashboardSettingsView'));
    });

    test('golden: middleware guards generate redirect wrapper', () {
      gen.addRoute(
        path: '/profile',
        name: 'profile',
        className: 'ProfileView',
        importUri: 'package:myapp/views/profile_view.dart',
        middleware: ['AuthGuard'],
      );

      final output = gen.generate();

      expect(output, contains('AuthGuard'));
      expect(output, contains('canActivate'));
      expect(output, contains('onRejected'));
    });

    test('golden: query parameters included in RouteParams', () {
      gen.addRoute(
        path: '/search',
        name: 'search',
        className: 'SearchView',
        importUri: 'package:myapp/views/search_view.dart',
        queryParameters: {'q': 'String', 'page': 'int'},
      );

      final output = gen.generate();

      expect(output, contains('SearchViewRouteParams'));
      expect(output, contains('queryParameters'));
    });

    test('golden: route name is preserved', () {
      gen.addRoute(
        path: '/products/:id',
        name: 'productDetail',
        className: 'ProductDetailView',
        importUri: 'package:myapp/views/product_detail_view.dart',
      );

      final output = gen.generate();
      expect(output, contains("name: 'productDetail'"));
    });

    test(
      'acceptance: multiple routes produce complete GoRouter configuration',
      () {
        // Home route
        gen.addRoute(
          path: '/',
          name: 'home',
          className: 'HomeView',
          importUri: 'package:myapp/views/home_view.dart',
        );

        // Product list
        gen.addRoute(
          path: '/products',
          name: 'productList',
          className: 'ProductListView',
          importUri: 'package:myapp/views/product_list_view.dart',
        );

        // Product detail with path param and deep link
        gen.addRoute(
          path: '/products/:id',
          name: 'productDetail',
          className: 'ProductDetailView',
          importUri: 'package:myapp/views/product_detail_view.dart',
          deepLinkAware: true,
        );

        // Profile with guard
        gen.addRoute(
          path: '/profile',
          name: 'profile',
          className: 'ProfileView',
          importUri: 'package:myapp/views/profile_view.dart',
          middleware: ['AuthGuard'],
        );

        // Redirect
        gen.addRedirect(from: '/legacy', to: '/');

        final output = gen.generate();

        // All routes present
        expect(output, contains("path: '/'"));
        expect(output, contains("path: '/products'"));
        expect(output, contains("path: '/products/:id'"));
        expect(output, contains("path: '/profile'"));
        expect(output, contains('/legacy'));

        // Params class for product detail
        expect(output, contains('ProductDetailViewRouteParams'));

        // Guard on profile
        expect(output, contains('AuthGuard'));

        // GoRouter factory
        expect(output, contains('createZfaRouter'));
        expect(output, contains('GoRouter('));

        // All view imports
        expect(output, contains('home_view.dart'));
        expect(output, contains('product_list_view.dart'));
        expect(output, contains('product_detail_view.dart'));
        expect(output, contains('profile_view.dart'));
      },
    );

    test('generator: hasRoutes reflects state', () {
      expect(gen.hasRoutes, isFalse);
      gen.addRoute(
        path: '/test',
        name: 'test',
        className: 'TestView',
        importUri: 'package:myapp/views/test_view.dart',
      );
      expect(gen.hasRoutes, isTrue);
    });

    test('generator: redirect-only hasRoutes is true', () {
      gen.addRedirect(from: '/a', to: '/b');
      expect(gen.hasRoutes, isTrue);

      final output = gen.generate();
      expect(output, contains('/a'));
      expect(output, contains('/b'));
    });

    test('generator: multiple path params generate all fields', () {
      gen.addRoute(
        path: '/users/:userId/orders/:orderId',
        name: 'orderDetail',
        className: 'OrderDetailView',
        importUri: 'package:myapp/views/order_detail_view.dart',
      );

      final output = gen.generate();

      expect(output, contains('OrderDetailViewRouteParams'));
      expect(output, contains('userId'));
      expect(output, contains('orderId'));
      expect(output, contains('String userId'));
      expect(output, contains('String orderId'));
    });
  });
}
