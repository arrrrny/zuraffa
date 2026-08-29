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
/// The DDA pipeline scans for `@ZfaRoute` (and its `@Route` alias)
/// annotations and compiles a master `zfa_router.g.dart` with GoRouter
/// configuration.
class ZfaRoute {
  /// The URL path pattern, e.g. `'/products/:id'`.
  ///
  /// Path parameters use `:paramName` syntax.
  /// Query parameters are declared via [queryParameters].
  final String path;

  /// Optional name for this route. Defaults to a camelCase derivation of
  /// the class name.
  final String? name;

  /// When `true`, registers the route for deep links
  /// (iOS universal links / Android app links).
  final bool deepLinkAware;

  /// When `true`, this route is a SHELL: its View renders around the child
  /// routes that reference it via [parent] or [parentPath].
  ///
  /// ```dart
  /// @ZfaRoute(path: '/dashboard', isShell: true)
  /// class DashboardShell extends StatelessWidget {
  ///   const DashboardShell({super.key, required this.child});
  ///   final Widget child; // required — the shell renders its children here
  ///   ...
  /// }
  ///
  /// @ZfaRoute(path: '/analytics', parent: 'dashboard')
  /// class AnalyticsView extends StatelessWidget { ... }
  /// ```
  final bool isShell;

  /// Optional parent route reference — either the parent route's NAME
  /// (`'dashboard'`) or its PATH (`'/dashboard'`). The parent must be
  /// declared with [isShell] set.
  ///
  /// Aliased by [parentPath] (path-only, legacy spelling); both are
  /// accepted.
  final String? parent;

  /// Optional parent route path for nested routing (legacy spelling of
  /// [parent], path references only).
  ///
  /// When set, this route is rendered inside a `ShellRoute` keyed by the
  /// parent path. Multiple routes sharing the same parent are grouped under
  /// one shell route.
  final String? parentPath;

  /// Optional redirect source path. When set alongside [redirectTo],
  /// generates a redirect rule.
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

  /// Path parameter types, e.g. `{'id': 'int'}` for
  /// `path: '/products/:id'`.
  ///
  /// Path parameters default to `String`; declare `int`, `double`, or
  /// `bool` here to generate typed fields (SC-004 compile-time safety).
  final Map<String, String>? pathParameters;

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
    this.isShell = false,
    this.parent,
    this.parentPath,
    this.redirectFrom,
    this.redirectTo,
    this.queryParameters,
    this.pathParameters,
    this.middleware,
  });

  /// Convenience constructor for redirect-only route entries.
  ///
  /// ```dart
  /// @ZfaRoute.redirect(from: '/old-products', to: '/products')
  /// ```
  ///
  /// The `@Route.redirect(...)` spelling works identically.
  const ZfaRoute.redirect({
    required this.redirectFrom,
    required this.redirectTo,
  }) : path = '',
       name = null,
       deepLinkAware = false,
       isShell = false,
       parent = null,
       parentPath = null,
       queryParameters = null,
       pathParameters = null,
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
