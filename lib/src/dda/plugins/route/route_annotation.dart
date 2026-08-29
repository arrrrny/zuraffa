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

  /// Whether this route is a SHELL route hosting nested child routes
  /// (spec 033 FR-007). The shell View renders the shared chrome and
  /// receives the active child via its `child` constructor parameter
  /// when it declares one.
  final bool isShell;

  /// Name of the parent SHELL route this route nests under (spec 033
  /// FR-007). Unlike [parentPath] (path-keyed), this references the
  /// parent route's [name].
  final String? parent;

  /// Redirect rule attached to this route (spec 033 FR-001):
  /// `@Route(redirect: RouteRedirect(from: '/old', to: '/new'))`.
  final RouteRedirect? redirect;

  /// Typed PATH parameters (spec 033 US-7): `{'id': int}` — supported
  /// types: `String`, `int`, `double`, `bool`. Unlisted `:params`
  /// default to `String`.
  final Map<String, Type>? params;

  /// Where to send users when a guard denies activation without an
  /// explicit [ZuraffaRouteGuard.onRejected] override (spec 033 US-5);
  /// recorded as the generated default deny path.
  final String? guardRedirect;

  const ZfaRoute({
    required this.path,
    this.name,
    this.deepLinkAware = false,
    this.parentPath,
    this.redirectFrom,
    this.redirectTo,
    this.queryParameters,
    this.middleware,
    this.isShell = false,
    this.parent,
    this.redirect,
    this.params,
    this.guardRedirect,
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
       middleware = null,
       isShell = false,
       parent = null,
       redirect = null,
       params = null,
       guardRedirect = null;
}

/// Spec 033 name for [ZfaRoute] — the canonical annotation spelling per
/// `specs/033-route-decorator-nav` FR-001 (`@Route(path: ...)` and
/// `@Route.redirect(from: ..., to: ...)`).
typedef Route = ZfaRoute;

/// Redirect configuration for `@Route(redirect: ...)` (spec 033 FR-001).
class RouteRedirect {
  /// URL pattern that should be redirected away from.
  final String from;

  /// Target URL that exists in the route configuration.
  final String to;

  const RouteRedirect({required this.from, required this.to});
}

/// Pure-Dart route state passed to [ZuraffaRouteGuard] callbacks.
///
/// This is the platform-agnostic counterpart to `GoRouterState` (from
/// `go_router`), so route guards can be implemented in pure Dart code.
/// The generated router code includes an adapter that constructs
/// [ZuraffaRouteState] from `GoRouterState` for middleware evaluation.
class ZuraffaRouteState {
  /// The current route location, e.g. `'/products/42?page=2'`.
  final String location;

  /// The route template pattern, e.g. `'/products/:id'`.
  final String path;

  /// The matched URI location, e.g. `'/products/42'`.
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
