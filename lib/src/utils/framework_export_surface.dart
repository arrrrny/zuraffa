import 'dart:convert';
import 'dart:io';

/// The zuraffa framework's export surface, resolved lazily and parsed
/// from source (issue #942, remediation 3 — errors-are-an-API).
///
/// `entity create` preflights the entity name against this surface: an
/// entity whose name matches a framework export (e.g. `Credentials`,
/// exported by `package:zuraffa/zuraffa.dart` via
/// `src/core/params/index.dart`) makes every GENERATED datasource/mock
/// file fail to compile with `ambiguous_import` errors — those templates
/// import the entity file AND the framework barrel unprefixed. The
/// preflight refuses the name up front with a `--> fix:` rename
/// suggestion (VISION §4) instead of letting users walk into the trap.
///
/// Resolution order (fail-open — a null result means "surface unknown",
/// and the preflight is skipped silently; the #942 hide clauses in the
/// generated templates remain the compile-time safety net):
///
///   1. `<projectRoot>/.dart_tool/package_config.json` — the `zuraffa`
///      package the TARGET project resolves against (its version is the
///      one that matters for the generated code's imports);
///   2. the CLI's own package root, found by walking up from
///      [Platform.script] (works for source runs and for the AOT test
///      binary, which lives inside the zuraffa checkout);
///   3. unresolvable → null.
///
/// The surface is the transitive export graph of the framework barrels
/// (`zuraffa.dart`, `mock.dart`), with `show`/`hide` combinators
/// applied, collecting the top-level class/enum/mixin/extension/typedef
/// names of every exported library (its part files included).
class FrameworkExportSurface {
  FrameworkExportSurface._(this._sources);

  /// Symbol → declaring file (relative to the package root), for the
  /// refusal message. Only symbols that are actually part of the
  /// composed export surface appear here — a symbol that every barrel
  /// path to its declaring file hides (`export 'a.dart' show Foo;` when
  /// the barrel needs `Bar`) is not on the surface and [lookup] reports
  /// null for it.
  final Map<String, String> _sources;

  static final Map<String, FrameworkExportSurface?> _cache = {};

  /// The framework barrels the surface is built from.
  static const List<String> _barrels = <String>['zuraffa.dart', 'mock.dart'];

  /// Resolves the export surface for the project at [projectRoot], or
  /// null when it cannot be determined (fail-open). Cached per lib root.
  static FrameworkExportSurface? tryResolve({String? projectRoot}) {
    final libRoot = _resolveLibRoot(projectRoot: projectRoot);
    if (libRoot == null) return null;
    if (_cache.containsKey(libRoot)) return _cache[libRoot];
    final surface = _parseSurface(libRoot);
    _cache[libRoot] = surface;
    return surface;
  }

  /// The framework file exporting [name], relative to the package root,
  /// or null when the surface does not export it (or is unknown).
  String? lookup(String name) => _sources[name];

  // -------------------------------------------------------------------
  // Resolution
  // -------------------------------------------------------------------

  static String? _resolveLibRoot({String? projectRoot}) {
    // 1. The target project's own package_config (authoritative for the
    //    zuraffa version the generated code will import).
    if (projectRoot != null) {
      final libRoot = _libRootFromPackageConfig(
        _join([projectRoot, '.dart_tool', 'package_config.json']),
      );
      if (libRoot != null) return libRoot;
    }
    // 2. The CLI's own package root (the CLI ships with the framework).
    return _libRootFromScriptPath();
  }

