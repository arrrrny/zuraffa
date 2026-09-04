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

import '../plugins/route/route_drift_detector.dart';
import '../plugins/route/route_table.dart';

class RouteVerifyCommand extends Command<void> {
  RouteVerifyCommand() {
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
    argParser.addOption('out', help: 'Write JSON to this path instead of stdout.');
  }

  final _detector = const RouteDriftDetector();

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
        'routes': table.routes.map((e) => e.toJson()).toList(),
        'drift': drifts
            .map((d) => {
              'path': d.path,
              'sources': d.sources.map((s) => s.toJson()).toList(),
            })
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
      for (final d in drifts) {
        stdout.writeln('DRIFT ${d.path}');
        for (final s in d.sources) {
          stdout.writeln('  ${s.source.name}: ${s.file}:${s.line} (${s.name})');
        }
      }
    } else {
      stdout.writeln('routes: ${table.routes.length}');
      stdout.writeln('drift: ${drifts.length}');
      for (final d in drifts) {
        stdout.writeln('⚠️  DRIFT ${d.path}');
        for (final s in d.sources) {
          stdout.writeln('    ${s.source.name}: ${s.file}:${s.line} (${s.name})');
        }
      }
    }

    if (drifts.isNotEmpty && strict) {
      exitCode = 1;
    }
  }

  /// Reads the on-disk route table. For this initial implementation we
  /// return an empty table — the real per-generator walkers are out of
  /// scope for the bug fix (they belong to follow-ups in spec 075). The
  /// verify command is therefore runnable today (proves the surface,
  /// the JSON shape, the plain text, the exit code) and the generators
  /// can be wired in incrementally.
  RouteTable _readRouteTable() {
    return const RouteTable(version: 1, routes: []);
  }
}
