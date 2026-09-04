// RouteVerifyCommand — `zfa route verify`.
//
// Reads the route table from disk (CLI side: `*_routes.dart`, DDA side:
// generated `zfa_router.g.dart` if present), runs drift detection, and
// emits a result in text, plain, or JSON form.
//
// Bug: route-dual-system-unreconciled. The CLI Route Plugin and the DDA
// Route Plugin generate routes independently; this command is the
// observability seam between them.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../plugins/route/route_drift_detector.dart';
import '../plugins/route/route_table.dart';

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
      help: 'Treat drift warnings as errors (exit 1).',
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
      'Compare CLI-generated and DDA-annotated routes; report drift.';

  @override
  Future<void> run() async {
    final json = argResults?['json'] == true;
    final plain = argResults?['plain'] == true;
    final strict = argResults?['strict'] == true;
    final outPath = argResults?['out'] as String?;

    final table = _readRouteTable();
    final drifts = _detector.detect(table);

    if (json) {
      final payload = {
        'version': table.version,
        'routes': canonicalRouteEntries(
          table.routes,
        ).map((e) => e.toJson()).toList(),
        'drift': drifts
            .map(
              (d) => {
                'path': d.path,
                'sources': canonicalRouteEntries(
                  d.sources,
                ).map((s) => s.toJson()).toList(),
              },
            )
            .toList(),
      };
      final encoded = jsonEncode(payload);
      if (outPath != null) {
        await File(outPath).writeAsString('$encoded\n');
        stdout.writeln('Wrote $outPath');
      } else {
        stdout.writeln(encoded);
      }
    } else if (plain) {
      stdout.writeln('routes: ${table.routes.length}');
      stdout.writeln('drift: ${drifts.length}');
      stdout.write(_renderDrifts(
        drifts,
        driftPrefix: 'DRIFT',
        sourceIndent: '  ',
      ));
    } else {
      stdout.writeln('routes: ${table.routes.length}');
      stdout.writeln('drift: ${drifts.length}');
      stdout.write(_renderDrifts(
        drifts,
        driftPrefix: '⚠️  DRIFT',
        sourceIndent: '    ',
      ));
    }

    if (drifts.isNotEmpty && strict) {
      exitCode = 1;
    }
  }

  /// Render drift findings to a string. [driftPrefix] is prepended to
  /// each drift path; [sourceIndent] precedes each source line.
  /// The plain path uses `DRIFT` (no emoji) + 2-space indent; the
  /// default path uses `⚠️  DRIFT` + 4-space indent.
  String _renderDrifts(
    List<RouteDrift> drifts, {
    String driftPrefix = '⚠️  DRIFT',
    String sourceIndent = '    ',
  }) {
    final buf = StringBuffer();
    for (final d in drifts) {
      buf.writeln('$driftPrefix ${d.path}');
      for (final s in d.sources) {
        buf.writeln('$sourceIndent${s.source.name}: ${s.file}:${s.line} (${s.name})');
      }
    }
    return buf.toString();
  }

  /// Reads CLI `*_routes.dart` modules and the DDA `zfa_router.g.dart`.
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
      } else if (fileName.endsWith('_routes.dart') &&
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
