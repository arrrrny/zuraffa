/// SandboxScaffold (feature 073, issue #961): the deterministic
/// runnable-sandbox generators `slice cut` composes on top of the
/// artifact export — shell bootstrap, router harness, mock-DI wiring.
///
/// Pure: manifest facts in, file contents out. No I/O, no timestamps —
/// identical cut inputs ⇒ byte-identical scaffolding (data-model I3).
library;

import '_pascal_case.dart';

/// One declared route of the feature (declared at cut, recorded in the
/// slice manifest).
class SandboxRoute {
  final String path;
  final String page;

  const SandboxRoute({required this.path, required this.page});
}

/// One declared dependency binding (declared at cut from the 072
/// dependency-mock rail rows).
class SandboxBinding {
  final String dependency;
  final String kind;

  /// Certified mock artifact path relative to the sandbox (e.g.
  /// `test/mock/dependencies/firebase_auth/firebase_auth_fake.dart`).
  final String mockArtifact;

  const SandboxBinding({
    required this.dependency,
    required this.kind,
    required this.mockArtifact,
  });

  /// The DI registration key: `dependencies/<snake>`.
  String get token => 'dependencies/${_snake(dependency)}';

  static String _snake(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}

/// The runtime route table the generated `lib/router.dart` mirrors.
///
/// Resolution is exact-match over the declared routes: a declared path
/// resolves to its page; anything else refuses naming the offending
/// path (errors-are-an-api).
class SliceRouteTable {
  final Map<String, String> _routes;

  SliceRouteTable(List<SandboxRoute> routes)
    : _routes = {for (final r in routes) r.path: r.page};

  /// The declared path → page map (insertion order preserved).
  Map<String, String> get routes => Map.unmodifiable(_routes);

  /// Resolve a declared route to its page widget name.
  ///
  /// Throws [StateError] naming the path for any undeclared route —
  /// the harness exposes EXACTLY the declared routes.
  String resolve(String path) {
    final page = _routes[path];
    if (page == null) {
      throw StateError(
        'unrouted slice path: $path --> fix: declare it in the slice '
        'manifest routes (issue #961 router harness exposes only '
        'declared routes)',
      );
    }
    return page;
  }
}

/// The runtime locator twin of the `SandboxLocator` class the generated
/// `lib/di.dart` embeds — same semantics, exercised by the sandbox
/// suite against the sandbox's own copy.
class SandboxLocator {
  final Map<String, Object Function()> _factories =
      <String, Object Function()>{};
  final Map<String, Object> _singletons = <String, Object>{};

  void bind(String token, Object Function() factory) =>
      _factories[token] = factory;

  Object resolve(String token) {
    if (_singletons.containsKey(token)) return _singletons[token]!;
    final factory = _factories[token];
    if (factory == null) {
      throw StateError(
        'unbound sandbox token: $token --> fix: declare the dependency '
        'at cut so the certified mock binds (issue #961 mock DI)',
      );
    }
    return _singletons[token] = factory();
  }

  bool isBound(String token) => _factories.containsKey(token);
}

/// The sandbox files `cut` scaffolds.
abstract final class SandboxScaffold {
  /// `lib/main.dart` — the shell bootstrap pumping the feature shell
  /// with mock DI.
  static String main({required String feature}) => '''
// GENERATED — slice sandbox for $feature (issue #961).
//
// Runnable on certified mocks alone: no host imports, no whole-app boot.
library;

import 'package:flutter/material.dart';

import 'di.dart';
import 'router.dart';

Future<void> main() async {
  bindSandboxDependencies();
  runApp(SliceApp());
}

/// The sandbox app: the feature shell over the slice router.
class SliceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: buildSliceRouter());
  }
}
''';

  /// `lib/router.dart` — the router harness exposing exactly the
  /// declared routes.
  static String router({required List<SandboxRoute> routes}) {
    final entries = routes
        .map((r) => "    '${r.path}': (ctx) => ${r.page}(),")
        .join('\n');
    return '''
// GENERATED — slice router harness (issue #961).
//
// Exposes EXACTLY the declared slice routes — nothing else is routable.
library;

import 'package:flutter/material.dart';

/// Build the slice router: every declared route resolves to its page.
Map<String, WidgetBuilder> sliceRoutes() {
  return <String, WidgetBuilder>{
$entries
  };
}

/// Navigation helper the shell and tests share.
Widget pageFor(String path) {
  final routes = sliceRoutes();
  final builder = routes[path];
  if (builder == null) {
    throw StateError(
      'unrouted slice path: \$path --> fix: declare it in the slice '
      'manifest routes (issue #961 router harness exposes only '
      'declared routes)',
    );
  }
  return builder(builder);
}
''';
  }

  /// `lib/di.dart` — mock-DI bindings, one per declared dependency.
  static String di({required List<SandboxBinding> bindings}) {
    final registrations = bindings
        .map(
          (b) => "  sandbox.bind('${b.token}', build${pascalCase(b.dependency)});"
              " // ${b.kind}: certified mock (${b.mockArtifact})",
        )
        .join('\n');
    final builders = bindings
        .map(
          (b) => '''
/// Certified mock builder for ${b.dependency} — wired from
/// `${b.mockArtifact}` (the 072 dependency-mock rail).
Object build${pascalCase(b.dependency)}() =>
    throw UnsupportedError(
      'wire the certified ${b.dependency} mock here --> fix: the artifact '
      'lives at ${b.mockArtifact} (issue #961 sandbox composition)',
    );
''',
        )
        .join('\n');
    return '''
// GENERATED — slice mock-DI wiring (issue #961).
//
// Every declared dependency touchpoint binds a CERTIFIED mock — the
// sandbox runs on simulation alone (VISION §9).

/// The sandbox locator: deterministic, registration-order stable, no
/// host dependencies.
class SandboxLocator {
  final Map<String, Object Function()> _factories =
      <String, Object Function()>{};
  final Map<String, Object> _singletons = <String, Object>{};

  void bind(String token, Object Function() factory) =>
      _factories[token] = factory;

  Object resolve(String token) {
    if (_singletons.containsKey(token)) return _singletons[token]!;
    final factory = _factories[token];
    if (factory == null) {
      throw StateError(
        'unbound sandbox token: \$token --> fix: declare the dependency '
        'at cut so the certified mock binds (issue #961 mock DI)',
      );
    }
    return _singletons[token] = factory();
  }

  bool isBound(String token) => _factories.containsKey(token);
}

/// The sandbox locator instance.
final SandboxLocator sandbox = SandboxLocator();

void bindSandboxDependencies() {
$registrations
}

$builders
''';
  }
}

