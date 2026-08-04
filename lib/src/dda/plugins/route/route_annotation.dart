/// Annotation classes for the `@ZfaRoute` decorator-driven navigation system.
///
/// Place `@ZfaRoute(path: '/products/:id')` on a View class, then run
/// `zfa build` to auto-generate the complete GoRouter configuration.
library;

// The annotation stores route metadata as plain strings; guards receive a
// pure-Dart [ZuraffaRouteState] (see below) instead of a Flutter type.

/// Marks a View class as a route with the given [path].
///
/// ```dart
/// @ZfaRoute(path: '/products/:id', deepLinkAware: true)
/// class ProductDetailView extends StatelessWidget { ... }
/// ```
///
/// The DDA pipeline scans for `@ZfaRoute` annotations and compiles a
/// master `zfa_router.g.dart` with GoRouter configuration.
class ZfaRoute {
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
  /// @ZfaRoute(
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
  /// @ZfaRoute(path: '/profile', middleware: [AuthGuard])
  /// class ProfileView extends StatelessWidget { ... }
  /// ```
  final List<Type>? middleware;

  const ZfaRoute({
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
  /// @ZfaRoute.redirect(from: '/old-products', to: '/products')
  /// ```
  const ZfaRoute.redirect({
    required this.redirectFrom,
    required this.redirectTo,
  }) : path = '',
       name = null,
       deepLinkAware = false,
       parentPath = null,
       queryParameters = null,
       middleware = null;
}

/// Backward-compatible alias for [ZfaRoute].
///
/// @deprecated Use [ZfaRoute] instead to avoid conflicts with Flutter's Route.
@Deprecated('Use ZfaRoute instead')
typedef Route = ZfaRoute;

/// Pure-Dart route state passed to [ZuraffaRouteGuard] callbacks.
///
/// This is the platform-agnostic counterpart to `GoRouterState` (from
/// `go_router`), so route guards can be implemented in pure Dart code.
/// Flutter consumers can construct it from a `GoRouterState` via
/// `ZuraffaRouteState.fromGoRouter(state)` (see `zuraffa_flutter`).
class ZuraffaRouteState {
  /// The current route location, e.g. `'/products/42?page=2'`.
  final String location;

  /// The matched route path, e.g. `'/products/:id'`.
  final String path;

  /// The path after the matched prefix, e.g. `'/42?page=2'`.
  final String matchedLocation;

  /// Query parameters from the URI.
  final Map<String, String> queryParameters;

  /// Path parameters matched by the route pattern.
  final Map<String, String> pathParameters;

  /// Optional extra object forwarded with the navigation.
  final Object? extra;

  const ZuraffaRouteState({
    required this.location,
    required this.path,
    required this.matchedLocation,
    required this.queryParameters,
    required this.pathParameters,
    this.extra,
  });
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
///   Future<bool> canActivate(ZuraffaRouteState state) async {
///     final isLoggedIn = await AuthService.instance.isAuthenticated;
///     return isLoggedIn;
///   }
///
///   @override
///   String onRejected(ZuraffaRouteState state) => '/login';
/// }
/// ```
abstract class ZuraffaRouteGuard {
  /// Whether the route may be activated for the given [state].
  Future<bool> canActivate(ZuraffaRouteState state);

  /// The path to redirect to when [canActivate] returns `false`.
  String onRejected(ZuraffaRouteState state);
}

/// Base class for generated route parameter classes.
///
/// Each `@ZfaRoute(path: '/products/:id')` with path parameters gets a
/// generated `ProductDetailRouteParams extends RouteParams` with
/// typed fields and a `fromGoRouterState` factory.
abstract class RouteParams {
  const RouteParams();
}