  /// Path join — this utility is intentionally dependency-free
  /// (dart:io + dart:convert only).
  static String _join(List<String> parts) {
    var joined = parts.first;
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      joined = joined.endsWith('/') ? '$joined$part' : '$joined/$part';
    }
    return joined;
  }

  static String? _libRootFromPackageConfig(String configPath) {
    final configFile = File(configPath);
    if (!configFile.existsSync()) return null;
    try {
      final config =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = (config['packages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();
      for (final pkg in packages) {
        if (pkg['name'] != 'zuraffa') continue;
        final rootUri = pkg['rootUri'] as String?;
        if (rootUri == null) return null;
        Uri uri;
        try {
          uri = Uri.parse(rootUri);
        } on FormatException {
          return null;
        }
        var rootPath = uri.scheme == 'file'
            ? uri.toFilePath()
            : // Relative rootUri entries resolve against the config
              // file's own directory (`<project>/.dart_tool/`) per the
              // package_config v2 spec — a root package's `"rootUri":
              // "../"` therefore lands on the project root, not one
              // level above it.
              _join([configFile.parent.path, rootUri]);
        if (rootPath.endsWith('/')) {
          rootPath = rootPath.substring(0, rootPath.length - 1);
        }
        final libRoot = _join([rootPath, 'lib']);
        if (Directory(libRoot).existsSync()) return libRoot;
        return null;
      }
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
    return null;
  }

  static String? _libRootFromScriptPath() {
    String? scriptPath;
    try {
      scriptPath = Platform.script.toFilePath();
    } on UnsupportedError {
      return null;
    } on FileSystemException {
      return null;
    }
    if (scriptPath.isEmpty) return null;
    var dir = File(scriptPath).parent.path;
    for (var i = 0; i < 12; i++) {
      final pubspec = File(_join([dir, 'pubspec.yaml']));
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        // Only the zuraffa package itself carries the framework surface.
        // A trailing `# comment` is allowed (YAML).
        final nameMatch = RegExp(
          r'^name:\s*zuraffa\s*(?:#.*)?$',
          multiLine: true,
        ).firstMatch(content);
        if (nameMatch != null && Directory(_join([dir, 'lib'])).existsSync()) {
          return _join([dir, 'lib']);
        }
      }
      final parent = File(dir).parent.path;
      if (parent == dir) return null;
      dir = parent;
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Parsing
  // -------------------------------------------------------------------

  static FrameworkExportSurface? _parseSurface(String libRoot) {
    final sources = <String, String>{};
    final visited = <String>{};

    // Per-file top-level symbol sets, parsed once each.
    final fileSymbols = <String, Set<String>>{};

    // Displays a file path as its package URI form for refusal messages
    // (e.g. package:zuraffa/src/core/params/credentials.dart).
    String display(String path) {
      const libMarker = '/lib/';
      final idx = path.indexOf(libMarker);
      if (idx < 0) return path;
      return 'package:zuraffa${path.substring(idx + libMarker.length - 1)}';
    }

    /// The effective symbol set [fileUri] exports to its importer: the
    /// library's own top-level declarations (part files included) plus
    /// every transitive re-export, with each hop's `show`/`hide`
    /// combinators applied. Combinators are per-hop: `export 'a.dart'
    /// show Foo;` exposes only `Foo` from `a.dart` — `a.dart`'s other
    /// declarations stay off the surface even though `a.dart` itself
    /// declares them.
    Set<String> visit(String fileUri) {
      // Cycle safety: a file already visited (or re-entered mid-visit
      // through an export cycle) contributes nothing new on this path.
      // An export cycle loses the second hop's contribution rather than
      // looping — acceptable for a collision preflight, which only ever
      // over-reports danger, never under-reports a first-hop collision.
      if (visited.contains(fileUri)) return const <String>{};
      visited.add(fileUri);
      final file = File(fileUri);
      if (!file.existsSync()) return const <String>{};
      final content = _stripComments(file.readAsStringSync());

      final effective = <String>{};

      // Symbols declared in this file, plus its part files (parts merge
      // into the library).
      final own = fileSymbols.putIfAbsent(
        fileUri,
        () => _collectSymbols(content),
      );
      effective.addAll(own);
      for (final symbol in own) {
        sources.putIfAbsent(symbol, () => display(fileUri));
      }
      for (final part in _partUris(content)) {
        final resolved = _resolveUri(part, fileUri);
        // Skip template-literal "part"/"export" statements (e.g. a code
        // generator embedding `export '$exportPath'` in a string) — the
        // URI does not resolve to a real file.
        if (resolved.isEmpty || !File(resolved).existsSync()) continue;
        final partContent = _stripComments(File(resolved).readAsStringSync());
        final partSymbols = fileSymbols.putIfAbsent(
          resolved,
          () => _collectSymbols(partContent),
        );
        effective.addAll(partSymbols);
        for (final symbol in partSymbols) {
          sources.putIfAbsent(symbol, () => display(resolved));
        }
      }

      // Transitive re-exports: visit first so declaring files win source
      // attribution, then narrow by THIS hop's combinators.
      for (final export in _exportsOf(content)) {
        final resolved = _resolveUri(export.uri, fileUri);
        if (resolved.isEmpty || !File(resolved).existsSync()) continue;
        var exported = visit(resolved);
        final showList = export.show;
        final hideList = export.hide;
        if (showList != null) {
          exported = exported.intersection(showList.toSet());
        }
        if (hideList != null) {
          exported = exported.difference(hideList.toSet());
        }
        effective.addAll(exported);
        for (final symbol in exported) {
          sources.putIfAbsent(symbol, () => display(resolved));
        }
      }
      return effective;
    }

    final symbols = <String>{};
    for (final barrel in _barrels) {
      symbols.addAll(visit(_join([libRoot, barrel])));
    }
    // Sources must describe the COMPOSED surface: drop symbols that are
    // declared (or re-exported) somewhere in the graph but hidden on
    // every barrel path — `lookup()` on them must stay null.
    sources.removeWhere((name, _) => !symbols.contains(name));
    if (symbols.isEmpty) return null;
    return FrameworkExportSurface._(sources);
  }

  static String _resolveUri(String uri, String fromFile) {
    if (uri.startsWith('dart:')) return '';
    if (uri.startsWith('package:')) return '';
    final dir = File(fromFile).parent.path;
    return _join([dir, uri]);
  }

  static Iterable<_ExportDirective> _exportsOf(String content) sync* {
    final pattern = RegExp(
      r'''export\s+['"]([^'"]+)['"]\s*'''
      r'''(?:(?:show\s+([^;]+?))?\s*(?:hide\s+([^;]+?))?)\s*;''',
    );
    for (final match in pattern.allMatches(content)) {
      List<String>? parseNames(String? raw) {
        if (raw == null) return null;
        final names = raw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        return names;
      }

      yield _ExportDirective(
        uri: match.group(1)!,
        show: parseNames(match.group(2)),
        hide: parseNames(match.group(3)),
      );
    }
  }

  static Iterable<String> _partUris(String content) sync* {
    final pattern = RegExp(
      r'''^\s*part\s+['"]([^'"]+)['"]\s*;''',
      multiLine: true,
    );
    for (final match in pattern.allMatches(content)) {
      yield match.group(1)!;
    }
  }

  static Set<String> _collectSymbols(String content) {
    final symbols = <String>{};
    final classLike = RegExp(
      r'^\s*(?:(?:abstract|final|sealed|base|interface|mixin)\s+)*'
      r'(?:class|enum|mixin)\s+([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    // `extension Foo on X` and `extension type Foo(...)` alike — the
    // `type` introducer must not be captured as the name.
    final extension = RegExp(
      r'^\s*extension\s+(?:type\s+)?([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    final typedef = RegExp(
      r'^\s*typedef\s+([A-Za-z_$][A-Za-z0-9_$]*)',
      multiLine: true,
    );
    void collect(RegExp pattern) {
      for (final match in pattern.allMatches(content)) {
        final name = match.group(1)!;
        // Private declarations are not part of the public export
        // surface (Dart forbids exporting them anyway).
        if (name.startsWith('_')) continue;
        symbols.add(name);
      }
    }

    collect(classLike);
    collect(extension);
    collect(typedef);
    return symbols;
  }

  /// Strips `//` line comments and `/* */` block comments so string
  /// literals in comments cannot fake declarations. String literals
  /// themselves are left intact (the framework source declares no
  /// `class ...` prose in literals).
  static String _stripComments(String source) {
    var noBlocks = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    return noBlocks
        .split('\n')
        .map((line) {
          final idx = line.indexOf('//');
          return idx < 0 ? line : line.substring(0, idx);
        })
        .join('\n');
  }
}

class _ExportDirective {
  const _ExportDirective({required this.uri, this.show, this.hide});

  final String uri;
  final List<String>? show;
  final List<String>? hide;
}
