/// Annotation classes for the `@Route` decorator-driven navigation system.
///
/// Place `@Route(path: '/products/:id')` on a View class, then run
/// `zfa build` to auto-generate the complete GoRouter configuration.
library;


/// Marks a View class as a route with the given [path].
///
/// ```dart
/// @Route(path: '/products/:id', deepLinkAware: true)
/// class ProductDetailView extends StatelessWidget { ... }
/// ```
///
/// The DDA pipeline scans for `@Route` annotations and compiles a
/// master `zfa_router.g.dart` with GoRouter configuration.
class Route {
  /// The URL path pattern, e.g. `'/products/:id'`.
  ///
  /// Path parameters use `:paramName` syntax.
  /// Query parameters are declared via [queryParameters].
  final String path;

  /// Optional name for this route. Defaults to the class name.
  final String? name;

  /// When `true`, registers the route for deep links
  /// (iOS universal links / Android app links).
  final bool deepLinkAware;

  /// Optional parent route path for nested routing.
  ///
  /// When set, this route is rendered inside a `ShellRoute`
  /// keyed by [parentPath]. Multiple routes sharing the same
  /// [parentPath] are grouped under one shell route.
  final String? parentPath;

  /// Optional redirect source path. When set alongside [redirectTo],
  /// generates a `GoRoute(redirect: ...)` rule.
  final String? redirectFrom;

  /// Optional redirect target path. Used with [redirectFrom].
  final String? redirectTo;

  /// Query parameter names and their Dart types.
  ///
  /// ```dart
  /// @Route(
  ///   path: '/search',
  ///   queryParameters: {'q': 'String', 'page': 'int'},
  /// )
  /// class SearchView extends StatelessWidget { ... }
  /// ```
  ///
  /// Keys are query param names, values are Dart type strings.
  final Map<String, String>? queryParameters;

  /// Guard classes that must be checked before the route activates.
  ///
  /// Each guard must implement [ZuraffaRouteGuard]. Guards are
  /// executed in order; if any returns `false`, the redirect
  /// callback is invoked.
  ///
  /// ```dart
  /// @Route(path: '/profile', middleware: [AuthGuard])
  /// class ProfileView extends StatelessWidget { ... }
  /// ```
  final List<Type>? middleware;

  const Route({
    required this.path,
    this.name,
    this.deepLinkAware = false,
    this.parentPath,
    this.redirectFrom,
    this.redirectTo,
    this.queryParameters,
    this.middleware,
  });

  /// Convenience constructor for redirect-only route entries.
  ///
  /// ```dart
  /// @Route.redirect(from: '/old-products', to: '/products')
  /// ```
  const Route.redirect({
    required this.redirectFrom,
    required this.redirectTo,
  }) : path = '',
       name = null,
       deepLinkAware = false,
       parentPath = null,
       queryParameters = null,
       middleware = null;
}

/// Base class for route guard / middleware implementations.
///
/// Guards are evaluated before a route is activated. If [canActivate]
/// returns `false`, the route is not shown and the user is redirected
/// via [onRejected].
///
/// ```dart
/// class AuthGuard extends ZuraffaRouteGuard {
///   @override
///   Future<bool> canActivate(GoRouterState state) async {
///     final isLoggedIn = await AuthService.instance.isAuthenticated;
///     return isLoggedIn;
///   }
///
///   @override
///   String onRejected(GoRouterState state) => '/login';
/// }
/// ```
abstract class ZuraffaRouteGuard {
  /// Whether the route may be activated for the given [state].
  Future<bool> canActivate(GoRouterState state);

  /// The path to redirect to when [canActivate] returns `false`.
  String onRejected(GoRouterState state);
}

/// Stub for GoRouterState — users import the real one from `go_router`.
/// This avoids a hard `go_router` dependency in the annotation-only file.
class GoRouterState {
  final String matchedLocation;
  final String fullPath;
  final Map<String, String> pathParameters;
  final Map<String, String> uriQueryParameters;

  const GoRouterState({
    this.matchedLocation = '',
    this.fullPath = '',
    this.pathParameters = const {},
    this.uriQueryParameters = const {},
  });
}

/// Base class for generated route parameter classes.
///
/// Each `@Route(path: '/products/:id')` with path parameters gets a
/// generated `ProductDetailRouteParams extends RouteParams` with
/// typed fields and `fromGoRouterState` factory.
abstract class RouteParams {
  const RouteParams();
}
