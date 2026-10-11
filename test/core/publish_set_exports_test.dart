/// Publish-set guard (issues #1307, #1325): every file the export/part
/// graph of `lib/zuraffa.dart` reaches must exist in the tree AND
/// survive the `.pubignore` rules — i.e. it must be in the set
/// `dart pub publish` would upload.
///
/// Bug #1307: the `.pubignore` line `benchmark/` used gitignore's
/// any-depth directory semantics, so it silently excluded
/// `lib/src/core/benchmark/` from the published tarball while
/// `lib/zuraffa.dart` kept exporting `src/core/benchmark/
/// benchmark_contract.dart` — every consumer failed to compile at day
/// zero. This test pins the invariant locally (fast tier, no network,
/// no publish): if an export target is ever ignored again, the suite
/// goes red BEFORE the package ships.
///
/// The matcher implements the gitignore subset this repo's `.pubignore`
/// uses: comments, blank lines, trailing `/` (directory-only), leading
/// `/` (root-anchored), and `*` (within one path segment). It does NOT
/// implement `**`, character classes, or `!` negation — extend it if
/// `.pubignore` ever grows those.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _IgnoreRule {
  _IgnoreRule(this.regex, this.dirOnly, this.anchored);

  final RegExp regex;
  final bool dirOnly;
  final bool anchored;
}

_IgnoreRule? _parseRule(String rawLine) {
  final line = rawLine.trim();
  if (line.isEmpty || line.startsWith('#')) return null;
  if (line.startsWith('!')) {
    throw StateError(
      '.pubignore negation (`$line`) is not supported by the '
      'publish-set guard — extend the matcher before relying on it',
    );
  }
  var pattern = line;
  var dirOnly = false;
  if (pattern.endsWith('/')) {
    dirOnly = true;
    pattern = pattern.substring(0, pattern.length - 1);
  }
  var anchored = false;
  if (pattern.startsWith('/')) {
    anchored = true;
    pattern = pattern.substring(1);
  }
  final source = pattern.splitMapJoin(
    '',
    onNonMatch: (ch) => ch == '*' ? '[^/]*' : RegExp.escape(ch),
  );
  // Unanchored rules match at ANY depth (gitignore: a pattern without a
  // leading slash matches a path suffix on segment boundaries) — the
  // exact semantics that made the #1307 `benchmark/` line swallow
  // `lib/src/core/benchmark/`. Anchored rules match from the root only.
  return _IgnoreRule(
    RegExp(anchored ? '^$source\$' : '^(?:.*/)?$source\$'),
    dirOnly,
    anchored,
  );
}

/// Whether [relPath] (project-relative POSIX) is excluded from the
/// published archive by [rules].
bool _isIgnored(String relPath, List<_IgnoreRule> rules) {
  final segments = p.posix.split(relPath);
  // Candidate paths: every ancestor directory prefix, then the file
  // itself — a rule matches when it matches any candidate, per
  // gitignore's directory semantics.
  final candidates = <String>[];
  for (var i = 1; i < segments.length; i++) {
    candidates.add(p.posix.joinAll(segments.sublist(0, i)));
  }
  candidates.add(relPath);
  for (final rule in rules) {
    for (final candidate in candidates) {
      final isDirectoryPrefix = candidate != relPath;
      if (rule.dirOnly && !isDirectoryPrefix) continue;
      if (rule.regex.hasMatch(candidate)) return true;
    }
  }
  return false;
}

/// Transitive export/part targets of [entrypoint], project-relative.
Set<String> _exportGraph(String entrypoint) {
  final visited = <String>{};
  final queue = <String>[entrypoint];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    if (!visited.add(current)) continue;
    final file = File(current);
    if (!file.existsSync()) continue; // existence asserted by the caller
    final dir = p.posix.dirname(current);
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final uri = match.group(3)!;
      // package:/dart: URIs are dependency imports, not publish-set files.
      if (uri.contains(':')) continue;
      final target = _normalize(p.posix.join(dir, uri));
      queue.add(target);
    }
  }
  return visited;
}

final _directive = RegExp(
  "^\\s*(export|part)\\s+(['\"])([^'\"]+)\\2\\s*;",
  multiLine: true,
);

String _normalize(String path) => p.posix.normalize(path).replaceAll('\\', '/');

void main() {
  final rules = <_IgnoreRule>[];
  final pubignore = File('.pubignore');
  test('.pubignore exists (the publish-set contract it pins)', () {
    expect(pubignore.existsSync(), isTrue);
  });

  setUpAll(() {
    rules
      ..clear()
      ..addAll(
        pubignore.readAsLinesSync().map(_parseRule).whereType<_IgnoreRule>(),
      );
  });

  test('#1307 regression: benchmark contract is in the publish set', () {
    const contract = 'lib/src/core/benchmark/benchmark_contract.dart';
    expect(
      File(contract).existsSync(),
      isTrue,
      reason: '$contract must exist in the tree',
    );
    expect(
      _isIgnored(contract, rules),
      isFalse,
      reason: '$contract is exported by lib/zuraffa.dart and must ship',
    );
  });

  test('matcher pins the #1307 semantics: `benchmark/` matches at any '
      'depth, `/benchmark/` only at the root', () {
    final buggy = [_parseRule('benchmark/')!];
    final fixed = [_parseRule('/benchmark/')!];
    const deep = 'lib/src/core/benchmark/benchmark_contract.dart';
    expect(
      _isIgnored(deep, buggy),
      isTrue,
      reason: 'the exact #1307 swallow: unanchored dir rule',
    );
    expect(
      _isIgnored(deep, fixed),
      isFalse,
      reason: 'root-anchored rule must leave lib/ alone',
    );
    expect(
      _isIgnored('benchmark/runner.dart', fixed),
      isTrue,
      reason: 'the root benchmark/ dir itself still ships ignored',
    );
  });

  test('every transitive export/part target of lib/zuraffa.dart '
      'survives .pubignore', () {
    const entrypoint = 'lib/zuraffa.dart';
    final graph = _exportGraph(entrypoint);
    expect(graph.contains(entrypoint), isTrue);
    expect(
      graph.length,
      greaterThan(10),
      reason: 'the export graph should be non-trivial',
    );

    final excluded = <String>[];
    final missing = <String>[];
    for (final path in graph) {
      if (!File(path).existsSync()) {
        missing.add(path);
        continue;
      }
      if (path != entrypoint && _isIgnored(path, rules)) {
        excluded.add(path);
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'export targets missing from the tree: $missing',
    );
    expect(
      excluded,
      isEmpty,
      reason:
          'export targets .pubignore would strip from the published '
          'package — the #1307 day-zero breakage class: $excluded',
    );
  });
}
