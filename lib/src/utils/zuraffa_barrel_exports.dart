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
/// Seeded once per generation (`seed`, called from
/// `PluginManager.buildContext`); builders then filter through
/// [filter]. The resolution itself is DEFERRED to the first read.
/// Unresolved (no seed, no resolvable `package_config.json` entry, or a
/// missing barrel file → an empty name set) makes [filter] return an
/// EMPTY list: callers emit no `hide` combinator at all (issue #1530
/// FR-001 removed the legacy keep-all fallback).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ZuraffaBarrelExports {
  ZuraffaBarrelExports._(this.names, this.mockNames);

  /// The names `package:zuraffa/zuraffa.dart` exports (the walk target of
  /// [filter] — the interface writer and every non-mock emission site).
  final Set<String> names;

  /// The names `package:zuraffa/mock.dart` exports (issue #1418): the mock
  /// barrel's own local declaration surface, unioned with [names] exactly
  /// when the mock chain carries a BARE (combinator-free)
  /// `export 'package:zuraffa/zuraffa.dart';` — the walk target of
  /// [filterMock] (the two mock-barrel emission sites).
  final Set<String> mockNames;

  static ZuraffaBarrelExports? _seeded;
  static String? _projectRoot;
  static bool _resolved = false;

  /// Seed from [projectRoot] (the generation target). Safe to call
  /// repeatedly; the resolution happens on first read and is cached
  /// until [reset].
  static void seed(String projectRoot) {
    _projectRoot = projectRoot;
    _seeded = null;
    _resolved = false;
  }

  /// Test seam: seed with an explicit name set. Both surfaces are seeded
  /// identically — a test that pins a surface intends "these names are
  /// verified" for whichever library the emission site imports.
  static void seedForTest(Set<String> names) {
    _seeded = ZuraffaBarrelExports._({...names}, {...names});
    _projectRoot = null;
    _resolved = true;
  }

  static void reset() {
    _seeded = null;
    _projectRoot = null;
    _resolved = false;
  }

  /// The current resolution, or null when the surface is unresolved.
  ///
  /// Issue #1530 (FR-001/FR-005): the resolution is DEFERRED to this
  /// first read rather than run inside [seed]. The seed happens at
  /// generation start (`PluginManager.buildContext`) while the pubspec
  /// ensure that makes a fresh target's `zuraffa` entry resolvable lands
  /// at the END of the same run — resolving late lets any resolution
  /// state produced in between land first. The window is still open for
  /// a run whose only change is that pubspec write (the ensure never
  /// spawns `pub get`, so `package_config.json` — what [_resolve] reads
  /// — is unchanged until the user runs it); that residual is recorded
  /// in the spec's risk table.
  static ZuraffaBarrelExports? get current {
    if (_resolved) return _seeded;
    final root = _projectRoot;
    if (root == null) return null;
    _resolved = true;
    return _seeded = _resolve(root);
  }

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
    final seed = current;
    if (seed == null) return const [];
    return hides.where(seed.names.contains).toList();
  }

  /// Filters [hides] to names `package:zuraffa/mock.dart` actually
  /// exports (issue #1418).
  ///
  /// The mock lane's generated files hide the entity's own symbols from
  /// the MOCK barrel (`import 'package:zuraffa/mock.dart' hide …`), but
  /// [filter] verifies against the `zuraffa.dart` surface — correctness
  /// rested on `src/mock/mock.dart` bare-re-exporting the full zuraffa
  /// surface, an accident of the current barrel layout. [filterMock]
  /// verifies against the mock barrel's own resolved surface: a name the
  /// mock barrel does not export is dropped (an unverified hide is an
  /// `undefined_hidden_name` warning, and `zfa build`'s analyze gate
  /// fails on warnings); the bare re-export union keeps the #942
  /// collision protection; an UNRESOLVED surface returns an EMPTY list —
  /// no combinator at all (#1530 FR-001 carryover).
  static List<String> filterMock(Iterable<String> hides) {
    final seed = current;
    if (seed == null) return const [];
    return hides.where(seed.mockNames.contains).toList();
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
      // Issue #1418: resolve the MOCK barrel's surface too — the mock
      // lane hides from `package:zuraffa/mock.dart`, so the verified set
      // for that import must come from walking `lib/mock.dart`, not from
      // assuming the zuraffa re-export.
      final mockNames = <String>{};
      _collectMockSurface(
        p.join(root, 'lib', 'mock.dart'),
        root,
        names,
        mockNames,
        0,
      );
      return ZuraffaBarrelExports._(names, mockNames);
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

    // Parses `export '<uri>' ...;` STATEMENTS into the quoted target plus
    // the combinator tail (everything after the closing quote).
    //
    // Combinators belong to the STATEMENT, not the line: dart_style
    // wraps long `export`s — this repo's own `lib/zuraffa.dart` uses that
    // form four times — so accumulate to the terminating `;` before
    // reading the tail. A line-scoped parse sees an empty tail for the
    // wrapped form, treats the statement as unrestricted, and collects
    // every top-level declaration of the target file (re-emitting
    // exactly the unverified hides issue #1530 removes). Whitespace is
    // collapsed so a wrapped name list reads as one list.
    Iterable<(String, String)> exportStatements(List<String> lines) =>
        _exportStatements(lines);

    // The names of one combinator (`show a, b` / `hide c`) — null when
    // the keyword is absent (issue #1530 FR-002). The capture stops at a
    // sibling combinator keyword or the statement terminator: `show
    // Alpha hide Beta` is one legal statement, and letting the capture
    // run to the `;` would swallow `hide Beta` into the `show` list, so
    // Alpha — genuinely exported — would stop verifying.
    Set<String>? combinatorNames(String tail, String keyword) =>
        _combinatorNames(tail, keyword);

    String? declaredType(String line) => _declaredType(line);

    for (final (target, tail) in exportStatements(barrel.readAsLinesSync())) {
      // Issue #1530 (FR-002): honor the statement's combinators — a
      // `show`-restricted statement contributes ONLY the shown names and
      // a `hide`-carrying statement subtracts the hidden names. Both
      // filters intersect with the inherited ones from an enclosing
      // barrel statement (`export 'index.dart' show X;` restricts what
      // the nested barrel contributes too).
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

  /// Parses `export '<uri>' …;` STATEMENTS into the quoted target plus
  /// the combinator tail (everything after the closing quote).
  ///
  /// Combinators belong to the STATEMENT, not the line: dart_style wraps
  /// long `export`s — this repo's own `lib/zuraffa.dart` uses that form
  /// four times — so accumulate to the terminating `;` before reading
  /// the tail. A line-scoped parse sees an empty tail for the wrapped
  /// form, treats the statement as unrestricted, and collects every
  /// top-level declaration of the target file (re-emitting exactly the
  /// unverified hides issue #1530 removes). Whitespace is collapsed so a
  /// wrapped name list reads as one list.
  static Iterable<(String, String)> _exportStatements(
    List<String> lines,
  ) sync* {
    final buf = StringBuffer();
    var open = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (!open) {
        if (!trimmed.startsWith('export ')) continue;
        open = true;
        buf.clear();
      }
      buf.write(trimmed.replaceAll(RegExp(r'\s+'), ' '));
      buf.write(' ');
      final text = buf.toString();
      if (!text.contains(';')) continue;
      open = false;
      final start = text.indexOf("'");
      if (start < 0) continue;
      final end = text.indexOf("'", start + 1);
      if (end < 0) continue;
      yield (text.substring(start + 1, end), text.substring(end + 1));
    }
  }

  /// The names of one combinator (`show a, b` / `hide c`) — null when the
  /// keyword is absent (issue #1530 FR-002). The capture stops at a
  /// sibling combinator keyword or the statement terminator: `show Alpha
  /// hide Beta` is one legal statement, and letting the capture run to
  /// the `;` would swallow `hide Beta` into the `show` list, so Alpha —
  /// genuinely exported — would stop verifying.
  static Set<String>? _combinatorNames(String tail, String keyword) {
    final match = RegExp(
      '\\b$keyword\\s+([^;]*?)(?=\\s+(?:show|hide)\\b|\\s*;)',
    ).firstMatch(tail);
    if (match == null) return null;
    return match
        .group(1)!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  static String? _declaredType(String line) {
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

  /// Resolves the surface `package:zuraffa/mock.dart` exports (issue
  /// #1418) into [mockNames], walking the mock barrel's own export chain
  /// from [barrelPath].
  ///
  /// The mock lane hides the entity's own symbols from
  /// `package:zuraffa/mock.dart`; the verified set for THAT import must
  /// come from walking the mock barrel, not from assuming the zuraffa
  /// surface (the old single-walk correctness rested on
  /// `src/mock/mock.dart` bare-re-exporting all of `zuraffa.dart` — an
  /// accident of the current barrel layout). Local declarations along
  /// the relative-export chain are collected with the same
  /// combinator-aware, depth-capped rules the zuraffa walk uses. A
  /// `package:zuraffa/zuraffa.dart` re-export statement contributes from
  /// [zuraffaNames] (already resolved): a BARE statement unions the
  /// whole zuraffa surface (what the current `lib/src/mock/mock.dart`
  /// layout asserts), a combinator-carrying statement contributes only
  /// its shown slice. Other `package:` targets stay skipped — collecting
  /// their surface would over-collect (the walker cannot see their
  /// combinators), and under-collection is the safe direction: it can
  /// only lose #942 protection for an exotic name, never emit an
  /// unverified hide.
  static void _collectMockSurface(
    String barrelPath,
    String packageRoot,
    Set<String> zuraffaNames,
    Set<String> mockNames,
    int depth,
  ) {
    if (depth > 3) return;
    final barrel = File(barrelPath);
    if (!barrel.existsSync()) return;
    final barrelDir = p.dirname(barrelPath);

    for (final (target, tail) in _exportStatements(barrel.readAsLinesSync())) {
      final shown = _combinatorNames(tail, 'show');
      final hidden = _combinatorNames(tail, 'hide') ?? const <String>{};

      if (target == 'package:zuraffa/zuraffa.dart') {
        if (shown == null) {
          // Bare, or hide-only: the zuraffa surface comes through whole,
          // minus anything the statement hides.
          mockNames.addAll(zuraffaNames);
        } else {
          mockNames.addAll(zuraffaNames.where(shown.contains));
        }
        mockNames.removeAll(hidden);
        continue;
      }
      if (target.startsWith('package:')) continue;

      final path = p.normalize(p.join(barrelDir, target));
      final file = File(path);
      if (!file.existsSync()) continue;
      final fileLines = file.readAsLinesSync();
      var hasNestedExports = false;
      for (final fileLine in fileLines) {
        if (fileLine.trim().startsWith('export ')) {
          hasNestedExports = true;
          continue;
        }
        final name = _declaredType(fileLine);
        if (name == null || name.isEmpty) continue;
        if (shown != null && !shown.contains(name)) continue;
        if (hidden.contains(name)) continue;
        mockNames.add(name);
      }
      if (depth < 2 && hasNestedExports) {
        _collectMockSurface(
          file.path,
          packageRoot,
          zuraffaNames,
          mockNames,
          depth + 1,
        );
      }
    }
  }
}
