// RouteVerifyCommand — `zfa route verify`.
//
// Reads the route table from disk (CLI side: `*_routes.dart` / `*_shell.dart`,
// DDA side: generated `zfa_router.g.dart` if present), runs drift detection,
// and emits an honest verdict in text, plain, or JSON form.
//
// Bug: route-dual-system-unreconciled. The CLI Route Plugin and the DDA
// Route Plugin generate routes independently; this command is the
// observability seam between them.
//
// Bug 1060: verify used to be a permanent no-op PASS — when one or both
// route systems were missing it printed "no drift" and exited 0. The
// verdict set is now honest and pinned to exit codes:
//
//   verdict             exit code    meaning
//   ------------------  -----------  --------------------------------------
//   match                0           both systems present, path sets agree
//   drift                1           overlap findings and/or one-sided paths
//   insufficient-input   2           a system has no routes at all; with
//                                    --strict it fails the run (exit 1)

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../plugins/route/route_drift_detector.dart';
import '../plugins/route/route_table.dart';

/// The honest verdict of a `zfa route verify` run. Never collapse a
/// missing-input run into a PASS.
enum RouteVerifyVerdict {
  /// Both systems contributed routes and no drift was found.
  match,

  /// Overlap drift and/or one-sided paths were found.
  drift,

  /// At least one route system contributed no entries, so the two systems
  /// could not be reconciled.
  insufficientInput;

  /// The stable machine-readable name used in text and `--json` output.
  String get label => switch (this) {
    RouteVerifyVerdict.match => 'match',
    RouteVerifyVerdict.drift => 'drift',
    RouteVerifyVerdict.insufficientInput => 'insufficient-input',
  };

  /// The exit code this verdict exits with when `--strict` is [strict].
  int exitCode({required bool strict}) => switch (this) {
    RouteVerifyVerdict.match => 0,
    RouteVerifyVerdict.drift => 1,
    // Without --strict, insufficient-input exits 2 so it is distinguishable
    // from drift; with --strict it fails the run with the uniform error code.
    RouteVerifyVerdict.insufficientInput => strict ? 1 : 2,
  };
}

/// The verdict plus every finding that backs it. Pure data — the command
/// renders it to text, plain, or JSON.
class RouteVerifyResult {
  const RouteVerifyResult({
    required this.verdict,
    required this.overlaps,
    required this.oneSided,
    this.missingInput,
  });

  final RouteVerifyVerdict verdict;

  /// Paths declared by BOTH systems (from [RouteDriftDetector]).
  final List<RouteDrift> overlaps;

  /// Paths declared by exactly one system while both systems are populated.
  /// Drift-class findings: the other system drifted from the declaring one.
  final List<RouteDrift> oneSided;

  /// Human-readable description of which route input is missing. Set only
  /// for [RouteVerifyVerdict.insufficientInput].
  final String? missingInput;

  Map<String, Object?> toJson() => {
    'verdict': verdict.label,
    'drift': overlaps
        .map(
          (d) => {
            'path': d.path,
            'sources': canonicalRouteEntries(
              d.sources,
            ).map((s) => s.toJson()).toList(),
          },
        )
        .toList(),
    'oneSided': oneSided
        .map(
          (d) => {
            'path': d.path,
            'sources': canonicalRouteEntries(
              d.sources,
            ).map((s) => s.toJson()).toList(),
          },
        )
        .toList(),
    if (missingInput != null) 'missingInput': missingInput,
  };
}

