/// Resolves the names `package:zuraffa/zuraffa.dart` actually exports in
/// the TARGET project (issue #1176/#942 family).
///
/// The generators hide the entity's own symbols from the framework
/// barrel (`#942`: an entity named like a core export collides at the
/// import). But the barrel only warns (`undefined_hidden_name`) — and
/// `zfa build`'s analyze gate fails on warnings — when the hidden name
/// is not exported at all. This resolver reads the target project's
/// `.dart_tool/package_config.json`, finds the resolved `zuraffa` root,
/// and walks the barrel's export graph collecting top-level type names,
/// so the emitted hide list contains only names that exist.
///
/// Seed once per generation (`seed`, called from
/// `PluginManager.buildContext`); builders then filter through
/// [filter]. Unresolved (no seed, no package_config) → `null` → callers
/// keep the legacy unconditional hide.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ZuraffaBarrelExports {
  ZuraffaBarrelExports._(this.names);

  final Set<String> names;

  static ZuraffaBarrelExports? _seeded;

  /// Seed from [projectRoot] (the generation target). Safe to call
  /// repeatedly; the resolution is cached until [reset].
  static void seed(String projectRoot) {
    _seeded = _resolve(projectRoot);
  }

  /// Test seam: seed with an explicit name set.
  static void seedForTest(Set<String> names) {
    _seeded = ZuraffaBarrelExports._(names);
  }

  static void reset() => _seeded = null;

  /// The current resolution, or null when never seeded / unresolvable.
  static ZuraffaBarrelExports? get current => _seeded;

  /// Filters [hides] to names the barrel actually exports. Unresolved →
  /// legacy behavior (keep every name).
  static List<String> filter(Iterable<String> hides) {
    final seed = _seeded;
    if (seed == null) return hides.toList();
    return hides.where(seed.names.contains).toList();
  }

  static ZuraffaBarrelExports? _resolve(String projectRoot) {
    try {
      final config = File(
        p.join(projectRoot, '.dart_tool', 'package_config.json'),
      );
      if (!config.existsSync()) return null;
      final decoded =
          jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
      final packages = decoded['packages'] as List<dynamic>;
      final zuraffa =
          packages.firstWhere(
                (pkg) =>
                    pkg is Map<String, dynamic> && pkg['name'] == 'zuraffa',
                orElse: () => null,
              )
              as Map<String, dynamic>?;
      if (zuraffa == null) return null;
      var root = zuraffa['rootUri'] as String;
      if (root.startsWith('file://')) root = Uri.parse(root).toFilePath();
      if (!p.isAbsolute(root)) {
        root = p.normalize(p.absolute(p.join(projectRoot, root)));
      }
      final names = <String>{};
      _collectFromBarrel(p.join(root, 'lib', 'zuraffa.dart'), root, names, 0);
      return ZuraffaBarrelExports._(names);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static void _collectFromBarrel(
    String barrelPath,
    String packageRoot,
    Set<String> names,
    int depth,
  ) {
    if (depth > 3) return;
    final barrel = File(barrelPath);
    if (!barrel.existsSync()) return;

    String? quotedTarget(String line) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('export ')) return null;
      final start = trimmed.indexOf("'");
      if (start < 0) return null;
      final end = trimmed.indexOf("'", start + 1);
      if (end < 0) return null;
      return trimmed.substring(start + 1, end);
    }

    String? declaredType(String line) {
      final trimmed = line.trim();
      for (final keyword in ['class ', 'mixin ', 'enum ', 'typedef ']) {
        if (trimmed.startsWith(keyword)) {
          final rest = trimmed
              .substring(keyword.length)
              .replaceAll('<', ' ')
              .replaceAll('>', ' ');
          return rest.trim().split(RegExp(r'\s+')).first;
        }
      }
      return null;
    }

    for (final line in barrel.readAsLinesSync()) {
      final target = quotedTarget(line);
      if (target == null) continue;
      var path = target;
      if (path.startsWith('package:zuraffa/')) {
        path = path.replaceFirst('package:zuraffa/', '');
      } else if (path.startsWith('package:')) {
        continue;
      } else {
        path = p.normalize(p.join('lib', path));
      }
      final file = File(p.join(packageRoot, path));
      if (!file.existsSync()) continue;
      for (final line in file.readAsLinesSync()) {
        final name = declaredType(line);
        if (name != null && name.isNotEmpty) names.add(name);
      }
      // Follow nested barrels one more level.
      if (depth < 2 &&
          file.readAsLinesSync().any((l) => l.trim().startsWith('export '))) {
        _collectFromBarrel(file.path, packageRoot, names, depth + 1);
      }
    }
  }
}
