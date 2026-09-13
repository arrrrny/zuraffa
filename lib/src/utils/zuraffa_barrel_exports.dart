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

  /// Filters [hides] to names the barrel actually exports.
  ///
  /// Issue #1530 (FR-001): an UNRESOLVED surface returns an EMPTY list —
  /// the import is emitted with no `hide` combinator at all. The legacy
  /// keep-all fallback emitted unverified names (`hide Task, TaskPatch`
  /// for an entity the barrel never exports), every one an
  /// `undefined_hidden_name` warning, and `zfa build`'s analyze gate
  /// fails on warnings — the generator's own output failed its own
  /// gate. Dropping the combinator when nothing can be verified is the
  /// honest emission; the #942 collision protection stays on the SEEDED
  /// path, where names are verified against the real surface.
  static List<String> filter(Iterable<String> hides) {
    final seed = _seeded;
    if (seed == null) return const [];
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
    int depth, {
    Set<String>? inheritedShow,
    Set<String> inheritedHide = const {},
  }) {
    if (depth > 3) return;
    final barrel = File(barrelPath);
    if (!barrel.existsSync()) return;
    // Issue #1530 (FR-003): directory-relative export targets resolve
    // against the EXPORTING barrel's own directory — for the top-level
    // `lib/zuraffa.dart` this is lib-root (identical to the legacy
    // lib-rooted join), and for nested barrels
    // (`src/core/params/index.dart` exporting `'query_params.dart'`)
    // the legacy join silently dropped the name one level down.
    final barrelDir = p.dirname(barrelPath);

    // Parses `export '<uri>' ...;` into the quoted target plus the
    // combinator tail (everything after the closing quote).
    (String, String)? exportParts(String line) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('export ')) return null;
      final start = trimmed.indexOf("'");
      if (start < 0) return null;
      final end = trimmed.indexOf("'", start + 1);
      if (end < 0) return null;
      return (trimmed.substring(start + 1, end), trimmed.substring(end + 1));
    }

    // The names of one combinator (`show a, b` / `hide c`) — null when
    // the keyword is absent (issue #1530 FR-002).
    Set<String>? combinatorNames(String tail, String keyword) {
      final match = RegExp('\\b$keyword\\s+([^;]+);?').firstMatch(tail);
      if (match == null) return null;
      return match
          .group(1)!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
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
      final parts = exportParts(line);
      if (parts == null) continue;
      final (target, tail) = parts;
      // Issue #1530 (FR-002): honor the line's combinators — a
      // `show`-restricted line contributes ONLY the shown names and a
      // `hide`-carrying line subtracts the hidden names. Both filters
      // intersect with the inherited ones from an enclosing barrel line
      // (`export 'index.dart' show X;` restricts what the nested barrel
      // contributes too).
      final shown = combinatorNames(tail, 'show');
      final hidden = combinatorNames(tail, 'hide') ?? const <String>{};
      final effectiveShow = inheritedShow == null
          ? shown
          : (shown == null ? inheritedShow : inheritedShow.intersection(shown));
      final effectiveHide = {...inheritedHide, ...hidden};

      var path = target;
      if (path.startsWith('package:zuraffa/')) {
        path = p.normalize(
          p.join('lib', path.replaceFirst('package:zuraffa/', '')),
        );
        path = p.join(packageRoot, path);
      } else if (path.startsWith('package:')) {
        // External re-exports stay skipped: collecting THEIR surface
        // would over-collect (the walker cannot see their combinators),
        // and under-collection is the safe direction — it can only
        // lose #942 protection for an exotic name, never emit an
        // unverified hide.
        continue;
      } else {
        path = p.normalize(p.join(barrelDir, path));
      }
      final file = File(path);
      if (!file.existsSync()) continue;
      final fileLines = file.readAsLinesSync();
      var hasNestedExports = false;
      for (final fileLine in fileLines) {
        if (fileLine.trim().startsWith('export ')) {
          hasNestedExports = true;
          continue;
        }
        final name = declaredType(fileLine);
        if (name == null || name.isEmpty) continue;
        if (effectiveShow != null && !effectiveShow.contains(name)) continue;
        if (effectiveHide.contains(name)) continue;
        names.add(name);
      }
      // Follow nested barrels one more level, threading the effective
      // combinators down (issue #1530 FR-002).
      if (depth < 2 && hasNestedExports) {
        _collectFromBarrel(
          file.path,
          packageRoot,
          names,
          depth + 1,
          inheritedShow: effectiveShow,
          inheritedHide: effectiveHide,
        );
      }
    }
  }
}
