// RouteDriftDetector — finds routes that the CLI plugin and the DDA plugin
// declared at the same path. One finding per overlapping path; the finding
// names every source file involved so a developer can jump to either side.
//
// Bug: route-dual-system-unreconciled.

import 'route_table.dart';

/// One drift finding: the same `path` was declared by two different
/// generators, with at least one from `cli` and one from `dda`.
class RouteDrift {
  const RouteDrift({required this.path, required this.sources});

  final String path;
  final List<RouteEntry> sources;
}

/// Pure, deterministic detector. Holds no I/O.
class RouteDriftDetector {
  const RouteDriftDetector();

  /// Returns every drift finding in [table]. The order of the returned
  /// list is sorted by `path` ascending so two calls over the same input
  /// return the same order — important for stable `--json` and `--plain`
  /// output.
  List<RouteDrift> detect(RouteTable table) {
    final byPath = <String, List<RouteEntry>>{};
    for (final entry in table.routes) {
      byPath.putIfAbsent(entry.path, () => []).add(entry);
    }
    final drifts = <RouteDrift>[];
    for (final entry in byPath.entries) {
      final sources = entry.value;
      final hasCli = sources.any((e) => e.source == RouteSource.cli);
      final hasDda = sources.any((e) => e.source == RouteSource.dda);
      if (hasCli && hasDda) {
        drifts.add(RouteDrift(path: entry.key, sources: sources));
      }
    }
    drifts.sort((a, b) => a.path.compareTo(b.path));
    return drifts;
  }
}
