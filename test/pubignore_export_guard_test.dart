// Publish-time export guard (bug 1307).
//
// Root cause being guarded: `.pubignore` patterns with a trailing slash and
// no leading/middle slash (`benchmark/`) follow gitignore semantics and match
// directories at ANY depth — which excluded `lib/src/core/benchmark/` and
// `lib/src/plugins/benchmark/` from the published tarball while
// `lib/zuraffa.dart` kept exporting `src/core/benchmark/*` (published
// 6.2.0/6.2.1 failed consumer compilation at day zero).
//
// This guard rebuilds the would-publish file set by applying `.pubignore`
// with gitignore semantics, then asserts every `export`/`part` target in the
// published `lib/**` sources is present in that set. It intentionally pins:
//   * B1/AC-1 — the export guard itself,
//   * B2/AC-2 — top-level `benchmark/` still excluded, `lib/src/core/benchmark/`
//     sources included,
//   * B3/AC-3 — no unanchored (any-depth) directory patterns in `.pubignore`.
//
// `dart pub publish --dry-run` remains the authoritative publish gate; this
// test mirrors the ignore semantics for the subset `.pubignore` uses
// (name patterns, root-anchored patterns, `*` globs, `!` negation).
//
// Returns the would-publish file set (relative POSIX paths) for the package
// rooted at [root], applying `<root>/.pubignore` with gitignore semantics.
// `.git` and `.dart_tool` are skipped unconditionally (pub never publishes
// them); every other path is governed solely by the ignore rules.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final String _pkgRoot = Directory.current.path;

/// One parsed `.pubignore` line.
class _IgnoreLine {
  _IgnoreLine(
    this.pattern,
    this.negated,
    this.dirOnly,
    this.anchored,
    this.regexp,
  );

  final String pattern;
  final bool negated;
  final bool dirOnly;
  final bool anchored;
  final RegExp regexp;

  bool matches(String relPath, {required bool isDir}) {
    if (dirOnly && !isDir) return false;
    final subject = anchored ? relPath : _basename(relPath);
    return regexp.hasMatch(subject);
  }
}

String _basename(String relPath) => relPath.split('/').last;

/// Translate a gitignore glob to a full-match RegExp over a relative POSIX
/// path (no leading/trailing slash). Supports `*`, `?` and `**`; `*` never
/// crosses `/` except as part of `**`.
RegExp _globToRegExp(String glob) {
  final sb = StringBuffer();
  var i = 0;
  while (i < glob.length) {
    final c = glob[i];
    if (c == '*') {
      final doubleStar = i + 1 < glob.length && glob[i + 1] == '*';
      sb.write(doubleStar ? '.*' : '[^/]*');
      i += doubleStar ? 2 : 1;
    } else if (c == '?') {
      sb.write('[^/]');
      i += 1;
    } else {
      sb.write(RegExp.escape(c));
      i += 1;
    }
  }
  return RegExp('^(?:$sb)\$');
}

List<_IgnoreLine> _parseIgnore(List<String> lines) {
  final out = <_IgnoreLine>[];
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    var pattern = line;
    var negated = false;
    if (pattern.startsWith('!')) {
      negated = true;
      pattern = pattern.substring(1);
    }
    var dirOnly = false;
    if (pattern.endsWith('/')) {
      dirOnly = true;
      pattern = pattern.substring(0, pattern.length - 1);
    }
    // Anchored iff a slash remains anywhere (leading or middle). A pattern
    // with no remaining slash matches its basename at ANY depth — this is
    // the exact semantics that caused bug 1307.
    final anchored = pattern.startsWith('/') || pattern.contains('/');
    pattern = pattern.startsWith('/') ? pattern.substring(1) : pattern;
    out.add(
      _IgnoreLine(pattern, negated, dirOnly, anchored, _globToRegExp(pattern)),
    );
  }
  return out;
}

/// True when [relPath] (relative POSIX path, no trailing slash) is excluded
/// by [lines]; last matching rule wins (gitignore negation semantics).
bool _isIgnored(
  List<_IgnoreLine> lines,
  String relPath, {
  required bool isDir,
}) {
  var ignored = false;
  for (final line in lines) {
    if (line.matches(relPath, isDir: isDir)) ignored = !line.negated;
  }
  return ignored;
}

Set<String> _wouldPublishSet() {
  final lines = _parseIgnore(
    File(p.join(_pkgRoot, '.pubignore')).readAsLinesSync(),
  );
  final out = <String>{};

  void walk(Directory dir, String relPrefix) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      final rel = relPrefix.isEmpty ? name : '$relPrefix/$name';
      if (entity is Link) continue;
      if (entity is Directory) {
        // pub never publishes these; skip before ignore evaluation.
        if (rel == '.git' || rel == '.dart_tool') continue;
        if (_isIgnored(lines, rel, isDir: true)) continue;
        walk(entity, rel);
      } else if (entity is File) {
        if (_isIgnored(lines, rel, isDir: false)) continue;
        out.add(rel);
      }
    }
  }

  walk(Directory(_pkgRoot), '');
  return out;
}

