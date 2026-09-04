// RouteTable — the union DTO for routes discovered from both the CLI plugin
// (`lib/src/plugins/route/`) and the DDA annotation plugin
// (`lib/src/dda/plugins/route/`).
//
// Bug: route-dual-system-unreconciled — without a single DTO, the two
// generators cannot be compared for drift, and their output cannot be
// surfaced as a stable JSON artifact.
//
// The shape is intentionally tiny: a `version`, a list of `RouteEntry`s,
// and a `RouteSource` enum that names the originating generator. Encoding
// is stable (entries sorted by `path`, then by `source`) so two runs over
// the same on-disk reality produce byte-identical JSON — which is what
// `zfa route verify --json` advertises.

import 'dart:convert';

/// Which generator declared a [RouteEntry].
///
/// `cli` comes from the entity-driven `lib/src/plugins/route/` plugin
/// (writes `*_routes.dart`). `dda` comes from the annotation-driven
/// `lib/src/dda/plugins/route/` plugin (writes `zfa_router.g.dart`).
enum RouteSource { cli, dda }

/// A single route declaration collected from one of the generators.
class RouteEntry {
  const RouteEntry({
    required this.path,
    required this.name,
    required this.source,
    required this.file,
    required this.line,
  });

  /// The route path, e.g. `/products`.
  final String path;

  /// The route name (entity name on the CLI side, View class on the DDA side).
  final String name;

  /// Which generator declared this route.
  final RouteSource source;

  /// The file the route was declared in. Used for drift findings so a
  /// developer can jump to the offending line.
  final String file;

  /// 1-based line number inside [file].
  final int line;

  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'source': source.name,
    'file': file,
    'line': line,
  };

  @override
  bool operator ==(Object other) =>
      other is RouteEntry &&
      other.path == path &&
      other.name == name &&
      other.source == source &&
      other.file == file &&
      other.line == line;

  @override
  int get hashCode => Object.hash(path, name, source, file, line);
}

/// The union of all routes declared in a project, across both generators.
class RouteTable {
  const RouteTable({required this.version, required this.routes});

  /// The schema version of the JSON encoding. Bump when [RouteEntry] gains
  /// a field; consumers should refuse unknown majors.
  final int version;

  /// Every route discovered, in arbitrary order at the API boundary; the
  /// JSON encoding sorts deterministically.
  final List<RouteEntry> routes;

  /// Convenience constructor that merges CLI- and DDA-discovered entries.
  factory RouteTable.union({
    List<RouteEntry> cli = const [],
    List<RouteEntry> dda = const [],
  }) {
    return RouteTable(
      version: 1,
      routes: [...cli, ...dda],
    );
  }

  /// Returns a stable JSON encoding. The output is a single line with no
  /// trailing newline — `zfa route verify --json` pipes this to consumers.
  String toJsonString() {
    final sorted = [...routes]..sort((a, b) {
      final byPath = a.path.compareTo(b.path);
      if (byPath != 0) return byPath;
      return a.source.name.compareTo(b.source.name);
    });
    return jsonEncode({
      'version': version,
      'routes': sorted.map((e) => e.toJson()).toList(),
    });
  }
}