class RouteVerifyCommand extends Command<void> {
  RouteVerifyCommand({String? projectRoot})
    : _projectRoot = projectRoot ?? Directory.current.path {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Emit a route-table.json artifact on stdout.',
    );
    argParser.addFlag(
      'plain',
      negatable: false,
      help: 'Strip emoji and color from output (CI-friendly).',
    );
    argParser.addFlag(
      'strict',
      negatable: false,
      help:
          'Fail hard on any non-match verdict: drift exits 1, and '
          'insufficient-input also exits 1 (without --strict it exits 2).',
    );
    argParser.addOption(
      'out',
      help: 'Write JSON to this path instead of stdout.',
    );
  }

  final _detector = const RouteDriftDetector();
  final String _projectRoot;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Compare CLI-generated and DDA-annotated routes; report drift. '
      'Verdicts and exit codes: match → exit 0 (both systems present, path '
      'sets agree); drift → exit 1 (overlapping or one-sided paths, each '
      'named); insufficient-input → exit 2 (a system has no routes at all; '
      'with --strict it exits 1). Insufficient-input is never a silent PASS.';

  @override
  Future<void> run() async {
    final json = argResults?['json'] == true;
    final plain = argResults?['plain'] == true;
    final strict = argResults?['strict'] == true;
    final outPath = argResults?['out'] as String?;

    final table = _readRouteTable();
    final result = _assess(table);

    if (json) {
      final payload = {
        'version': table.version,
        ...result.toJson(),
        'routes': canonicalRouteEntries(
          table.routes,
        ).map((e) => e.toJson()).toList(),
      };
      final encoded = jsonEncode(payload);
      if (outPath != null) {
        await File(outPath).writeAsString('$encoded\n');
        stdout.writeln('Wrote $outPath');
      } else {
        stdout.writeln(encoded);
      }
    } else {
      final buf = StringBuffer();
      buf.writeln('verdict: ${result.verdict.label}');
      buf.writeln('routes: ${table.routes.length}');
      buf.writeln('drift: ${result.overlaps.length}');
      if (result.missingInput != null) {
        buf.writeln('missing-input: ${result.missingInput}');
      }
      buf.write(
        _renderFindings(
          result.overlaps,
          oneSided: result.oneSided,
          driftPrefix: plain ? 'DRIFT' : '⚠️  DRIFT',
          sourceIndent: plain ? '  ' : '    ',
        ),
      );
      stdout.write(buf.toString());
    }

    exitCode = result.verdict.exitCode(strict: strict);
  }

  /// Pure: computes the honest verdict from the walked route table. The
  /// [RouteDriftDetector] stays untouched — overlap findings come from it;
  /// one-sided findings are computed here from the same table.
  ///
  /// Verdict semantics (bug 1060):
  /// - a system with no entries at all → insufficient-input (never a PASS);
  /// - both systems populated and the path sets AGREE → match. The
  ///   detector's overlap findings are reconciled agreements in this state
  ///   (both systems declare the same paths), not conflicts;
  /// - both systems populated and the path sets DISAGREE → drift: the
  ///   detector's overlap findings plus every one-sided path, each named.
  RouteVerifyResult _assess(RouteTable table) {
    final cli = table.routes
        .where((entry) => entry.source == RouteSource.cli)
        .toList();
    final dda = table.routes
        .where((entry) => entry.source == RouteSource.dda)
        .toList();

    if (cli.isEmpty || dda.isEmpty) {
      final missing = <String>[
        if (cli.isEmpty) 'CLI routes (*_routes.dart / *_shell.dart)',
        if (dda.isEmpty) 'DDA router (zfa_router.g.dart)',
      ];
      return RouteVerifyResult(
        verdict: RouteVerifyVerdict.insufficientInput,
        overlaps: const [],
        oneSided: const [],
        missingInput:
            'no entries found for ${missing.join(' and ')} under lib/ — '
            'the systems cannot be reconciled',
      );
    }

    final cliPaths = cli.map((e) => e.path).toSet();
    final ddaPaths = dda.map((e) => e.path).toSet();

    if (cliPaths.length == ddaPaths.length && cliPaths.containsAll(ddaPaths)) {
      // Full agreement: every path declared by one system is declared by
      // the other. Nothing to reconcile — that is what match means.
      return RouteVerifyResult(
        verdict: RouteVerifyVerdict.match,
        overlaps: const [],
        oneSided: const [],
      );
    }

    final overlaps = _detector.detect(table);
    final oneSided = _oneSidedFindings(cli, dda);
    return RouteVerifyResult(
      verdict: RouteVerifyVerdict.drift,
      overlaps: overlaps,
      oneSided: oneSided,
    );
  }

  /// Pure: paths declared by exactly one system while BOTH systems are
  /// populated. Each finding names the offending path and every declaring
  /// entry, in canonical order.
  List<RouteDrift> _oneSidedFindings(
    List<RouteEntry> cli,
    List<RouteEntry> dda,
  ) {
    final cliPaths = cli.map((e) => e.path).toSet();
    final ddaPaths = dda.map((e) => e.path).toSet();
    final orphaned = <RouteEntry>[
      ...cli.where((e) => !ddaPaths.contains(e.path)),
      ...dda.where((e) => !cliPaths.contains(e.path)),
    ];
    final byPath = <String, List<RouteEntry>>{};
    for (final entry in orphaned) {
      byPath.putIfAbsent(entry.path, () => []).add(entry);
    }
    final findings = [
      for (final entry in byPath.entries)
        RouteDrift(
          path: entry.key,
          sources: canonicalRouteEntries(entry.value),
        ),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return findings;
  }

  /// Render overlap + one-sided findings to a string. [driftPrefix] is
  /// prepended to each drift path; [sourceIndent] precedes each source line.
  /// The plain path uses `DRIFT` (no emoji) + 2-space indent; the
  /// default path uses `⚠️  DRIFT` + 4-space indent. One-sided findings are
  /// drift-class: the same prefix with an explicit `(one-sided)` marker.
  String _renderFindings(
    List<RouteDrift> overlaps, {
    List<RouteDrift> oneSided = const [],
    String driftPrefix = '⚠️  DRIFT',
    String sourceIndent = '    ',
  }) {
    final buf = StringBuffer();
    for (final d in overlaps) {
      buf.writeln('$driftPrefix ${d.path}');
      for (final s in d.sources) {
        buf.writeln(
          '$sourceIndent${s.source.name}: ${s.file}:${s.line} (${s.name})',
        );
      }
    }
    for (final d in oneSided) {
      buf.writeln('$driftPrefix (one-sided) ${d.path}');
      for (final s in d.sources) {
        buf.writeln(
          '$sourceIndent${s.source.name}: ${s.file}:${s.line} (${s.name})',
        );
      }
    }
    return buf.toString();
  }

  /// Reads CLI `*_routes.dart` / `*_shell.dart` modules and the DDA
  /// `zfa_router.g.dart`.
  RouteTable _readRouteTable() {
    final libDirectory = Directory(p.join(_projectRoot, 'lib'));
    if (!libDirectory.existsSync()) {
      return const RouteTable(version: 1, routes: []);
    }

    final files =
        libDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => p.extension(file.path) == '.dart')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final cli = <RouteEntry>[];
    final dda = <RouteEntry>[];
    for (final file in files) {
      final fileName = p.basename(file.path);
      if (fileName == 'zfa_router.g.dart') {
        dda.addAll(_parseRoutes(file, RouteSource.dda));
      } else if ((fileName.endsWith('_routes.dart') ||
              fileName.endsWith('_shell.dart')) &&
          fileName != 'app_routes.dart') {
        cli.addAll(_parseRoutes(file, RouteSource.cli));
      }
    }
    return RouteTable.fromSources(cli: cli, dda: dda);
  }

  List<RouteEntry> _parseRoutes(File file, RouteSource routeSource) {
    final source = file.readAsStringSync();
    final constants = _routeConstants(source);
    final entries = <RouteEntry>[];
    final goRoutePattern = RegExp(r'\bGoRoute\s*\(');

    for (final match in goRoutePattern.allMatches(source)) {
      final openParen = source.indexOf('(', match.start);
      final closeParen = _matchingParen(source, openParen);
      if (closeParen == null) continue;
      final invocation = source.substring(openParen + 1, closeParen);
      final pathExpression = _namedArgument(invocation, 'path');
      final nameExpression = _namedArgument(invocation, 'name');
      final routePath = _resolveValue(pathExpression, constants);
      final routeName = _resolveValue(nameExpression, constants);
      if (routePath == null || routeName == null) continue;

      entries.add(
        RouteEntry(
          path: routePath,
          name: routeName,
          source: routeSource,
          file: p.relative(file.path, from: _projectRoot),
          line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
        ),
      );
    }
    return entries;
  }

  Map<String, String> _routeConstants(String source) {
    final constants = <String, String>{};
    final pattern = RegExp(
      r'''static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*((?:r)?'(?:\\.|[^'\\])*'|(?:r)?"(?:\\.|[^"\\])*")\s*;''',
    );
    for (final match in pattern.allMatches(source)) {
      final value = _stringLiteralValue(match.group(2)!);
      if (value != null) constants[match.group(1)!] = value;
    }
    return constants;
  }

  String? _namedArgument(String invocation, String name) {
    final pattern = RegExp(
      '\\b$name\\s*:\\s*'
      r'''((?:r)?'(?:\\.|[^'\\])*'|(?:r)?"(?:\\.|[^"\\])*"|[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)''',
    );
    return pattern.firstMatch(invocation)?.group(1);
  }

  String? _resolveValue(String? expression, Map<String, String> constants) {
    if (expression == null) return null;
    return _stringLiteralValue(expression) ??
        constants[expression.split('.').last];
  }

  String? _stringLiteralValue(String expression) {
    var literal = expression;
    final raw = literal.startsWith('r');
    if (raw) literal = literal.substring(1);
    if (literal.length < 2) return null;
    final quote = literal[0];
    if ((quote != "'" && quote != '"') ||
        literal[literal.length - 1] != quote) {
      return null;
    }
    final value = literal.substring(1, literal.length - 1);
    if (raw) return value;
    return value.replaceAll('\\$quote', quote).replaceAll(r'\\', r'\');
  }

  int? _matchingParen(String source, int openParen) {
    var depth = 0;
    String? quote;
    var escaped = false;
    for (var index = openParen; index < source.length; index++) {
      final character = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == "'" || character == '"') {
        quote = character;
      } else if (character == '(') {
        depth++;
      } else if (character == ')' && --depth == 0) {
        return index;
      }
    }
    return null;
  }
}