class _DirectiveTarget {
  _DirectiveTarget(this.sourceFile, this.kind, this.uri, this.resolved);
  final String sourceFile;
  final String kind;
  final String uri;
  final String? resolved;
}

final RegExp _directiveRe = RegExp(
  r'''^\s*(export|part)\s+(['"])([^'"]+)\2''',
  multiLine: true,
);

/// Resolve an export/part URI in [sourceRel] (relative POSIX path under lib/)
/// to a package-relative path, or null when it cannot land in the tarball.
String? _resolveTarget(String sourceRel, String uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    const selfPrefix = 'package:zuraffa/';
    if (!uri.startsWith(selfPrefix)) return null; // external dependency
    return 'lib/${uri.substring(selfPrefix.length)}';
  }
  final dir = p.posix.dirname(sourceRel);
  return p.posix.normalize(p.posix.join(dir, uri));
}

/// Blank out triple-quoted string bodies before directive scanning.
///
/// `export '…'`-shaped TEMPLATE text lives inside `'''` and `"""` literals
/// in lib/ generators — #1604's plugin_scaffold.dart renders its emitted
/// consumer barrel from one, complete with `export 'src/register.dart';`
/// lines, and seven lib/ files fence their templates with triple-double
/// quotes (e.g. api_bridge_builder.dart, graphql_builder.dart). The
/// directive regex must only see real code. WHICH fence is open is tracked,
/// so a `'''` body cannot be closed by a `"""` and vice versa; text inside
/// an open span is dropped, fence tokens themselves are kept.
String _codeOutsideTripleQuotedStrings(String source) {
  const single = "'''";
  const double = '"""';
  var open = ''; // '' → code; otherwise the fence kind that is open.
  final out = <String>[];
  for (final line in const LineSplitter().convert(source)) {
    final kept = StringBuffer();
    var rest = line;
    while (rest.isNotEmpty) {
      if (open.isEmpty) {
        final s = rest.indexOf(single);
        final d = rest.indexOf(double);
        if (s < 0 && d < 0) {
          kept.write(rest);
          break;
        }
        final opensSingle = s >= 0 && (d < 0 || s < d);
        final at = opensSingle ? s : d;
        kept.write(rest.substring(0, at + 3));
        open = opensSingle ? single : double;
        rest = rest.substring(at + 3);
      } else {
        final at = rest.indexOf(open);
        if (at < 0) {
          rest = ''; // still inside: the remainder is body → blanked
          break;
        }
        rest = rest.substring(at + 3); // drop the body, rescan after the close
        open = '';
      }
    }
    out.add(kept.toString());
  }
  return out.join('\n');
}

/// Scan every published `lib/**/*.dart` for export/part directives.
List<_DirectiveTarget> _collectTargets(Set<String> published) {
  final targets = <_DirectiveTarget>[];
  for (final rel in published) {
    if (!rel.startsWith('lib/') || !rel.endsWith('.dart')) continue;
    final text = _codeOutsideTripleQuotedStrings(
      File(p.join(_pkgRoot, rel)).readAsStringSync(),
    );
    for (final m in _directiveRe.allMatches(text)) {
      final uri = m.group(3)!;
      // A real Dart export/part URI is a plain string literal — it cannot
      // contain string interpolation. URIs with `$` are code-generation
      // templates embedded in lib/ (e.g. package_scaffold.dart emits
      // `export 'src/module/${name}_package_module.dart';` into consumer
      // projects); they are not directives of THIS package.
      // Same class: the `@@TOKEN@@` placeholder family — #1604's
      // plugin_scaffold.dart renders its emitted consumer barrel from a
      // template whose `export 'src/@@NOUN@@_exception.dart';` lines are
      // text, not this package's directives.
      if (uri.contains(r'$') || uri.contains('@@')) continue;
      targets.add(
        _DirectiveTarget(rel, m.group(1)!, uri, _resolveTarget(rel, uri)),
      );
    }
  }
  return targets;
}

