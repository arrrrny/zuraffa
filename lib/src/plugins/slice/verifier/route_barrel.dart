/// RouteBarrel (feature 074, issue #962): the pure, deterministic
/// regeneration of the host's route barrel — merge invokes the same
/// seam the route capabilities use, so the host router file is never
/// hand-edited and re-merging a merged feature is a byte no-op.
library;

/// One declared route of the feature being merged.
class RouteDecl {
  final String path;
  final String page;

  /// The feature module the route came from (conflict attribution).
  final String module;

  const RouteDecl({
    required this.path,
    required this.page,
    this.module = 'feature',
  });
}

/// The regenerated barrel plus any conflicts found.
class RouteRegeneration {
  final String barrel;
  final List<String> conflicts;

  const RouteRegeneration({required this.barrel, required this.conflicts});

  bool get passed => conflicts.isEmpty;
}

/// Parses, regenerates, and resolves the host route barrel.
abstract final class RouteBarrel {
  /// One route entry of the barrel, e.g.
  /// `route('/login', page: LoginPage(), // module: login`.
  static final RegExp _entry = RegExp(
    r"""route\('([^']+)',\s*page:\s*([A-Za-z_][A-Za-z0-9_]*)""",
  );

  /// Regenerate the barrel additively: existing entries are kept,
  /// incoming entries are appended (deduplicated), and the result is
  /// deterministic — identical inputs produce a byte-identical barrel.
  ///
  /// A route collision (same path or same page name already registered
  /// from another module) refuses BEFORE any landing, naming both.
  static RouteRegeneration regenerate({
    required String barrelSource,
    required String module,
    required List<RouteDecl> incoming,
  }) {
    final existing = <({String path, String page})>[
      for (final m in _entry.allMatches(barrelSource))
        (path: m.group(1)!, page: m.group(2)!),
    ];

    final conflicts = <String>[];
    final additions = <({String path, String page})>[];
    for (final route in incoming) {
      for (final e in existing) {
        if (e.path == route.path && e.page != route.page) {
          conflicts.add(
            'route path "${route.path}" already registered as ${e.page} '
            '(module: $module declares ${route.page}) --> fix: rename the '
            'incoming route module or remove the stale host route.',
          );
        }
        if (e.page == route.page && e.path != route.path) {
          conflicts.add(
            'page "${route.page}" already registered at "${e.path}" '
            '(module: $module declares "${route.path}") --> fix: rename '
            'the incoming route module or remove the stale host route.',
          );
        }
      }
      final duplicate =
          existing.any((e) => e.path == route.path && e.page == route.page) ||
          additions.any((a) => a.path == route.path);
      if (!duplicate && conflicts.isEmpty) {
        additions.add((path: route.path, page: route.page));
      }
    }
    if (conflicts.isNotEmpty) {
      return RouteRegeneration(barrel: barrelSource, conflicts: conflicts);
    }

    // Deterministic emission: existing lines verbatim (byte-stable for
    // a re-merge), then the additions sorted by path.
    final buffer = StringBuffer(barrelSource);
    for (final addition
        in additions.toList()..sort((a, b) => a.path.compareTo(b.path))) {
      buffer.writeln();
      buffer.write(
        "route('${addition.path}', page: ${addition.page}(), // module: $module",
      );
      buffer.write(')');
    }
    return RouteRegeneration(barrel: buffer.toString(), conflicts: const []);
  }

  /// The resolution proof: every declared path must reach its declared
  /// page through the generated table. Pure traversal, per-route
  /// offenders.
  static List<String> resolutionOffenders({
    required String barrelSource,
    required List<RouteDecl> declared,
  }) {
    final table = <String, String>{
      for (final m in _entry.allMatches(barrelSource)) m.group(1)!: m.group(2)!,
    };
    return [
      for (final route in declared)
        if (table[route.path] != route.page)
          "route '${route.path}' does not resolve to ${route.page} in the "
              'regenerated barrel --> fix: re-run the route registration '
              '(the barrel must expose every declared route).',
    ];
  }
}