void main() {
  test('export guard: every export/part directive target under lib/ exists in '
      'the would-publish set', () {
    final published = _wouldPublishSet();
    final missing = <String>[];
    for (final t in _collectTargets(published)) {
      final resolved = t.resolved;
      if (resolved == null) continue; // dart: or external package target
      if (!published.contains(resolved)) {
        missing.add(
          '${t.sourceFile}: ${t.kind} \'${t.uri}\' -> '
          '${resolved.isEmpty ? "<root>" : resolved} '
          '(on disk: ${File(p.join(_pkgRoot, resolved)).existsSync() ? "yes" : "no"})',
        );
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Published lib/ files reference files that .pubignore (or '
          'the tree) removes from the publish set — day-zero compile '
          'breakage for consumers (bug 1307 class):\n'
          '${missing.join('\n')}',
    );
  });

  // Review-finding pin (latent failure mode): the blanking state machine's
  // only possible bug direction is REMOVING input — the guard checks less
  // and stays green. These tests pin that the scan still sees the real
  // directives and that template bodies drop out.
  test('scan sanity: blanking keeps the real directives in view', () {
    final targets = _collectTargets(_wouldPublishSet());
    expect(targets, isNotEmpty);
    expect(
      targets.map((t) => t.resolved),
      contains('lib/src/core/benchmark/benchmark_contract.dart'),
      reason: 'lib/zuraffa.dart:295 exports this file; B2 pins that it ships',
    );
  });

  test('blanking: template bodies drop out, post-fence directives stay', () {
    final src = [
      "const b = r'''",
      "export 'src/ghost.dart';",
      "''';",
      "export 'src/real.dart';",
    ].join('\n');
    final code = _codeOutsideTripleQuotedStrings(src);
    expect(code, isNot(contains('ghost')));
    expect(code, contains("export 'src/real.dart';"));
  });

  test('blanking: triple-double template bodies drop out too', () {
    // Seven lib/ files fence templates with """ (e.g. api_bridge_builder,
    // graphql_builder) — invisible today only because their exports
    // interpolate. A non-interpolated export in one must not re-red the
    // lane the way #1604 did.
    final src = [
      'const t = """',
      "export 'src/ghost.dart';",
      '""";',
      "export 'src/real.dart';",
    ].join('\n');
    final code = _codeOutsideTripleQuotedStrings(src);
    expect(code, isNot(contains('ghost')));
    expect(code, contains("export 'src/real.dart';"));
  });

  test("blanking: a ''' body is not closed by a \"\"\" fence", () {
    final src = [
      "const b = r'''",
      "export 'src/ghost.dart';",
      '"""',
      "export 'src/other_ghost.dart';",
      "''';",
      "export 'src/real.dart';",
    ].join('\n');
    final code = _codeOutsideTripleQuotedStrings(src);
    expect(code, isNot(contains('ghost')));
    expect(code, contains("export 'src/real.dart';"));
  });

  test(
    'would-publish set: includes lib/src/core/benchmark sources and excludes '
    'the top-level benchmark harness',
    () {
      final published = _wouldPublishSet();

      // The 8 files lib/zuraffa.dart:294-301 exports (AC-2, the 1307 breakage).
      const exportedCoreBenchmark = [
        'lib/src/core/benchmark/benchmark_contract.dart',
        'lib/src/core/benchmark/benchmark_result.dart',
        'lib/src/core/benchmark/benchmark_registry.dart',
        'lib/src/core/benchmark/benchmark_runner.dart',
        'lib/src/core/benchmark/metric_collector.dart',
        'lib/src/core/benchmark/baseline_store.dart',
        'lib/src/core/benchmark/standard_metrics.dart',
        'lib/src/core/benchmark/isolate_benchmark_runner.dart',
      ];
      for (final f in exportedCoreBenchmark) {
        expect(
          published,
          contains(f),
          reason:
              '$f is exported by lib/zuraffa.dart and MUST ship in the '
              'published tarball',
        );
      }

      // The dev-only harness stays out of the tarball.
      final harness = published.where(
        (f) => f == 'benchmark' || f.startsWith('benchmark/'),
      );
      expect(
        harness,
        isEmpty,
        reason: 'the top-level benchmark/ dev harness must stay excluded',
      );
      final plugins = published.where(
        (f) => f.startsWith('lib/src/plugins/benchmark/'),
      );
      expect(
        plugins,
        isNotEmpty,
        reason:
            'lib/src/plugins/benchmark/ is library source and must not '
            'be dropped by an any-depth benchmark/ ignore',
      );
    },
  );

  test('.pubignore hygiene: directory patterns are root-anchored '
      '(no any-depth hazards)', () {
    final hazards = <String>[];
    for (final raw in File(p.join(_pkgRoot, '.pubignore')).readAsLinesSync()) {
      var line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('!')) line = line.substring(1).trim();
      if (!line.endsWith('/')) continue; // file pattern: not a dir hazard
      final stripped = line.substring(0, line.length - 1);
      // A trailing-slash pattern with NO slash remaining is unanchored and
      // matches directories at ANY depth (gitignore semantics — bug 1307).
      if (!stripped.contains('/')) hazards.add(raw.trim());
    }
    expect(
      hazards,
      isEmpty,
      reason:
          'unanchored directory patterns in .pubignore exclude '
          'same-named directories at ANY depth (e.g. lib/src/core/benchmark/ '
          'was excluded by `benchmark/`):\n${hazards.join('\n')}',
    );
  });
}
